/*
    Dimension: Customers
    Grain: one row per customer_id

    Enriched with order-level aggregates for analytical convenience.
*/

with customers as (

    select * from {{ ref('brz_customers') }}

),

orders as (

    select * from {{ ref('slv_orders_enriched') }}

),

customer_metrics as (

    select
        customer_id,
        count(distinct order_id)                       as total_orders,
        sum(total_order_value)                         as lifetime_value,
        avg(total_order_value)::numeric(10,2)          as avg_order_value,
        min(order_purchase_timestamp)                  as first_order_date,
        max(order_purchase_timestamp)                  as last_order_date,
        avg(avg_review_score)::numeric(3,2)            as avg_review_score

    from orders
    group by customer_id

),

final as (

    select
        c.customer_id                                  as customer_key,
        c.customer_id,
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        c.customer_zip,

        -- Customer metrics
        coalesce(m.total_orders, 0)                    as total_orders,
        coalesce(m.lifetime_value, 0)                  as lifetime_value,
        coalesce(m.avg_order_value, 0)                 as avg_order_value,
        m.first_order_date,
        m.last_order_date,
        m.avg_review_score,

        -- Customer segment
        case
            when coalesce(m.total_orders, 0) = 0 then 'No Orders'
            when m.total_orders = 1 then 'One-Time'
            when m.total_orders between 2 and 3 then 'Repeat'
            else 'Loyal'
        end as customer_segment

    from customers c
    left join customer_metrics m
        on c.customer_id = m.customer_id

)

select * from final
