with source as (

    select * from {{ source('raw', 'raw_order_items') }}

),

renamed as (

    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        cast(unit_price as numeric) as unit_price

    from source

)

select * from renamed
