/*
    Dimension: Sellers
    Grain: one row per seller_id

    Includes performance metrics for seller scorecard.
*/

with sellers as (

    select * from {{ ref('brz_sellers') }}

),

order_items as (

    select * from {{ ref('brz_order_items') }}

),

reviews as (

    select
        order_id,
        avg(review_score)::numeric(3,2) as review_score
    from {{ ref('brz_order_reviews') }}
    group by order_id

),

seller_metrics as (

    select
        oi.seller_id,
        count(distinct oi.order_id)                    as total_orders,
        count(*)                                       as total_items_sold,
        sum(oi.price)                                  as total_revenue,
        avg(oi.price)::numeric(10,2)                   as avg_item_price,
        avg(r.review_score)::numeric(3,2)              as avg_review_score

    from order_items oi
    left join reviews r
        on oi.order_id = r.order_id
    group by oi.seller_id

),

final as (

    select
        s.seller_id                                    as seller_key,
        s.seller_id,
        s.seller_city,
        s.seller_state,
        s.seller_zip,

        -- Seller performance
        coalesce(m.total_orders, 0)                    as total_orders,
        coalesce(m.total_items_sold, 0)                as total_items_sold,
        coalesce(m.total_revenue, 0)                   as total_revenue,
        coalesce(m.avg_item_price, 0)                  as avg_item_price,
        m.avg_review_score,

        -- Seller tier
        case
            when coalesce(m.total_revenue, 0) = 0 then 'Inactive'
            when m.total_revenue >= 50000 then 'Platinum'
            when m.total_revenue >= 10000 then 'Gold'
            when m.total_revenue >= 1000  then 'Silver'
            else 'Bronze'
        end as seller_tier

    from sellers s
    left join seller_metrics m
        on s.seller_id = m.seller_id

)

select * from final
