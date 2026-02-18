/*
    Test: Review scores should be between 1 and 5.
*/

select
    order_item_key,
    order_id,
    review_score

from {{ ref('gld_fact_orders') }}

where review_score is not null
  and (review_score < 1 or review_score > 5)
