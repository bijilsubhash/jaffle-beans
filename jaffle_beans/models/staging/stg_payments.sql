with source as (

    select * from {{ source('raw', 'raw_payments') }}

),

renamed as (

    select
        payment_id,
        order_id,
        payment_method,
        cast(amount as numeric) as amount,
        status,
        cast(created_at as timestamp) as created_at

    from source

)

select * from renamed
