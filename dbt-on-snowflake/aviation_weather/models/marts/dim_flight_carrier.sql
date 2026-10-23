
SELECT
    CODE ,
    DESCRIPTION as NAME
FROM {{ source('bts','raw_carrier_lookup') }}