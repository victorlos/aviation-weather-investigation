
with flights as (
    select
        flight_date,
        carrier_name,
        origin_airport_id,
        destination_airport_id,
        orig_airport_name,
        dest_airport_name,
        arrival_delay,
        coalesce(weather_delay, 0)                          as weather_delay_min,
        coalesce(nas_delay, 0)                              as nas_delay_min,
        coalesce(is_cancelled, false)                       as is_cancelled,
        cancellation_code,
        coalesce(arrival_delay_15, false)                   as is_delayed,
        coalesce(has_weather_data, false)                   as has_weather_data,
        coalesce(orig_bad_weather, false)
            or coalesce(orig_other_weather_issue, false)    as origin_bad_weather,
        coalesce(dest_bad_weather, false)
            or coalesce(dest_other_weather_issue, false)    as dest_bad_weather
    from {{ ref('fact_flights_weather_delay') }}
    where coalesce(is_cancelled, false)
       or coalesce(arrival_delay_15, false)                -- only disrupted flights
),

classified as (
    select
        *,
        case
            when is_cancelled and cancellation_code = 'B'
                then 'Weather cancellation'
            when is_cancelled and cancellation_code = 'C'
                 and (origin_bad_weather or dest_bad_weather)
                then 'NAS cancellation on a bad-weather day'
            when not is_cancelled and weather_delay_min > 0
                then 'Extreme weather delay'
            when not is_cancelled and nas_delay_min > 0
                 and (origin_bad_weather or dest_bad_weather)
                then 'NAS delay on a bad-weather day'
        end                                                 as disruption_type,

        case
            when origin_bad_weather and dest_bad_weather then 'Both airports'
            when origin_bad_weather                      then 'Origin airport'
            when dest_bad_weather                        then 'Destination airport'
            when not has_weather_data                    then 'No weather data'
            else 'No bad weather at either airport'
        end                                                 as weather_location
    from flights
),

weather_disruptions as (
    select
        *,
        iff(disruption_type in ('Weather cancellation', 'Extreme weather delay'),
            'Reported as weather', 'Hidden in NAS')         as attribution,
        case disruption_type
            when 'Extreme weather delay'          then weather_delay_min
            when 'NAS delay on a bad-weather day' then nas_delay_min
        end                                                 as weather_related_delay_min
    from classified
    where disruption_type is not null                       -- drop non-weather disruptions
)

select
    attribution,
    disruption_type,
    weather_location,
    count(*)                                                as flights,
    round(100 * ratio_to_report(count(*)) over (), 1)       as pct_of_weather_disruptions,
    round(avg(iff(is_cancelled, null, arrival_delay)), 1)   as avg_arrival_delay_min,
    sum(weather_related_delay_min)                          as weather_related_delay_min
from weather_disruptions
group by attribution, disruption_type, weather_location
order by attribution desc, flights desc