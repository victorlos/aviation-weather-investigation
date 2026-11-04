
SELECT 
    ff.FLIGHT_DATE,
    ff.CARRIER_NAME,
    ff.ORIGIN_AIRPORT_ID,
    ff.DESTINATION_AIRPORT_ID,
    ff.ARRIVAL_DELAY,
    ff.WEATHER_DELAY,
    da_orig.display_airport_name orig_airport_name,
    da_orig.display_airport_city_name_full orig_city,
    da_orig.distance_km orig_dist_airport_station,
    (fw_orig.station_id IS NOT NULL AND fw_dest.station_id IS NOT NULL) AS has_weather_data, -- CHECK IF BOTH ORIGIN AND DESTINATION AIRPORTS HAVE WEATHER DATA
    (fw_orig.IS_HEAVY_RAIN OR fw_orig.IS_HIGH_WIND OR fw_orig.IS_FREEZING OR fw_orig.precip_mm > 25) orig_bad_weather,
    (fw_orig.IS_THUNDER OR fw_orig.IS_FOG OR fw_orig.IS_ICING) as orig_other_weather_issue,
    da_dest.display_airport_name dest_airport_name,
    da_dest.display_airport_city_name_full dest_city,
    da_dest.distance_km dest_dist_airport_station,
    (fw_dest.IS_HEAVY_RAIN OR fw_dest.IS_HIGH_WIND OR fw_dest.IS_FREEZING OR fw_dest.precip_mm > 25) dest_bad_weather,
    (fw_dest.IS_THUNDER OR fw_dest.IS_FOG OR fw_dest.IS_ICING) as dest_other_weather_issue,
    ff.NAS_DELAY,
    ff.IS_CANCELLED,
    ff.CANCELLATION_CODE, 
    ff.ARRIVAL_DELAY_15
FROM {{ ref('fact_flights') }} ff
LEFT JOIN {{ ref('dim_airports') }} da_dest
ON ff.DESTINATION_AIRPORT_ID = da_dest.AIRPORT_CODE
LEFT JOIN {{ ref('dim_airports') }} da_orig
ON ff.ORIGIN_AIRPORT_ID = da_orig.AIRPORT_CODE
LEFT JOIN {{ ref('fact_weather') }} fw_dest
ON fw_dest.date = ff.FLIGHT_DATE      -- MATCH ON THE WEATHER FOR EACH DATE
AND da_dest.STATION_ID = fw_dest.STATION_ID -- ONLY GET WEATHER FROM AIRPORTS WITH CLOSE STATION
LEFT JOIN {{ ref('fact_weather') }} fw_orig
ON fw_orig.date = ff.FLIGHT_DATE      -- MATCH ON THE WEATHER FOR EACH DATE
AND da_orig.STATION_ID = fw_orig.STATION_ID -- ONLY GET WEATHER FROM AIRPORTS WITH CLOSE STATION
