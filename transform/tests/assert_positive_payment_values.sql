/*
    Test: All payment values in the fact table should be non-negative.
    This test returns rows that violate the assertion (dbt convention).
*/

select
    order_item_key,
    order_id,
    price,
    freight_value

from {{ ref('gld_fact_orders') }}

where price < 0
   or freight_value < 0
