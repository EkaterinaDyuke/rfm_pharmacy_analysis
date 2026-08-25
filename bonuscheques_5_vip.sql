-- смотрим випов и аптеки
with client_base as (
    select 
        card,
        count(distinct doc_id) as frequency,
        sum(summ_with_disc) as monetary,
        min(datetime) as first_purchase_dt,
        max(datetime) as last_purchase_dt,
        array_agg(distinct shop) as shops,
        -- для первой аптеки: берем shop из самой ранней строки
        (
            select shop
            from bonuscheques b
            where b.card = c.card
            order by b.datetime asc
            limit 1
        ) as first_shop
    from bonuscheques c
    where length(trim(c.card)) = 13
    group by c.card
),
vip_clients as (
    select *
    from client_base
    where frequency > 20 or monetary > 15000
)
select
    card,
    frequency,
    monetary,
    first_shop,
    case
        when cardinality(shops) > 1 then 1
        else 0
    end as multiple_shops,
    shops as all_shops  -- для проверки
from vip_clients


-- доли тех, кто покупает не в одной аптеке (отдельно одноразовые)
with client_base as (
    select 
        card,
        count(distinct doc_id) as frequency,
        sum(summ_with_disc) as monetary,
        array_agg(distinct shop) as shops
    from bonuscheques
    where length(trim(card)) = 13
    group by card
),
client_flags as (
    select 
        card,
        frequency,
        monetary,
        shops,
        case 
            when frequency > 20 or monetary > 15000 then 1 
            else 0 
        end as is_vip,
        case 
            when cardinality(shops) > 1 then 1 
            else 0 
        end as multiple_shops,
        -- флаг, чтобы исключить single из non_vip
        case 
            when frequency = 1 then 1 
            else 0 
        end as is_single
    from client_base
)
select 
    client_group,
    count(*) as card_cnt,
    round(sum(multiple_shops) * 100.0 / count(*), 1) as few_shops_share
from (
    select 
        card,
        multiple_shops,
        case 
            when is_vip = 1 then 'vip'
            when is_single = 1 then 'single'          -- отдельно выделяем single
            else 'non_vip_no_single'                  -- non_vip без single
        end as client_group
    from client_flags
) t
group by client_group
union all
select 
    'total' as client_group,
    count(*) as client_cnt,
    round(sum(multiple_shops) * 100.0 / count(*), 1) as few_shops_share
from client_flags;

 