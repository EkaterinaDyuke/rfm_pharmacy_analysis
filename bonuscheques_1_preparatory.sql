-- 1. Общее количество записей
select 
	count(*) as total_rows 
from bonuscheques; 
-- 38 486


-- 2. Распределение по длине поля card
select
	length(trim(card)) as card_len,
	count(*) as n_transactions
from bonuscheques
group by 1
order by 1;
-- 13 символов - 21 075
-- 36 символов - 17 411


-- 3. Доля транзакций с картой/без карты: число и выручка
select
	case 
		when length(trim(card)) = 13 then 'с картой' 
		else 'без карты' 
		end as client_type,
	count(*) as n_transactions,
	sum(summ_with_disc) as total_revenue,
	round(100.0 * count(*) / sum(count(*)) over ()) as pct_transactions,
	round(100.0 * sum(summ_with_disc) / sum(sum(summ_with_disc)) over ()) as pct_revenue
from bonuscheques
group by 1
order by 1;
/*
client_type	n_transactions	total_revenue	pct_transactions	pct_revenue
"без карты"	"17 411"	"12 963 730"	"45"	"40"
"с картой"	"21 075"	"19 133 878"	"55"	"60"
 */


-- 4. Проверка пропусков и некорректных summ_with_disc
select
	count(*) filter (where summ_with_disc is null) as n_null,
	count(*) filter (where summ_with_disc = 0) as n_zero,
	count(*) filter (where summ_with_disc < 0) as n_negative,
	round(100.0 * count(*) filter (where summ_with_disc is null) / count(*)) as pct_null
from bonuscheques;
-- 0  0  0	0
-- нет пропусков и некорректных


-- 5. Дубликаты по doc_id и проверка уникальности чеков
select
	count(distinct doc_id) as unique_doc_id,
	count(*) as total_rows,
	count(*) - count(distinct doc_id) as dup_doc_id_count
from bonuscheques;
-- найдено 6 дубликатов


-- 5.1 Выводим дубликаты 
select *
from bonuscheques
where doc_id in (
    select 
    	doc_id
    from bonuscheques
    group by doc_id
    having count(*) > 1
);
/*
datetime	shop	card	bonus_earned	bonus_spent	summ	summ_with_disc	doc_id
"2021-09-16 20:10:32.000"	"Аптека 7"	"cf1dcbed-2d3e-4054-a04c-36c88c2e6f63"	"27"	"0"	"943"	"907"	"15#11009179#66003#11_199"
"2021-09-16 20:10:48.000"	"Аптека 7"	"cf1dcbed-2d3e-4054-a04c-36c88c2e6f63"	"27"	"0"	"943"	"907"	"15#11009179#66003#11_199"
"2021-09-16 20:11:28.000"	"Аптека 7"	"cf1dcbed-2d3e-4054-a04c-36c88c2e6f63"	"27"	"0"	"943"	"907"	"15#11009179#66003#11_199"
"2022-01-06 12:57:28.000"	"Аптека 10"	"2000200208211"	"66"	"0"	"2 207"	"2 207"	"15#17000057#66115#17_17"
"2022-01-06 12:57:45.000"	"Аптека 10"	"2000200208211"	"66"	"0"	"2 207"	"2 207"	"15#17000057#66115#17_17"
"2022-01-18 17:21:49.000"	"Аптека 10"	"2000200189985"	"19"	"21"	"771"	"771"	"15#17000300#66127#17_51"
"2022-01-18 17:26:16.000"	"Аптека 10"	"2000200188902"	"11"	"0"	"371"	"371"	"15#17000300#66127#17_51"
"2022-02-20 18:37:44.000"	"Аптека 4"	"abaee6eb-5569-4081-b8f4-5b0e051605cc"	"50"	"0"	"1 676"	"1 676"	"15#7000547#66160#7_68"
"2022-02-20 18:37:47.000"	"Аптека 4"	"abaee6eb-5569-4081-b8f4-5b0e051605cc"	"50"	"0"	"1 676"	"1 676"	"15#7000547#66160#7_68"
"2022-02-20 18:37:51.000"	"Аптека 4"	"7bf2b55a-347b-4c49-8e25-8e4c0f0c7e50"	"1"	"0"	"130"	"130"	"15#7000547#66160#7_78"
"2022-02-20 18:37:53.000"	"Аптека 4"	"7bf2b55a-347b-4c49-8e25-8e4c0f0c7e50"	"1"	"0"	"130"	"130"	"15#7000547#66160#7_78"
 
вывод
doc_id: 15#11009179#66003#11_199: 3 идентичные записи (не совпадают в секундах) => явный дубликат (сделать одну запись)
doc_id: 15#17000057#66115#17_17: 2 идентичные записи (не совпадают в секундах) => явный дубликат (сделать одну запись)
doc_id: 15#7000547#66160#7_68: 2 идентичные записи (не совпадают в секундах) => явный дубликат (сделать одну запись)
doc_id: 15#7000547#66160#7_78: 2 идентичные записи (не совпадают в секундах) => явный дубликат (сделать одну запись)
doc_id: 15#17000300#66127#17_51: разное все, скорее всего две транзакции получили один id (оставить обе записи)
Решение: для RFM (группа с картами, card_len=13) агрегируем по card + doc_id, для группы без карт - просто по doc_id
*/


