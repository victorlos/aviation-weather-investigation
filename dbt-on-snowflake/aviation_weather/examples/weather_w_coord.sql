SELECT 
ID, 
TO_DATE(date::varchar, 'YYYYMMDD') as DATE,
ELEMENT,
DATA_VALUE
FROM {{ source('noah_weather','raw_weather') }} rw
JOIN {{ dim_stations }} s
ON s.station_id = rw.ID