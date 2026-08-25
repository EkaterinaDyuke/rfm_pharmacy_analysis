-- 1. Распределение частоты покупок
with client_freq as (
    select 
        card,
        count(*) as n_purchases
    from bonuscheques
    where length(trim(card)) = 13
    group by card
)
select 
    case 
        when n_purchases = 1 then '1 раз'
        when n_purchases between 2 and 4 then '2-4 раза'
        when n_purchases between 5 and 9 then '5-9 раз'
        when n_purchases >= 10 then '10+ раз'
    end as freq_group,
    count(*) as n_clients,
    sum(n_purchases) as total_purchases,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as pct_clients,
    round(sum(n_purchases) * 100.0 / sum(sum(n_purchases)) over (), 2) as pct_purchases
from client_freq
group by 1
order by 2 desc;
/*
freq_group  n_clients  total_purchases  pct_clients  pct_purchases
1 раз	   2 686	    2 686	        45.33	     12.74
2-4 раза   2 026	    5 397	        34.19	     25.61
5-9 раз	   783	        5 000	        13.21	     23.72
10+ раз	   431	        7 992	        7.27	     37.92
*/

-- 2. Статистика: интервалы между 1-й и 2-й покупками (только идентифицированные и 2+ покупки)
with client_purchases as (
    select 
        card,
        datetime,
        row_number() over (partition by card order by datetime) as purchase_num
    from bonuscheques
    where length(trim(card)) = 13
),
first_second as (
    select 
        card,
        max(datetime::date) filter (where purchase_num = 1) as first_purchase,
        max(datetime::date) filter (where purchase_num = 2) as second_purchase
    from client_purchases
    group by card
    having count(*) >= 2
)
select 
    round(avg(second_purchase - first_purchase)) as avg_days,
    percentile_cont(0.5) within group (order by second_purchase - first_purchase) as median_days,
    min(second_purchase - first_purchase) as min_days,
    max(second_purchase - first_purchase) as max_days,
    count(*) as n_clients_with_2plus
from first_second;
/*
avg_days	median_days	min_days	max_days	n_clients_with_2plus
"44"	"22"	"0"	"318"	"3 240"
*/

-- 3. Статистика: интервалы между 1-й до последней покупками (только идентифицированные и 2+ покупки)
with client_life as (
    select 
        card,
        min(datetime::date) as first_purchase,
        max(datetime::date) as last_purchase,
        count(*) as n_purchases
    from bonuscheques
    where length(trim(card)) = 13
    group by card
)
select 
    round(avg(last_purchase - first_purchase)) as avg_days,
    percentile_cont(0.50) within group (order by last_purchase - first_purchase) as median_days,
    min(last_purchase - first_purchase) as min_days,
    max(last_purchase - first_purchase) as max_days,
    count(*) filter (where last_purchase - first_purchase > 180) as clients_6months_plus
from client_life
where n_purchases >= 2;
/*
avg_days	median_days	min_days	max_days	clients_6months_plus
"127"	"112"	"0"	"331"	"1 005"
*/

-- 4. Эффективность бонусной программы
with client_bonuses as (
    select 
        card,
        sum(bonus_earned) as total_earned,
        sum(bonus_spent) as total_spent,
        sum(bonus_earned) - sum(bonus_spent) as balance
    from bonuscheques
    where length(trim(card)) = 13
    group by card
)
select 
    count(*) as total_clients,
    count(*) filter (where total_spent > 0) as clients_using_bonuses,
    round(100.0 * count(*) filter (where total_spent > 0) / count(*), 2) as pct_using_bonuses,
    round(avg(balance), 2) as avg_balance,
    count(*) filter (where balance = 0) as clients_zero_balance,
    round(100.0 * count(*) filter (where balance = 0) / count(*), 2) as pct_zero_balance
from client_bonuses;
-- total_clients  clients_using_bonuses  pct_using_bonuses  avg_balance  clients_zero_balance  pct_zero_balance
-- 5 926	      2 649	                 44.70	            40.91	     40	                   0.67

