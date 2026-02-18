with source as (

    select * from {{ source('raw', 'raw_customers') }}

),

cleaned as (

    select
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix       as customer_zip,
        initcap(customer_city)         as customer_city,
        upper(customer_state)          as customer_state

    from source
    where customer_id is not null

)

select * from cleaned
