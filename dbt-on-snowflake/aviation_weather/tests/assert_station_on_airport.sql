
SELECT 
    airport,
    display_airport_name,
    display_airport_city_name_full
FROM {{ source('bts', 'raw_airport_coordinates') }} AS raw_airports
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ ref('dim_airports') }} AS dim_airports
    WHERE dim_airports.airport_id = raw_airports.airport_id
)
AND AIRPORT_IS_LATEST = 1 -- FILTER FOR LAST ROW OF AIRPORT IN SOURCE
AND AIRPORT_IS_CLOSED = 0 -- FILTER FOR OPEN AIRPORTS
AND AIRPORT_COUNTRY_CODE_ISO = 'US' --FILTER FOR US AIRPORTS ONLY
