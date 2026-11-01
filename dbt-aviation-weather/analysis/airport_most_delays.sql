
{% set min_flights = 1000 %}        {# skip small airports, where a few delays dominate the rate #}
{% set delay_threshold_min = 15 %}  {# DOT definition of a delayed flight #}
{% set top_n = 20 %}

with flights as (
    select
        originairportid                  as airport_id,
        cancelled = 1                    as is_cancelled,
        depdelay                         as dep_delay_min,
        coalesce(carrierdelay, 0)        as carrier_delay_min,
        coalesce(weatherdelay, 0)        as weather_delay_min,
        coalesce(nasdelay, 0)            as nas_delay_min,
        coalesce(securitydelay, 0)       as security_delay_min,
        coalesce(lateaircraftdelay, 0)   as late_aircraft_delay_min
    from {{ ref('fact_flights') }}
),

airport_stats as (
    select
        airport_id,
        count(*)                                                        as total_flights,
        count_if(not is_cancelled)                                      as operated_flights,
        count_if(not is_cancelled
                 and dep_delay_min >= {{ delay_threshold_min }})        as delayed_departures,
        count_if(is_cancelled)                                          as cancelled_flights,
        avg(iff(dep_delay_min >= {{ delay_threshold_min }},
                dep_delay_min, null))                                   as avg_delay_when_late_min,
        sum(carrier_delay_min)                                          as carrier_delay_min,
        sum(weather_delay_min)                                          as weather_delay_min,
        sum(nas_delay_min)                                              as nas_delay_min,
        sum(security_delay_min)                                         as security_delay_min,
        sum(late_aircraft_delay_min)                                    as late_aircraft_delay_min
    from flights
    group by airport_id
    having count(*) >= {{ min_flights }}
),

with_rates as (
    select
        *,
        delayed_departures / nullif(operated_flights, 0)                as delay_rate,
        carrier_delay_min + weather_delay_min + nas_delay_min
            + security_delay_min + late_aircraft_delay_min              as total_cause_min
    from airport_stats
)

select
    rank() over (order by r.delay_rate desc)                            as delay_rank,
    r.airport_id,
    a.airport                                                           as airport_code,
    a.display_airport_name                                              as airport_name,
    a.display_airport_city_name_full                                    as city,
    r.total_flights,
    r.delayed_departures,
    round(100 * r.delay_rate, 1)                                        as delay_rate_pct,
    round(100 * r.cancelled_flights / r.total_flights, 1)               as cancellation_rate_pct,
    round(r.avg_delay_when_late_min, 1)                                 as avg_delay_when_late_min,

    -- share of delay minutes by cause
    round(100 * r.carrier_delay_min       / nullif(r.total_cause_min, 0), 1) as carrier_pct,
    round(100 * r.weather_delay_min       / nullif(r.total_cause_min, 0), 1) as weather_pct,
    round(100 * r.nas_delay_min           / nullif(r.total_cause_min, 0), 1) as nas_pct,
    round(100 * r.security_delay_min      / nullif(r.total_cause_min, 0), 1) as security_pct,
    round(100 * r.late_aircraft_delay_min / nullif(r.total_cause_min, 0), 1) as late_aircraft_pct,

    case greatest(r.carrier_delay_min, r.weather_delay_min, r.nas_delay_min,
                  r.security_delay_min, r.late_aircraft_delay_min)
        when r.late_aircraft_delay_min then 'Late aircraft'
        when r.carrier_delay_min       then 'Carrier'
        when r.nas_delay_min           then 'NAS (air traffic, non-extreme weather)'
        when r.weather_delay_min       then 'Extreme weather'
        when r.security_delay_min      then 'Security'
    end                                                                 as main_delay_cause

from with_rates r
left join {{ ref('dim_airports') }} a
    on r.airport_id = a.airport_id
order by delay_rank
limit {{ top_n }}