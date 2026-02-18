/*
    Dimension: Date
    Grain: one row per calendar date

    Generates a date spine from the earliest to latest order date.
*/

with date_spine as (

    select
        generate_series(
            '2016-01-01'::date,
            '2018-12-31'::date,
            '1 day'::interval
        )::date as date_day

),

final as (

    select
        to_char(date_day, 'YYYYMMDD')::int             as date_key,
        date_day                                        as order_date,
        extract(year from date_day)::int                as year,
        extract(quarter from date_day)::int             as quarter,
        extract(month from date_day)::int               as month,
        to_char(date_day, 'Month')                      as month_name,
        extract(week from date_day)::int                as week,
        to_char(date_day, 'Day')                        as day_name,
        extract(isodow from date_day)::int              as day_of_week,
        case
            when extract(isodow from date_day) in (6, 7) then true
            else false
        end                                             as is_weekend,
        to_char(date_day, 'YYYY-Q')                     as year_quarter,
        to_char(date_day, 'YYYY-MM')                    as year_month

    from date_spine

)

select * from final