-- 6. Количество уникальных бонусных карт
select
	count(distinct trim(card)) as unique_cards_count
from bonuscheques
where length(trim(card)) = 13;
-- 5 926 


-- 7. Период данных: min/max дат и число месяцев наблюдения
select
	min(datetime)::date as min_date,
	max(datetime)::date as max_date,
	date_trunc('month', min(datetime))::date as min_month,
	date_trunc('month', max(datetime))::date as max_month,
	date_part('year', age(max(datetime), min(datetime))) * 12 +
	date_part('month', age(max(datetime), min(datetime))) + 1 as n_months
from bonuscheques;
-- с 2021-07-12 по 2022-06-09 (11 месяцев)


-- 8. Количество уникальных аптек
select 
	count(distinct shop) as n_shops 
from bonuscheques;
-- 8 аптек


-- 8.1 Период по каждой аптеке и число месяцев наблюдения
select
	shop,
	min(datetime)::date as min_date,
	max(datetime)::date as max_date,
	date_part('year', age(max(datetime), min(datetime))) * 12 +
	date_part('month', age(max(datetime), min(datetime))) + 1 as months_observed,
	count(*) as n_transactions
from bonuscheques
group by shop
order by months_observed, shop;
-- в аптеках 11 и 6 записи не за все 11 месяцев
-- Аптека 11: с 2022-03-15 по 2022-06-09
-- Аптека 6: с 2021-07-12 по 2021-10-02


