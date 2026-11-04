
{{
    config(
        materialized = 'incremental',
        unique_key = ['STATION_ID', 'DATE'],
        on_schema_change = 'sync_all_columns',
    )
}}

SELECT 
    STATION_ID, 
    DATE,
    max(iff(ELEMENT = 'PRCP', DATA_VALUE / 10, null)) >= 25  as IS_HEAVY_RAIN,
    max(iff(ELEMENT = 'WSF5', DATA_VALUE / 10 , null)) >= 15 as IS_HIGH_WIND,
    max(iff(ELEMENT = 'TMIN', DATA_VALUE / 10 , null )) <= 0 as IS_FREEZING,
    max(iff(ELEMENT = 'PRCP', DATA_VALUE / 10, null))  as PRECIP_MM,
    max(iff(ELEMENT = 'WSF5', DATA_VALUE / 10, null))  as MAX_GUST_MS,
    max(iff(ELEMENT = 'TMIN', DATA_VALUE / 10, null))  as TMIN_C,
    max(iff(ELEMENT = 'WT03', 1, 0)) = 1          as IS_THUNDER,
    max(iff(ELEMENT in ('WT01','WT02','WT21','WT22'), 1, 0)) = 1 as IS_FOG,
    max(iff(ELEMENT in ('WT06','WT15','WT17'), 1, 0)) = 1        as IS_ICING
FROM {{ ref('stg_noaa__weather') }}
WHERE STATION_ID like 'USW%' -- FILTER FOR STATIONS AT AIRPORTS
AND Q_FLAG IS NULL -- FILTER FOR QUALITY DATA

{% if is_incremental() %}

    AND (DATE >= (SELECT DATEADD( 'day', -30, MAX(DATE) ) FROM {{ this }})) -- ONLY GET NEW DATA

{% endif %}

GROUP BY 1,2

