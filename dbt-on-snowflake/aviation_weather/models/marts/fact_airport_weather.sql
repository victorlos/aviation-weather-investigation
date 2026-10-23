
SELECT 
ID, 
TO_DATE(date::varchar, 'YYYYMMDD') as DATE,
max(iff(element = 'PRCP', data_value / 10, null)) >= 25  as is_heavy_rain,
max(iff(element = 'WSF5', data_value / 10 , null)) >= 15 as is_high_wind,
max(iff(element = 'TMIN', data_value / 10 , null )) <= 0 as is_freezing,
max(iff(element = 'PRCP', data_value / 10, null))  as precip_mm,
max(iff(element = 'WSF5', data_value / 10, null))  as max_gust_ms,
max(iff(element = 'TMIN', data_value / 10, null))  as tmin_c,
max(iff(element = 'WT03', 1, 0)) = 1          as had_thunder,
max(iff(element in ('WT01','WT02','WT21','WT22'), 1, 0)) = 1 as had_fog,
max(iff(element in ('WT06','WT15','WT17'), 1, 0)) = 1        as had_icing
FROM {{ source('','raw_weather') }}
WHERE ID like 'USW%' -- FILTER FOR STATIONS AT AIRPORTS
GROUP BY 1,2