-- 9. Разбивка по группам с картой / без карты + статистика по выручке
with group_stats as (
    select 
        case 
	        when length(trim(card)) = 13 
	        then 'identified_with_card' 
	        else 'unidentified_without_card' 
	    end as group_name,
        count(*) as n_transactions,
        sum(summ_with_disc) as total_revenue,
        percentile_cont(0.01) within group (order by summ_with_disc) as p1,
        percentile_cont(0.05) within group (order by summ_with_disc) as p5,
        percentile_cont(0.25) within group (order by summ_with_disc) as p25,
        percentile_cont(0.50) within group (order by summ_with_disc) as p50_median,
        percentile_cont(0.75) within group (order by summ_with_disc) as p75,
        percentile_cont(0.95) within group (order by summ_with_disc) as p95,
        percentile_cont(0.99) within group (order by summ_with_disc) as p99,
        min(summ_with_disc) as min_value,
        max(summ_with_disc) as max_value,
        avg(summ_with_disc) as avg_value,
        stddev(summ_with_disc) as stddev_value
    from bonuscheques
    group by 
    	case 
	        when length(trim(card)) = 13 
	        then 'identified_with_card' 
	        else 'unidentified_without_card' 
	    end
),
total_stats as (
    select 
        sum(n_transactions) as total_transactions,
        sum(total_revenue) as total_revenue_all
    from group_stats
)
select 
    g.group_name,
    g.n_transactions,
    round(100.0 * g.n_transactions / t.total_transactions, 2) as pct_transactions,
    g.total_revenue,
    round(100.0 * g.total_revenue / t.total_revenue_all, 2) as pct_revenue,
    round(g.p1::numeric, 2) as p1_value,
    round(g.p5::numeric, 2) as p5_value,
    round(g.p25::numeric, 2) as p25_value,
    round(g.p50_median::numeric, 2) as p50_median_value,
    round(g.p75::numeric, 2) as p75_value,
    round(g.p95::numeric, 2) as p95_value,
    round(g.p99::numeric, 2) as p99_value,
    round(g.min_value::numeric, 2) as min_value,
    round(g.max_value::numeric, 2) as max_value,
    round(g.avg_value::numeric, 2) as avg_value,
    round(g.stddev_value::numeric, 2) as stddev_value
from group_stats g
join total_stats t 
on 1=1
order by g.total_revenue desc;
/*
group_name	n_transactions	pct_transactions	total_revenue	pct_revenue	p1_value	p5_value	p25_value	p50_median_value	p75_value	p95_value	p99_value	min_value	max_value	avg_value	stddev_value
"identified_with_card"	"21 075"	"54,76"	"19 133 878"	"59,61"	"51"	"102"	"312,5"	"628"	"1 123,5"	"2 655"	"4 797,26"	"6"	"23 229"	"907,89"	"1 010,92"
"unidentified_without_card"	"17 411"	"45,24"	"12 963 730"	"40,39"	"45"	"88"	"239"	"500"	"931"	"2 234,5"	"4 220,7"	"11"	"17 712"	"744,57"	"857,8"
 */


-- 10. Подтверждение наблюдения: % транзакций с картами и их доля в выручке
select
	round(100.0 * sum(case when length(trim(card)) = 13 then 1 else 0 end) / count(*)) as pct_with_cards,
	round(100.0 * sum(case when length(trim(card)) = 13 then summ_with_disc else 0 end) / sum(summ_with_disc)) as revenue_pct_with_cards
from bonuscheques;
-- 55% транзакций с картами дают 60% по выручке (summ_with_disc)


-- 11. По аптекам: число транзакций с картами и без 
select
	shop,
	sum(case when length(trim(card)) = 13 then 1 else 0 end) as n_with_cards,
	sum(case when length(trim(card)) != 13 then 1 else 0 end) as n_without_cards,
	sum(case when length(trim(card)) = 13 then summ_with_disc else 0 end) as revenue_with_cards,
	sum(case when length(trim(card)) != 13 then summ_with_disc else 0 end) as revenue_without_cards,
	count(*) as total_transactions
from bonuscheques
group by shop
order by total_transactions desc;
/*
shop	n_with_cards	n_without_cards	revenue_with_cards	revenue_without_cards	total_transactions
"Аптека 2"	"6 914"	"5 296"	"6 702 093"	"4 844 145"	"12 210"
"Аптека 10"	"6 475"	"819"	"6 461 948"	"910 494"	"7 294"
"Аптека 7"	"2 405"	"4 257"	"2 014 753"	"2 845 735"	"6 662"
"Аптека 1"	"1 179"	"3 215"	"876 765"	"2 094 993"	"4 394"
"Аптека 8"	"2 074"	"1 397"	"1 396 787"	"858 306"	"3 471"
"Аптека 4"	"897"	"2 068"	"537 127"	"1 156 786"	"2 965"
"Аптека 11"	"986"	"273"	"1 028 378"	"201 557"	"1 259"
"Аптека 6"	"145"	"86"	"116 027"	"51 714"	"231"
 */


