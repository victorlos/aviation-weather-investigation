
SELECT 
    ID                                  AS STATION_ID, 
    TO_DATE(date::varchar, 'YYYYMMDD')  AS DATE,
    ELEMENT                             AS ELEMENT,
    DATA_VALUE                          AS DATA_VALUE,
    Q_FLAG                              AS Q_FLAG
FROM {{ source('noaa_weather','raw_weather') }}
