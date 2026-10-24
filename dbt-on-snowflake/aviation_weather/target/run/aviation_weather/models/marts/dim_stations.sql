
  
    

        create or replace transient table AVIATION_WEATHER_PROJECT.DEV.dim_stations
         as
        (SELECT 
  STATION_ID,
  LATITUDE,
  LONGITUDE,
  ALTITUDE,
  STATE,
  NAME
FROM AVIATION_WEATHER_PROJECT.PUBLIC.raw_stations
WHERE 
    TRIM(SUBSTR(ALL_DATA, 1, 3)) = 'USW' -- ONLY GET STATIONS AT US AIRPORTS
        );
      
  