/*
    Fact table: One row per order line item.
    Grain: order_id + order_item_id

    Contains all measurable facts about each order item,
    with foreign keys to all dimension tables.
*/

with order_items as (

    select * from {{ ref('brz_order_items') }}

),

orders as (

    select * from {{ ref('slv_orders_enriched') }}

),

reviews as (

    select
        order_id,
        avg(review_score)::numeric(3,2) as review_score
    from {{ ref('brz_order_reviews') }}
    group by order_id

),

fact as (

    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['oi.order_id', 'oi.order_item_id']) }}
            as order_item_key,

        -- Foreign keys
        oi.order_id,
        oi.order_item_id,
        o.customer_id                                  as customer_key,
        oi.product_id                                  as product_key,
        oi.seller_id                                   as seller_key,
        to_char(o.order_purchase_timestamp, 'YYYYMMDD')::int
            as date_key,

        -- Order attributes
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,

        -- Measures
        oi.price,
        oi.freight_value,
        oi.price + oi.freight_value                    as total_item_value,

        -- Delivery metrics
        o.delivery_days,
        o.delivery_vs_estimate_days,
        o.is_delivered_on_time,

        -- Review
        r.review_score,

        -- Payment context
        o.primary_payment_type,
        o.max_installments

    from order_items oi
    inner join orders o
        on oi.order_id = o.order_id
    left join reviews r
        on oi.order_id = r.order_id

)

select * from fact
