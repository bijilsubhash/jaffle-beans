with customers as (

    select * from {{ ref('stg_customers') }}

),

orders as (

    select * from {{ ref('int_orders_enriched') }}

),

customer_orders as (

    select
        customer_id,
        count(*) as total_orders,
        count(case when status = 'completed' then 1 end) as completed_orders,
        count(case when status = 'cancelled' then 1 end) as cancelled_orders,
        count(case when status = 'refunded' then 1 end) as refunded_orders,
        sum(case when status = 'completed' then net_payment else 0 end) as lifetime_value,
        avg(case when status = 'completed' then item_total else null end) as avg_order_value,
        min(ordered_at) as first_order_at,
        max(ordered_at) as last_order_at

    from orders
    group by 1

)

select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.loyalty_tier,
    c.created_at as customer_since,
    coalesce(co.total_orders, 0) as total_orders,
    coalesce(co.completed_orders, 0) as completed_orders,
    coalesce(co.cancelled_orders, 0) as cancelled_orders,
    coalesce(co.refunded_orders, 0) as refunded_orders,
    coalesce(co.lifetime_value, 0) as lifetime_value,
    co.avg_order_value,
    co.first_order_at,
    co.last_order_at,
    timestamp_diff(co.last_order_at, co.first_order_at, day) as customer_tenure_days

from customers c
left join customer_orders co on c.customer_id = co.customer_id
