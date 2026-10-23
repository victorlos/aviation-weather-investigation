
  
    

        create or replace transient table AVIATION_WEATHER_PROJECT.DEV.dim_flight_carrier
         as
        (SELECT
    CODE ,
    DESCRIPTION as NAME
FROM AVIATION_WEATHER_PROJECT.PUBLIC.raw_carrier_lookup
        );
      
  