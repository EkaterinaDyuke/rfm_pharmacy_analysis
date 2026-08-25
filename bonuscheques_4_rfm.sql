-- ============================================================================================================================================================
-- rfm анализ с приоритетными группами + стандартный rfm для остальных
-- 1. группа single (одноразовые). у нас 45% клиентской базы - совершившие только одну покупку за период
--    - критерий: frequency = 1
-- 2. группа vip (самые лояльные). для них возьмем отсечки больше 20 по frequency и больше 15к по monetary (это реальные люди, а не ошибка данных) 
--    - критерий: frequency > 20 or monetary > 15 000 (or - чтобы брать и частых, и дорогих, а не только частых+дорогих)
-- 3. группа incompleted (неполный период). аптека 6 и аптека 11 - неполный период (некорректно сравнивать).
--    - критерий: shop in ('аптека 6', 'аптека 11').
-- 4. группа остальные (нормальные клиенты). для них используем стандартные комбинации r-f-m: 
--    по monetary/recency p33/p66 (классические пороги, выбросы отсечены)
--    по frequency - 2-4, 5-9, 10+ (фиксированные пороги, бизнес-логика)
--    - формат: r{low/med/high}-f{1/2/3}-m{1/2/3}
--    - критерий: frequency > 1 and frequency <= 20 and monetary <= 15 000
-- ============================================================================================================================================================


with client_base as (
    -- шаг 1: агрегация по клиенту (card) без shop
    select 
        card,
        count(distinct doc_id) as frequency,
        sum(summ_with_disc) as monetary,
        extract(day from date '2022-06-09' - min(datetime)) as first_purchase_days,
        extract(day from date '2022-06-09' - max(datetime)) as recency,
        array_agg(distinct shop) as shops
    from bonuscheques
    where length(trim(card)) = 13  -- только идентифицированные клиенты
    group by card
),
-- шаг 2: incompleted = карточки, которые покупали только в аптека 6 или только в аптека 11
incompleted_cards as (
    select card
    from client_base
    where shops = array['аптека 6']::varchar[]
       or shops = array['аптека 11']::varchar[]
),
frequency_stats as (
    -- шаг 3a: расчет p33/p66 для frequency (только для "остальные")
    select 
        percentile_cont(0.33) within group (order by frequency::numeric) as p33_freq,
        percentile_cont(0.66) within group (order by frequency::numeric) as p66_freq
    from client_base
    where frequency > 1 
        and frequency <= 20 
        and card not in (select card from incompleted_cards)
),
monetary_stats as (
    -- шаг 3b: расчет p33/p66 для monetary (только для "остальные")
    select 
        percentile_cont(0.33) within group (order by monetary::numeric) as p33_mon,
        percentile_cont(0.66) within group (order by monetary::numeric) as p66_mon
    from client_base
    where frequency > 1 
        and frequency <= 20 
        and monetary <= 15000
        and card not in (select card from incompleted_cards)
),
recency_stats as (
    -- шаг 3c: расчет p33/p66 для recency (только для "остальные")
    select 
        percentile_cont(0.33) within group (order by recency::numeric) as p33_rec,
        percentile_cont(0.66) within group (order by recency::numeric) as p66_rec
    from client_base
    where frequency > 1 
        and frequency <= 20 
        and monetary <= 15000
        and card not in (select card from incompleted_cards)
),
client_rfm as (
    -- шаг 4: расчет rfm для всех клиентов
    select 
        c.card,
        c.frequency,
        c.monetary,
        c.recency,
        c.shops,      
        -- критический фильтр: группа "остальные" (исключены single, vip, incompleted)
        case 
            when c.frequency > 1 
                 and c.frequency <= 20 
                 and c.monetary <= 15000
                 and c.card not in (select card from incompleted_cards) then 1
            else 0
        end as is_others,    
        -- f_score: фиксированные buckets (бизнес-логика)
        case 
            when c.frequency between 2 and 4 then 1  -- f1: низкая
            when c.frequency between 5 and 9 then 2  -- f2: средняя
            when c.frequency >= 10 then 3            -- f3: высокая
        end as f_score,    
        -- m_score: p33/p66 (классический rfm)
        case 
            when c.monetary < m.p33_mon then 1  -- m1: низкая
            when c.monetary <= m.p66_mon then 2  -- m2: средняя
            else 3  -- m3: высокая
        end as m_score,   
        -- r_score: p33/p66 (инвертировано)
        case 
            when c.recency > r.p66_rec then 1  -- rlow: старый
            when c.recency >= r.p33_rec then 2  -- rmed: средний
            else 3  -- rhigh: новый
        end as r_score     
    from client_base c
    join frequency_stats f on 1=1
    join monetary_stats m on 1=1
    join recency_stats r on 1=1
),
final_segments as (
    -- шаг 5: присвоение финальных названий групп
    select 
        c.card,
        c.frequency,
        c.monetary,
        c.recency,
        c.shops,        
        -- группа: приоритетные (single, vip, incompleted) или остальные (r-f-m)
        case 
            -- приоритетная группа 1: single (frequency = 1)
            when c.frequency = 1 then 'single'            
            -- приоритетная группа 2: vip (frequency > 20 or monetary > 15000)
            when c.frequency > 20 or c.monetary > 15000 then 'vip'           
            -- приоритетная группа 3: incompleted (card только в аптека 6 или только в аптека 11)
            when c.card in (select card from incompleted_cards) then 'incompleted'         
            -- остальные: r{low/med/high}-f{1/2/3}-m{1/2/3}
            else 'r' || 
                 case c.r_score when 1 then 'low' when 2 then 'med' when 3 then 'high' end || 
                 '-f' || c.f_score || 
                 '-m' || c.m_score
        end as группа      
    from client_rfm c
)
-- шаг 6: финальный вывод (группа, количество клиентов, доля от всех)
select 
    группа,
    count(*) as количество_клиентов,
    round(count(*) * 100.0 / sum(count(*)) over (), 1) as доля_от_всех_проценты
from final_segments
group by группа
order by количество_клиентов desc;