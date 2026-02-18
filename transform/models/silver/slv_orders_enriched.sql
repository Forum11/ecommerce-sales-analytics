/*
    Enriched orders: joins orders with aggregated items, payments, and reviews
    to create a single denormalized order-level table.
*/

with orders as (

    select * from {{ ref('brz_orders') }}

),

order_items_agg as (

    select
        order_id,
        count(*)                               as item_count,
        sum(price)                             as total_price,
        sum(freight_value)                     as total_freight,
        sum(price) + sum(freight_value)        as total_order_value,
        -- Take the first seller_id and product_id for fact table FK
        -- (orders with multiple items will have multiple rows in fact)
        min(seller_id)                         as primary_seller_id,
        min(product_id)                        as primary_product_id

    from {{ ref('brz_order_items') }}
    group by order_id

),

payments_agg as (

    select
        order_id,
        sum(payment_value)                     as total_payment_value,
        count(distinct payment_type)           as payment_type_count,
        max(payment_installments)              as max_installments,
        -- Most common payment type
        (
            select payment_type
            from {{ ref('brz_order_payments') }} p2
            where p2.order_id = p1.order_id
            order by payment_value desc
            limit 1
        )                                      as primary_payment_type

    from {{ ref('brz_order_payments') }} p1
    group by order_id

),

reviews_agg as (

    select
        order_id,
        avg(review_score)::numeric(3,2)        as avg_review_score,
        count(*)                               as review_count

    from {{ ref('brz_order_reviews') }}
    group by order_id

),

enriched as (

    select
        o.order_id,
        o.customer_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,

        -- Delivery metrics
        extract(day from (o.order_delivered_customer_date - o.order_purchase_timestamp))::int
            as delivery_days,
        extract(day from (o.order_estimated_delivery_date - o.order_delivered_customer_date))::int
            as delivery_vs_estimate_days,
        case
            when o.order_delivered_customer_date <= o.order_estimated_delivery_date then true
            else false
        end as is_delivered_on_time,

        -- Order items
        coalesce(oi.item_count, 0)             as item_count,
        coalesce(oi.total_price, 0)            as total_price,
        coalesce(oi.total_freight, 0)          as total_freight,
        coalesce(oi.total_order_value, 0)      as total_order_value,
        oi.primary_seller_id,
        oi.primary_product_id,

        -- Payments
        coalesce(pa.total_payment_value, 0)    as total_payment_value,
        pa.payment_type_count,
        pa.max_installments,
        pa.primary_payment_type,

        -- Reviews
        r.avg_review_score,
        coalesce(r.review_count, 0)            as review_count

    from orders o
    left join order_items_agg oi on o.order_id = oi.order_id
    left join payments_agg pa on o.order_id = pa.order_id
    left join reviews_agg r on o.order_id = r.order_id

)

select * from enriched
