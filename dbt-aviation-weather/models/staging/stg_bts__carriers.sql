
SELECT
    CODE AS CARRIER_CODE,
    DESCRIPTION AS CARRIER_NAME
FROM {{ source('bts','raw_carrier_lookup') }}
