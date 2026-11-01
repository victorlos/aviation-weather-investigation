
SELECT 
    count(*) all_flights,
    count(case when arrdelay >= 15 then 1 end) as bts_delayed_flights,
    count(case when arrdelay >= 15 and weatherdelay > 0 then 1 end) as bts_weather_delayed_flights,
    count(case when orig_bad_weather or dest_bad_weather or orig_other_weather_issue or dest_other_weather_issue then 1 end) as noaa_flights_with_bad_weather,
    count(case when (orig_bad_weather or dest_bad_weather or orig_other_weather_issue or dest_other_weather_issue) and (arrdelay >= 15 or weatherdelay > 0) then 1 end) as noaa_flights_with_bad_weather_delayed,
    count(case when CANCELLED = 1 then 1 end) as bts_cancelled_flights,
    count(case when CANCELLED = 1 and (orig_bad_weather or dest_bad_weather or orig_other_weather_issue or dest_other_weather_issue) then 1 end) as noaa_cancelled_flights_with_bad_weather
FROM {{ ref('fact_flights_weather_delay') }}
WHERE has_weather_data is true
