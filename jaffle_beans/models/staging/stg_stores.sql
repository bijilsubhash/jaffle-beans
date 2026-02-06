with source as (

    select * from {{ source('raw', 'raw_stores') }}

),

renamed as (

    select
        store_id,
        store_name,
        city,
        state,
        cast(opened_at as date) as opened_at,
        is_active

    from source

)

select * from renamed
