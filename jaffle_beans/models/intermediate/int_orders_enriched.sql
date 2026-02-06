with orders as (

    select * from {{ ref('stg_orders') }}

),

order_items as (

    select * from {{ ref('stg_order_items') }}

),

products as (

    select * from {{ ref('stg_products') }}

),

payments as (

    select * from {{ ref('stg_payments') }}

),

order_items_summary as (

    select
        oi.order_id,
        count(*) as item_count,
        sum(oi.quantity) as total_quantity,
        sum(oi.quantity * oi.unit_price) as item_total

    from order_items oi
    group by 1

),

payment_summary as (

    select
        order_id,
        sum(case when status = 'success' then amount else 0 end) as amount_paid,
        sum(case when status = 'refund' then amount else 0 end) as amount_refunded,
        sum(amount) as net_payment,
        count(distinct payment_id) as payment_count

    from payments
    group by 1

)

select
    o.order_id,
    o.customer_id,
    o.store_id,
    o.ordered_at,
    o.status,
    o.is_online,
    coalesce(ois.item_count, 0) as item_count,
    coalesce(ois.total_quantity, 0) as total_quantity,
    coalesce(ois.item_total, 0) as item_total,
    coalesce(ps.amount_paid, 0) as amount_paid,
    coalesce(ps.amount_refunded, 0) as amount_refunded,
    coalesce(ps.net_payment, 0) as net_payment,
    coalesce(ps.payment_count, 0) as payment_count,
    o.created_at,
    o.updated_at

from orders o
left join order_items_summary ois on o.order_id = ois.order_id
left join payment_summary ps on o.order_id = ps.order_id
