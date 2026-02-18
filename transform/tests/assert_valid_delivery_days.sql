/*
    Test: Delivery days should be null or non-negative for delivered orders.
    Negative delivery days would indicate a data quality issue.
*/

select
    order_item_key,
    order_id,
    delivery_days,
    order_status

from {{ ref('gld_fact_orders') }}

where order_status = 'delivered'
  and delivery_days is not null
  and delivery_days < 0
