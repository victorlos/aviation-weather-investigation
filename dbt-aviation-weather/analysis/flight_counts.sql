
SELECT 
SELECT 
    count(*) all_flights,
    count(case when ARRIVAL_DELAY >= 15 then 1 end) as bts_delayed_flights,
    count(case when ARRIVAL_DELAY >= 15 and WEATHER_DELAY > 0 then 1 end) as bts_weather_delayed_flights,
    count(case when ORIG_BAD_WEATHER or DEST_BAD_WEATHER or ORIG_OTHER_WEATHER_ISSUE or DEST_OTHER_WEATHER_ISSUE then 1 end) as noaa_flights_with_bad_weather,
    count(case when (ORIG_BAD_WEATHER or DEST_BAD_WEATHER or ORIG_OTHER_WEATHER_ISSUE or DEST_OTHER_WEATHER_ISSUE) and (ARRIVAL_DELAY >= 15 or WEATHER_DELAY > 0) then 1 end) as noaa_flights_with_bad_weather_delayed,
    count(case when IS_CANCELLED = 1 then 1 end) as bts_cancelled_flights,
    count(case when IS_CANCELLED = 1 and (ORIG_BAD_WEATHER or DEST_BAD_WEATHER or ORIG_OTHER_WEATHER_ISSUE or DEST_OTHER_WEATHER_ISSUE) then 1 end) as noaa_cancelled_flights_with_bad_weather
FROM {{ ref('fact_flights_weather_delay') }}
WHERE HAS_WEATHER_DATA
