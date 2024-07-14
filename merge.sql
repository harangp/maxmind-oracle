----------------------------------------------------------
--- Merge data from bulk import into production tables ---
--- imp_country_locations -> country_locations         ---
--- imp_country_blocks -> country_blocks               ---
----------------------------------------------------------

-- measurements for geoip_lite database (3.2 million records from city file)
-- if index is not present on country_blocks: 6 sec
-- if index is present on country_blocks: 88 sec
DELETE FROM COUNTRY_BLOCKS;

INSERT INTO COUNTRY_BLOCKS (
    network, geoname_id, registered_country_geoname_id, represented_country_geoname_id, is_anonymous_proxy, is_satellite_provider
)
SELECT
    network, geoname_id, registered_country_geoname_id, represented_country_geoname_id, is_anonymous_proxy, is_satellite_provider
FROM imp_country_blocks;

-- approx. 120.000 records
-- mere seconds with geoname_id indexed column
DELETE FROM COUNTRY_LOCATIONS;

insert into country_locations (
    geoname_id, locale_code, continent_code, continent_name, country_iso_code, country_name, is_in_european_union
) select 
    geoname_id, locale_code, continent_code, continent_name, country_iso_code, country_name, is_in_european_union
from imp_country_locations;

----------------------------------------------------------
--- Merge data from bulk import into production tables ---
--- imp_city_locations -> city_locations               ---
--- imp_city_blocks -> city_blocks                     ---
----------------------------------------------------------

DELETE FROM CITY_BLOCKS;

INSERT INTO CITY_BLOCKS (
    network, geoname_id, registered_country_geoname_id, represented_country_geoname_id, is_anonymous_proxy, is_satellite_provider, postal_code, 
    latitude, longitude, accuracy_radius
)
SELECT
    network, geoname_id, registered_country_geoname_id, represented_country_geoname_id, is_anonymous_proxy, is_satellite_provider, postal_code, 
    to_number(replace(latitude, '.', ',')) as latitude,
    to_number(replace(longitude, '.', ',')) as longitude,
    accuracy_radius
FROM imp_city_blocks;

DELETE FROM CITY_LOCATIONS;

insert into country_locations (
    geoname_id, locale_code, continent_code, continent_name, country_iso_code, country_name, 
    subdivision_1_iso_code, subdivision_1_name, subdivision_2_iso_code, subdivision_2_name, city_name, metro_code, time_zone,
    is_in_european_union
) select 
    geoname_id, locale_code, continent_code, continent_name, country_iso_code, country_name, 
    subdivision_1_iso_code, subdivision_1_name, subdivision_2_iso_code, subdivision_2_name, city_name, metro_code, time_zone,
    is_in_european_union
from imp_city_locations;

commit;
