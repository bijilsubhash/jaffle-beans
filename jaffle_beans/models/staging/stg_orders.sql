with source as (

    select * from {{ source('raw', 'raw_orders') }}

),

renamed as (

    select
        order_id,
        customer_id,
        store_id,
        cast(order_date as timestamp) as ordered_at,
        status,
        is_online,
        cast(created_at as timestamp) as created_at,
        cast(updated_at as timestamp) as updated_at

    from source

)

select * from renamed
