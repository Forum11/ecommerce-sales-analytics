/*
    Dimension: Products
    Grain: one row per product_id

    Includes English category name and sales aggregates.
*/

with products as (

    select * from {{ ref('slv_products_translated') }}

),

order_items as (

    select * from {{ ref('brz_order_items') }}

),

product_metrics as (

    select
        product_id,
        count(distinct order_id)                       as times_ordered,
        sum(price)                                     as total_revenue,
        avg(price)::numeric(10,2)                      as avg_price

    from order_items
    group by product_id

),

final as (

    select
        p.product_id                                   as product_key,
        p.product_id,
        p.product_category,
        p.product_category_portuguese,
        p.product_name_length,
        p.product_description_length,
        p.product_photos_qty,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,

        -- Product metrics
        coalesce(m.times_ordered, 0)                   as times_ordered,
        coalesce(m.total_revenue, 0)                   as total_revenue,
        coalesce(m.avg_price, 0)                       as avg_price

    from products p
    left join product_metrics m
        on p.product_id = m.product_id

)

select * from final
