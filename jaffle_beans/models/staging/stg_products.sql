with source as (

    select * from {{ source('raw', 'raw_products') }}

),

renamed as (

    select
        product_id,
        product_name,
        category,
        cast(price as numeric) as price,
        cast(cost as numeric) as cost,
        is_available

    from source

)

select * from renamed
