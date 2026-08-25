-- 1. Все метрики + перцентили для каждой
with client_base as (
    select 
        card,
        count(distinct doc_id) as frequency,
        sum(summ_with_disc) as monetary,
        extract(day from date '2022-06-09' - max(datetime)) as recency
    from bonuscheques
    where length(trim(card)) = 13
    group by card
),
freq_stats as (
    select 
        percentile_cont(0.50) within group (order by frequency) as median_freq,
        percentile_cont(0.95) within group (order by frequency) as p95_freq,
        max(frequency) as max_freq
    from client_base
),
mon_stats as (
    select 
        percentile_cont(0.50) within group (order by monetary) as median_mon,
        percentile_cont(0.95) within group (order by monetary) as p95_mon,
        max(monetary) as max_mon
    from client_base
),
rec_stats as (
    select 
        percentile_cont(0.50) within group (order by recency) as median_rec,
        percentile_cont(0.95) within group (order by recency) as p95_rec,
        max(recency) as max_rec
    from client_base
)
select 
    'Frequency' as metric,
    median_freq as median,
    p95_freq as p95,
    max_freq as max
from freq_stats
union all
select 
    'Monetary' as metric,
    median_mon as median,
    p95_mon as p95,
    max_mon as max
from mon_stats
union all
select 
    'Recency' as metric,
    median_rec as median,
    p95_rec as p95,
    max_rec as max
from rec_stats;
-- metric       median    p95        max
-- Frequency	2    	  12         217       -- явно аномалия (p95 и max)
-- Monetary	    1 470.5	  10 951.5	 162 687   -- явно аномалия (p95 и max)
-- Recency	    86    	  298	     331       -- тут из-за 45% купивших 1 раз

-- 2. Выбросы по аптекам: перцентили для frequency, monetary, recency (по каждой аптеке)
with client_by_shop as (
    select 
        card,
        shop,
        count(distinct doc_id) as frequency,
        sum(summ_with_disc) as monetary,
        extract(day from date '2022-06-09' - max(datetime)) as recency
    from bonuscheques
    where length(trim(card)) = 13
    group by card, shop
),
shop_freq_stats as (
    select 
        shop,
        percentile_cont(0.50) within group (order by frequency) as median_freq,
        percentile_cont(0.95) within group (order by frequency) as p95_freq,
        max(frequency) as max_freq,
        avg(frequency) as avg_freq
    from client_by_shop
    group by shop
),
shop_mon_stats as (
    select 
        shop,
        percentile_cont(0.50) within group (order by monetary) as median_mon,
        percentile_cont(0.95) within group (order by monetary) as p95_mon,
        max(monetary) as max_mon,
        avg(monetary) as avg_mon
    from client_by_shop
    group by shop
),
shop_rec_stats as (
    select 
        shop,
        percentile_cont(0.50) within group (order by recency) as median_rec,
        percentile_cont(0.95) within group (order by recency) as p95_rec,
        max(recency) as max_rec,
        avg(recency) as avg_rec
    from client_by_shop
    group by shop
)
select 
    shop,
    'Frequency' as metric_type,
    median_freq as median,
    p95_freq as p95,
    max_freq as max,
    round(avg_freq) as avg
from shop_freq_stats
union all
select 
    shop,
    'Monetary' as metric_type,
    median_mon as median,
    p95_mon as p95,
    max_mon as max,
    round(avg_mon) as avg
from shop_mon_stats
union all
select 
    shop,
    'Recency' as metric_type,
    median_rec as median,
    p95_rec as p95,
    max_rec as max,
    round(avg_rec) as avg
