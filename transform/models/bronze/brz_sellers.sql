with source as (

    select * from {{ source('raw', 'raw_sellers') }}

),

cleaned as (

    select
        seller_id,
        seller_zip_code_prefix         as seller_zip,
        initcap(seller_city)           as seller_city,
        upper(seller_state)            as seller_state

    from source
    where seller_id is not null

)

select * from cleaned
