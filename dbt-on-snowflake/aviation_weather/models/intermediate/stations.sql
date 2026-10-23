
SELECT 
  TRIM(SUBSTR(ALL_DATA, 1, 11))           AS station_id,
  TRY_TO_DOUBLE(SUBSTR(ALL_DATA, 13, 8))  AS latitude,
  TRY_TO_DOUBLE(SUBSTR(ALL_DATA, 22, 9))  AS longitude,
  TRY_TO_DOUBLE(SUBSTR(ALL_DATA, 32, 6))  AS alttiude,
  TRIM(SUBSTR(ALL_DATA, 39, 2))           AS state,
  TRIM(SUBSTR(ALL_DATA, 42, 30))          AS name
FROM {{ source('noah_weather','raw_stations') }}
WHERE 1=1
AND TRIM(SUBSTR(ALL_DATA, 1, 3)) = 'USW' -- ONLY GET STATIONS AT US AIRPORTS