from shop_rec_stats
order by metric_type, shop;
/*
shop	metric_type	median	p95	max	avg
"Аптека 1"	"Frequency"	"2"	"9"	"32"	"3"
"Аптека 10"	"Frequency"	"2"	"18"	"217"	"5"
"Аптека 11"	"Frequency"	"1"	"4"	"15"	"2"
"Аптека 2"	"Frequency"	"2"	"10"	"52"	"3"
"Аптека 4"	"Frequency"	"1,5"	"8"	"29"	"3"
"Аптека 6"	"Frequency"	"1"	"4"	"7"	"2"
"Аптека 7"	"Frequency"	"2"	"11,55"	"37"	"3"
"Аптека 8"	"Frequency"	"1"	"8"	"48"	"2"
"Аптека 1"	"Monetary"	"1 068"	"7 371,8"	"23 460"	"2 088"
"Аптека 10"	"Monetary"	"2 056"	"18 767,65"	"149 326"	"5 394"
"Аптека 11"	"Monetary"	"941,5"	"5 224"	"23 015"	"1 643"
"Аптека 2"	"Monetary"	"1 480"	"9 736,2"	"90 315"	"2 893"
"Аптека 4"	"Monetary"	"841,5"	"5 342,35"	"15 470"	"1 628"
"Аптека 6"	"Monetary"	"1 124"	"3 685,55"	"5 145"	"1 381"
"Аптека 7"	"Monetary"	"1 600,5"	"9 860,7"	"27 708"	"2 838"
"Аптека 8"	"Monetary"	"891,5"	"4 614,05"	"38 045"	"1 598"
"Аптека 1"	"Recency"	"86"	"300,1"	"330"	"113"
"Аптека 10"	"Recency"	"76"	"291"	"331"	"103"
"Аптека 11"	"Recency"	"33"	"78"	"81"	"36"
"Аптека 2"	"Recency"	"111"	"307,2"	"331"	"128"
"Аптека 4"	"Recency"	"123,5"	"303"	"331"	"132"
"Аптека 6"	"Recency"	"272"	"325,4"	"330"	"278"
"Аптека 7"	"Recency"	"112,5"	"301,75"	"328"	"121"
"Аптека 8"	"Recency"	"122"	"305,35"	"331"	"136"
*/

-- 3. Найдем клиента с 217 покупками
with top_freq as (
    select 
        card,
        count(*) as frequency
    from bonuscheques
    where length(trim(card)) = 13
    group by card
    order by frequency desc
    limit 1
)
-- Выводим все транзакции этого клиента
select 
    t.datetime,
    t.shop,
    t.card,
    t.bonus_earned,
    t.bonus_spent,
    t.summ,
    t.summ_with_disc,
    t.doc_id
from bonuscheques t
join top_freq c 
on t.card = c.card
order by t.datetime;
-- Это реальный клиент, совершающий по несколько покупок в месяц (в аптеке 10, 2000200189985)


-- 4. Найдем клиента с максимальной выручкой
with top_rev as (
    select 
        card,
        sum(summ_with_disc) as total_revenue
    from bonuscheques
    where length(trim(card)) = 13
    group by card
    order by total_revenue desc
    limit 1
)
-- Выводим все транзакции этого клиента
select 
    t.datetime,
    t.shop,
    t.card,
    t.bonus_earned,
    t.bonus_spent,
    t.summ,
    t.summ_with_disc,
    t.doc_id
from bonuscheques t
join top_rev c 
on t.card = c.card
order by t.datetime;
-- Это реальный клиент, совершающий по несколько покупок в месяц (в аптеке 10, 2000200170860)


-- Статистика RFM без двух VIP клиентов (2000200189985 и 2000200170860)
with client_base_without_outliers as (
    select 
        card,
        count(distinct doc_id) as frequency,
        sum(summ_with_disc) as monetary,
        extract(day from date '2022-06-09' - max(datetime)) as recency
    from bonuscheques
    where length(trim(card)) = 13
        and card not in ('2000200189985', '2000200170860')
    group by card
),
freq_stats_without as (
    select 
        percentile_cont(0.50) within group (order by frequency) as median_freq,
        percentile_cont(0.95) within group (order by frequency) as p95_freq,
        max(frequency) as max_freq
    from client_base_without_outliers
),
mon_stats_without as (
    select 
        percentile_cont(0.50) within group (order by monetary) as median_mon,
        percentile_cont(0.95) within group (order by monetary) as p95_mon,
        max(monetary) as max_mon
    from client_base_without_outliers
),
rec_stats_without as (
    select 
        percentile_cont(0.50) within group (order by recency) as median_rec,
        percentile_cont(0.95) within group (order by recency) as p95_rec,
        max(recency) as max_rec
    from client_base_without_outliers
)
select 
    'frequency' as metric,
    median_freq as median_without,
    p95_freq as p95_without,
    max_freq as max_without
from freq_stats_without
union all
select 
    'monetary' as metric,
    median_mon as median_without,
    p95_mon as p95_without,
    max_mon as max_without
from mon_stats_without
union all
select 
    'recency' as metric,
    median_rec as median_without,
    p95_rec as p95_without,
    max_rec as max_without
from rec_stats_without
order by metric;
/*
metric	median_without	p95_without	max_without
"frequency"	"2"	"12"	"103"
"monetary"	"1 470"	"10 899,25"	"122 410"
"recency"	"86"	"298"	"331"
*/