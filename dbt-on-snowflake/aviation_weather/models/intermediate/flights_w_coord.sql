-- validate this later

SELECT * 
FROM {{ source( 'bts', 'raw_flights') }} rf
JOIN {{ source('bts', 'raw_airport_lookup') }} ori_air
ON rf.ORIGINAIRPORTID = ori_air.AIRPORTID
JOIN {{ source('bts', 'raw_airport_lookup') }} dest_air
ON rf.DESTAIRPORTID = dest_air.AIRPORTID