-- 12. Агрегация по месяцам (гггг‑мм) по картам/без карт - общий и по аптекам
-- 2021-07 и 2022-06 - неполные месяцы (поэтому результаты ниже реальности)
select
	to_char(date_trunc('month', datetime), 'YYYY-MM') as ym,
	sum(case when length(trim(card)) = 13 then 1 else 0 end) as n_with_cards,
	sum(case when length(trim(card)) != 13 then 1 else 0 end) as n_without_cards,
	sum(case when length(trim(card)) = 13 then summ_with_disc else 0 end) as revenue_with_cards,
	sum(case when length(trim(card)) != 13 then summ_with_disc else 0 end) as revenue_without_cards,
	count(*) as total_transactions
from bonuscheques
group by to_char(date_trunc('month', datetime), 'YYYY-MM')
order by to_char(date_trunc('month', datetime), 'YYYY-MM');
/*
с октября 2021 трансакций с картами становится стабильно больше, чем без них
ym	n_with_cards	n_without_cards	revenue_with_cards	revenue_without_cards	total_transactions
"2021-07"	"902"	"938"	"792 010"	"628 246"	"1 840"
"2021-08"	"1 375"	"1 597"	"1 168 453"	"1 119 233"	"2 972"
"2021-09"	"1 589"	"1 803"	"1 385 593"	"1 288 933"	"3 392"
"2021-10"	"1 880"	"1 870"	"1 726 477"	"1 495 476"	"3 750"
"2021-11"	"1 929"	"1 690"	"1 796 416"	"1 267 631"	"3 619"
"2021-12"	"2 136"	"1 732"	"1 854 325"	"1 334 800"	"3 868"
"2022-01"	"2 092"	"1 679"	"1 867 151"	"1 284 072"	"3 771"
"2022-02"	"2 007"	"1 539"	"1 813 379"	"1 164 626"	"3 546"
"2022-03"	"2 084"	"1 448"	"2 211 566"	"1 156 776"	"3 532"
"2022-04"	"2 158"	"1 374"	"1 955 047"	"1 006 163"	"3 532"
"2022-05"	"2 190"	"1 344"	"1 957 688"	"920 359"	"3 534"
"2022-06"	"733"	"397"	"605 773"	"297 415"	"1 130"
 */


-- 13. Агрегация по месяцам и аптекам (гггг‑мм) по картам/без карт - общий и по аптекам
-- 2021-07 и 2022-06 - неполные месяцы (поэтому резултаты ниже реальности)
select
	to_char(date_trunc('month', datetime), 'YYYY-MM') as ym,
	shop,
	sum(case when length(trim(card)) = 13 then 1 else 0 end) as n_with_cards,
	sum(case when length(trim(card)) != 13 then 1 else 0 end) as n_without_cards,
	sum(case when length(trim(card)) = 13 then summ_with_disc else 0 end) as revenue_with_cards,
	sum(case when length(trim(card)) != 13 then summ_with_disc else 0 end) as revenue_without_cards,
	count(*) as total_transactions