-- 5. Поведение по аптекам (покупают в 1 аптеке или в нескольких)
with client_shops as (
    select 
        card,
        count(distinct shop) as n_shops
    from bonuscheques
    where length(trim(card)) = 13
    group by card
)
select 
    count(*) as total_clients,
    count(*) filter (where n_shops = 1) as single_shop_clients,
    round(100.0 * count(*) filter (where n_shops = 1) / count(*), 2) as pct_single_shop,
    count(*) filter (where n_shops >= 2) as multi_shop_clients,
    round(100.0 * count(*) filter (where n_shops >= 2) / count(*), 2) as pct_multi_shop
from client_shops;
-- total_clients  single_shop_clients  pct_single_shop  multi_shop_clients  pct_multi_shop
-- 5 926	      5 365	               90.53	        561	                9.47


-- 6. По аптекам: % транзакций с картами, доля выручки от карт, группировка
with shop_stats as (
    select 
        shop,
        -- Транзакции
        count(*) filter (where length(trim(card)) = 13) as tr_with_cards,
        count(*) filter (where length(trim(card)) != 13) as tr_without_cards,
        count(*) as total_tr,
        -- Выручка
        sum(summ_with_disc) filter (where length(trim(card)) = 13) as rev_with_cards,
        sum(summ_with_disc) filter (where length(trim(card)) != 13) as rev_without_cards,
        sum(summ_with_disc) as total_rev,
        -- % транзакций с картами
        round(100.0 * count(*) filter (where length(trim(card)) = 13) / count(*), 2) as pct_tr_with_cards,
        -- % выручки от карт (от общей выручки аптеки)
        round(100.0 * sum(summ_with_disc) filter (where length(trim(card)) = 13) / sum(summ_with_disc), 2) as pct_rev_from_cards
    from bonuscheques
    group by shop
)
select 
	shop,
	-- Группировка аптек
	case 
    	-- Аптека 6 и 11: неполный период (3 месяца данных)
    	when shop in ('Аптека 6', 'Аптека 11') then 'incompleted_period'
    	-- Высокая лояльность: выручка от карт > 80%
    	when pct_rev_from_cards > 80 then 'high_loyalty'
     	-- Средняя лояльность: выручка от карт 50-80%
     	when pct_rev_from_cards between 50 and 80 then 'medium_loyalty'
   	    -- Низкая лояльность: выручка от карт < 50%
    	else 'low_loyalty'
        end as shop_group,
	tr_with_cards,
	tr_without_cards,
	total_tr,
	rev_with_cards,
	rev_without_cards,
	total_rev,
	pct_tr_with_cards,
	pct_rev_from_cards
from shop_stats
order by pct_tr_with_cards desc, pct_rev_from_cards desc;
/*
shop	shop_group	tr_with_cards	tr_without_cards	total_tr	rev_with_cards	rev_without_cards	total_rev	pct_tr_with_cards	pct_rev_from_cards
"Аптека 10"	"high_loyalty"	"6 475"	"819"	"7 294"	"6 461 948"	"910 494"	"7 372 442"	"88,77"	"87,65"
"Аптека 11"	"incompleted_period"	"986"	"273"	"1 259"	"1 028 378"	"201 557"	"1 229 935"	"78,32"	"83,61"
"Аптека 6"	"incompleted_period"	"145"	"86"	"231"	"116 027"	"51 714"	"167 741"	"62,77"	"69,17"
"Аптека 8"	"medium_loyalty"	"2 074"	"1 397"	"3 471"	"1 396 787"	"858 306"	"2 255 093"	"59,75"	"61,94"
"Аптека 2"	"medium_loyalty"	"6 914"	"5 296"	"12 210"	"6 702 093"	"4 844 145"	"11 546 238"	"56,63"	"58,05"
"Аптека 7"	"low_loyalty"	"2 405"	"4 257"	"6 662"	"2 014 753"	"2 845 735"	"4 860 488"	"36,1"	"41,45"
"Аптека 4"	"low_loyalty"	"897"	"2 068"	"2 965"	"537 127"	"1 156 786"	"1 693 913"	"30,25"	"31,71"
"Аптека 1"	"low_loyalty"	"1 179"	"3 215"	"4 394"	"876 765"	"2 094 993"	"2 971 758"	"26,83"	"29,5"
*/