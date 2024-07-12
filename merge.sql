----------------------------------------------------------
--- Merge data from bulk upload into production tables ---
----------------------------------------------------------

-- measurements for geoip_lite database (3.2 million records)
-- if index is not present on country_blocks: 6 sec
-- if index is present on country_blocks: 88 sec
DELETE FROM COUNTRY_BLOCKS;

INSERT INTO COUNTRY_BLOCKS (
    network, geoname_id, registered_country_geoname_id, represented_country_geoname_id, is_anonymous_proxy, is_satellite_provider, postal_code, 
    latitude, longitude, accuracy_radius
)
SELECT
    network, geoname_id, registered_country_geoname_id, represented_country_geoname_id, is_anonymous_proxy, is_satellite_provider, postal_code, 
    to_number(replace(latitude, '.', ',')) as latitude,
    to_number(replace(longitude, '.', ',')) as longitude,
    accuracy_radius
FROM imp_country_blocks;

commit;