from bonuscheques
group by shop, to_char(date_trunc('month', datetime), 'YYYY-MM')
order by to_char(date_trunc('month', datetime), 'YYYY-MM');
/*
ym	shop	n_with_cards	n_without_cards	revenue_with_cards	revenue_without_cards	total_transactions
"2021-07"	"Аптека 1"	"25"	"188"	"20 540"	"124 876"	"213"
"2021-07"	"Аптека 10"	"252"	"31"	"212 529"	"25 597"	"283"
"2021-07"	"Аптека 2"	"366"	"263"	"370 343"	"234 846"	"629"
"2021-07"	"Аптека 4"	"52"	"132"	"31 835"	"65 778"	"184"
"2021-07"	"Аптека 6"	"28"	"18"	"21 897"	"7 498"	"46"
"2021-07"	"Аптека 7"	"97"	"230"	"79 695"	"125 588"	"327"
"2021-07"	"Аптека 8"	"82"	"76"	"55 171"	"44 063"	"158"
"2021-08"	"Аптека 1"	"67"	"320"	"49 757"	"201 190"	"387"
"2021-08"	"Аптека 10"	"425"	"75"	"361 509"	"68 815"	"500"
"2021-08"	"Аптека 2"	"432"	"463"	"400 645"	"405 436"	"895"
"2021-08"	"Аптека 4"	"53"	"207"	"32 691"	"110 696"	"260"
"2021-08"	"Аптека 6"	"45"	"28"	"41 396"	"16 734"	"73"
"2021-08"	"Аптека 7"	"170"	"366"	"159 144"	"227 671"	"536"
"2021-08"	"Аптека 8"	"183"	"138"	"123 311"	"88 691"	"321"
"2021-09"	"Аптека 1"	"81"	"326"	"77 629"	"222 250"	"407"
"2021-09"	"Аптека 10"	"378"	"68"	"374 611"	"72 938"	"446"
"2021-09"	"Аптека 2"	"605"	"527"	"557 173"	"463 330"	"1 132"
"2021-09"	"Аптека 4"	"102"	"237"	"69 885"	"135 466"	"339"
"2021-09"	"Аптека 6"	"71"	"37"	"51 403"	"24 557"	"108"
"2021-09"	"Аптека 7"	"172"	"456"	"137 221"	"267 645"	"628"
"2021-09"	"Аптека 8"	"180"	"152"	"117 671"	"102 747"	"332"
"2021-10"	"Аптека 1"	"99"	"402"	"77 423"	"278 630"	"501"
"2021-10"	"Аптека 10"	"648"	"95"	"618 367"	"104 357"	"743"
"2021-10"	"Аптека 2"	"625"	"563"	"641 356"	"561 755"	"1 188"
"2021-10"	"Аптека 4"	"95"	"219"	"59 808"	"138 459"	"314"
"2021-10"	"Аптека 6"	"1"	"3"	"1 331"	"2 925"	"4"
"2021-10"	"Аптека 7"	"218"	"440"	"210 055"	"312 918"	"658"
"2021-10"	"Аптека 8"	"194"	"148"	"118 137"	"96 432"	"342"
"2021-11"	"Аптека 1"	"113"	"314"	"83 270"	"215 001"	"427"
"2021-11"	"Аптека 10"	"652"	"86"	"621 682"	"73 875"	"738"
"2021-11"	"Аптека 2"	"681"	"533"	"732 852"	"469 090"	"1 214"
"2021-11"	"Аптека 4"	"69"	"201"	"41 773"	"130 893"	"270"
"2021-11"	"Аптека 7"	"220"	"410"	"191 122"	"295 680"	"630"
"2021-11"	"Аптека 8"	"194"	"146"	"125 717"	"83 092"	"340"
"2021-12"	"Аптека 1"	"122"	"329"	"81 721"	"207 953"	"451"
"2021-12"	"Аптека 10"	"677"	"77"	"660 086"	"114 055"	"754"
"2021-12"	"Аптека 2"	"738"	"536"	"701 922"	"499 723"	"1 274"
"2021-12"	"Аптека 4"	"123"	"213"	"68 744"	"110 145"	"336"
"2021-12"	"Аптека 7"	"280"	"454"	"230 958"	"322 886"	"734"
"2021-12"	"Аптека 8"	"196"	"123"	"110 894"	"80 038"	"319"
"2022-01"	"Аптека 1"	"106"	"272"	"70 363"	"174 554"	"378"
"2022-01"	"Аптека 10"	"717"	"81"	"786 360"	"109 598"	"798"
"2022-01"	"Аптека 2"	"664"	"528"	"557 111"	"488 436"	"1 192"
"2022-01"	"Аптека 4"	"90"	"224"	"44 452"	"127 664"	"314"
"2022-01"	"Аптека 7"	"322"	"454"	"271 406"	"309 768"	"776"
"2022-01"	"Аптека 8"	"193"	"120"	"137 459"	"74 052"	"313"
"2022-02"	"Аптека 1"	"116"	"304"	"70 400"	"198 314"	"420"
"2022-02"	"Аптека 10"	"698"	"67"	"695 653"	"65 510"	"765"
"2022-02"	"Аптека 2"	"714"	"500"	"702 633"	"472 848"	"1 214"
"2022-02"	"Аптека 4"	"86"	"176"	"63 503"	"90 910"	"262"
"2022-02"	"Аптека 7"	"238"	"387"	"182 033"	"284 751"	"625"
"2022-02"	"Аптека 8"	"155"	"105"	"99 157"	"52 293"	"260"
"2022-03"	"Аптека 1"	"126"	"252"	"117 231"	"166 036"	"378"
"2022-03"	"Аптека 10"	"548"	"76"	"723 096"	"89 912"	"624"
"2022-03"	"Аптека 11"	"179"	"49"	"186 344"	"31 765"	"228"
"2022-03"	"Аптека 2"	"776"	"478"	"822 126"	"459 725"	"1 254"
"2022-03"	"Аптека 4"	"66"	"154"	"33 134"	"102 588"	"220"
"2022-03"	"Аптека 7"	"199"	"315"	"187 228"	"221 647"	"514"
"2022-03"	"Аптека 8"	"190"	"124"	"142 407"	"85 103"	"314"
"2022-04"	"Аптека 1"	"144"	"225"	"93 693"	"131 576"	"369"
"2022-04"	"Аптека 10"	"588"	"68"	"598 720"	"79 879"	"656"
"2022-04"	"Аптека 11"	"312"	"87"	"344 525"	"77 429"	"399"
"2022-04"	"Аптека 2"	"612"	"413"	"556 529"	"377 966"	"1 025"
"2022-04"	"Аптека 4"	"43"	"132"	"27 241"	"71 596"	"175"
"2022-04"	"Аптека 7"	"227"	"325"	"167 152"	"199 289"	"552"
"2022-04"	"Аптека 8"	"232"	"124"	"167 187"	"68 428"	"356"
"2022-05"	"Аптека 1"	"143"	"218"	"110 165"	"132 575"	"361"
"2022-05"	"Аптека 10"	"684"	"67"	"633 575"	"82 743"	"751"
"2022-05"	"Аптека 11"	"328"	"113"	"335 405"	"69 401"	"441"
"2022-05"	"Аптека 2"	"517"	"373"	"503 292"	"295 404"	"890"
"2022-05"	"Аптека 4"	"97"	"125"	"53 706"	"47 284"	"222"
"2022-05"	"Аптека 7"	"204"	"335"	"160 942"	"224 639"	"539"
"2022-05"	"Аптека 8"	"217"	"113"	"160 603"	"68 313"	"330"
"2022-06"	"Аптека 1"	"37"	"65"	"24 573"	"42 038"	"102"
"2022-06"	"Аптека 10"	"208"	"28"	"175 760"	"23 215"	"236"
"2022-06"	"Аптека 11"	"167"	"24"	"162 104"	"22 962"	"191"
"2022-06"	"Аптека 2"	"184"	"119"	"156 111"	"115 586"	"303"
"2022-06"	"Аптека 4"	"21"	"48"	"10 355"	"25 307"	"69"
"2022-06"	"Аптека 7"	"58"	"85"	"37 797"	"53 253"	"143"
"2022-06"	"Аптека 8"	"58"	"28"	"39 073"	"15 054"	"86"
 */

