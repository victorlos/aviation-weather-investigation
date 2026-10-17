CREATE STAGE weather_data 
	URL = 's3://noaa-ghcn-pds' 
	DIRECTORY = ( ENABLE = true );