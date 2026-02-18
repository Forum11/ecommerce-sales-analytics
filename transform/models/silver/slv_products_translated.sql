/*
    Products with English category names joined from the translation seed.
*/

with products as (

    select * from {{ ref('brz_products') }}

),

translation as (

    select * from {{ ref('product_category_translation') }}

),

translated as (

    select
        p.product_id,
        p.product_category_name                as product_category_portuguese,
        coalesce(
            t.product_category_name_english,
            p.product_category_name,
            'unknown'
        )                                      as product_category,
        p.product_name_length,
        p.product_description_length,
        p.product_photos_qty,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm

    from products p
    left join translation t
        on p.product_category_name = t.product_category_name

)

select * from translated
