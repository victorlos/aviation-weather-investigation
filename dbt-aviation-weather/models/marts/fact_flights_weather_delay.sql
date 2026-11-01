
SELECT 
    ff.flightdate,
    ff.carrier_name,
    ff.originairportid,
    ff.destairportid,
    ff.arrdelay,
    ff.weatherdelay,
    da_orig.display_airport_name orig_airport_name,
    da_orig.display_airport_city_name_full orig_city,
    da_orig.distance_km orig_dist_airport_station,
    (fw_orig.station_id IS NOT NULL AND fw_dest.station_id IS NOT NULL) AS has_weather_data, -- CHECK IF BOTH ORIGIN AND DESTINATION AIRPORTS HAVE WEATHER DATA
    (fw_orig.is_heavy_rain OR fw_orig.is_high_wind OR fw_orig.is_freezing OR fw_orig.precip_mm > 25) orig_bad_weather,
    (fw_orig.had_thunder OR fw_orig.had_fog OR fw_orig.had_icing) as orig_other_weather_issue,
    da_dest.display_airport_name dest_airport_name,
    da_dest.display_airport_city_name_full dest_city,
    da_dest.distance_km dest_dist_airport_station,
    (fw_dest.is_heavy_rain OR fw_dest.is_high_wind OR fw_dest.is_freezing OR fw_dest.precip_mm > 25) dest_bad_weather,
    (fw_dest.had_thunder OR fw_dest.had_fog OR fw_dest.had_icing) as dest_other_weather_issue,
    ff.NASDELAY, 
    ff.CANCELLED, 
    ff.CANCELLATIONCODE, 
    ff.ARRDEL15
FROM {{ ref('fact_flights') }} ff
LEFT JOIN {{ ref('dim_airports') }} da_dest
ON ff.DESTAIRPORTID = da_dest.AIRPORT_ID
LEFT JOIN {{ ref('dim_airports') }} da_orig
ON ff.ORIGINAIRPORTID = da_orig.AIRPORT_ID
LEFT JOIN {{ ref('fact_weather') }} fw_dest
ON fw_dest.date = ff.flightdate      -- MATCH ON THE WEATHER FOR EACH DATE
AND da_dest.STATION_ID = fw_dest.STATION_ID -- ONLY GET WEATHER FROM AIRPORTS WITH CLOSE STATION
LEFT JOIN {{ ref('fact_weather') }} fw_orig
ON fw_orig.date = ff.flightdate      -- MATCH ON THE WEATHER FOR EACH DATE
AND da_orig.STATION_ID = fw_orig.STATION_ID -- ONLY GET WEATHER FROM AIRPORTS WITH CLOSE STATION
