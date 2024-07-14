/**
 * MaxMind tables for GeoIP2 / GeoLite2 databases. Extended and indexed for maximum query efficiency
 * Author: Harang Péter
 */

---
--- Accessing country-level information
--- Table holds all of the fields that are required for experiments. Remove the ones you don't need in production.
--- Also note, that Maxmind's country blocks do not contain lat/long coordinates and postal codes.
---

create table country_blocks (
	network varchar2(19) not null,
	geoname_id number,
	registered_country_geoname_id number,
	represented_country_geoname_id number,
	is_anonymous_proxy number(1),
	is_satellite_provider number(1),
	-- virtual columns
	significant_bits number as (to_number(regexp_substr(network, '\d+', 1, 5))),
	bitmask number as (bitand(4294967295 * power(2, 32 - to_number(regexp_substr(network, '\d+', 1, 5))), 4294967295)),
	masked_network number as (bitand(
		to_number(regexp_substr(network, '\d+', 1, 1)) * 16777216 +
		to_number(regexp_substr(network, '\d+', 1, 2)) * 65536 +
		to_number(regexp_substr(network, '\d+', 1, 3)) * 256 +
		to_number(regexp_substr(network, '\d+', 1, 4)),
		bitand(4294967295 * power(2, 32 - to_number(regexp_substr(network, '\d+', 1, 5))), 4294967295)
	)),
    	upper_bound number as (bitor(
		to_number(regexp_substr(network, '\d+', 1, 1)) * 16777216 +
		to_number(regexp_substr(network, '\d+', 1, 2)) * 65536 +
		to_number(regexp_substr(network, '\d+', 1, 3)) * 256 +
		to_number(regexp_substr(network, '\d+', 1, 4)),
		(power(2, 32 - to_number(regexp_substr(network, '\d+', 1, 5))) - 1)
    	))
);

create index idx_country_blocks_masked_network on country_blocks (masked_network, significant_bits) compress 1 compute statistics;
-- if you don't use upper_bound colum, this index is not required
create index idx_country_blocks_network_bounds on country_blocks (masked_network, upper_bound) compress 1 compute statistics;

create table country_locations (
	geoname_id number not null,
	locale_code char(2),
	continent_code char(2),
	continent_name varchar2(128),
	country_iso_code char(2),
	country_name  varchar2(128),
	is_in_european_union number(1)
);

create index idx_country_locations_geoname on country_locations (geoname_id) compute statistics;

/**
 * retrieving the country geoname_id for the best matching IP address
 */
create or replace function getCountryGeoNameId (ip in varchar2)
	return number
	is ret number;
	begin
		select geoname_id
		into ret
		from (
			select
				src.*, country_blocks.*
			from (
				select
					:ip,
					to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
					to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
					to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
					to_number(regexp_substr(:ip, '\d+', 1, 4)) numip,
					bitand(
						to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
						to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
						to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
						to_number(regexp_substr(:ip, '\d+', 1, 4)),
						power(2, 32) - 1  - (power(2, rownum - 1) - 1)
					) as masked_numip,
					33 - rownum as generated_network_bits
				from dual
				connect by rownum <= 32
			) src, country_blocks
			where masked_network = masked_numip and significant_bits <= generated_network_bits
			order by generated_network_bits desc, significant_bits desc
		) where rownum <= 1;
		
		return ret;
	end;
/

create or replace function getCountryBlock (ip in varchar2)
	return country_blocks%ROWTYPE
	is ret country_blocks%ROWTYPE;
	begin
		select *
		into ret
		from (
			select
				country_blocks.*
			from (
				select
					:ip,
					to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
					to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
					to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
					to_number(regexp_substr(:ip, '\d+', 1, 4)) numip,
					bitand(
						to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
						to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
						to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
						to_number(regexp_substr(:ip, '\d+', 1, 4)),
						power(2, 32) - 1  - (power(2, rownum - 1) - 1)
					) as masked_numip,
					33 - rownum as generated_network_bits
				from dual
				connect by rownum <= 32
			) src, country_blocks
			where masked_network = masked_numip and significant_bits <= generated_network_bits
			order by generated_network_bits desc, significant_bits desc
		) where rownum <= 1;
		
		return ret;
	end;
/

create or replace function getCountryBlockNetwork (ip in varchar2)
	return varchar2
	is ret country_blocks%ROWTYPE;
	begin
        ret := getCountryBlock(ip);
		return ret.network;
	end;
/

---
--- Accessing city-level information
---

create table city_blocks (
	network varchar2(19) not null,
	-- unfortunately, there are some records with no geoname information
	geoname_id number,
	registered_country_geoname_id number,
	represented_country_geoname_id number,
	is_anonymous_proxy number(1) not null,
	is_satellite_provider number(1) not null,
	postal_code varchar2(18),
	latitude number,
	longitude number,
	accuracy_radius number,
	-- virtual columns
	significant_bits number as (to_number(regexp_substr(network, '\d+', 1, 5))),
	bitmask number as (bitand(4294967295 * power(2, 32 - to_number(regexp_substr(network, '\d+', 1, 5))), 4294967295)),
	masked_network number as (bitand(
		to_number(regexp_substr(network, '\d+', 1, 1)) * 16777216 +
		to_number(regexp_substr(network, '\d+', 1, 2)) * 65536 +
		to_number(regexp_substr(network, '\d+', 1, 3)) * 256 +
		to_number(regexp_substr(network, '\d+', 1, 4)),
		bitand(4294967295 * power(2, 32 - to_number(regexp_substr(network, '\d+', 1, 5))), 4294967295)
	)),
    	upper_bound number as (bitor(
		to_number(regexp_substr(network, '\d+', 1, 1)) * 16777216 +
		to_number(regexp_substr(network, '\d+', 1, 2)) * 65536 +
		to_number(regexp_substr(network, '\d+', 1, 3)) * 256 +
		to_number(regexp_substr(network, '\d+', 1, 4)),
		(power(2, 32 - to_number(regexp_substr(network, '\d+', 1, 5))) - 1)
    	))
);

-- if you don't use upper_bound colum, this index is not required
create index idx_city_blocks_network_bounds on city_blocks (masked_network, upper_bound) compress 1 compute statistics;
create index idx_city_blocks_masked_network on city_blocks (masked_network, significant_bits) compress 1 compute statistics;

create table city_locations (
	geoname_id number not null,
	locale_code char(2),
	continent_code char(2),
	continent_name varchar2(128),
	country_iso_code char(2),
	country_name  varchar2(128),
	subdivision_1_iso_code char(3),
	subdivision_1_name varchar(128),
	subdivision_2_iso_code char(3),
	subdivision_2_name varchar(128),
	city_name varchar2(128),
	metro_code varchar2(18),
	time_zone varchar2(128),
	is_in_european_union number(1)
);

create index idx_city_locations_geoname on city_locations (geoname_id) compute statistics;

/**
 * retrieving the city geoname_id for the best matching IP address
 */
create or replace function getCityGeoNameId (ip in varchar2)
	return number
	is ret number;
	begin
		select geoname_id
		into ret
		from (
			select
				src.*, city_blocks.*
			from (
				select
					:ip,
					to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
					to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
					to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
					to_number(regexp_substr(:ip, '\d+', 1, 4)) numip,
					bitand(
						to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
						to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
						to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
						to_number(regexp_substr(:ip, '\d+', 1, 4)),
						power(2, 32) - 1  - (power(2, rownum - 1) - 1)
					) as masked_numip,
					33 - rownum as generated_network_bits
				from dual
				connect by rownum <= 32
			) src, city_blocks
			where masked_network = masked_numip and significant_bits <= generated_network_bits
			order by generated_network_bits desc, significant_bits desc
		) where rownum <= 1;
		
		return ret;
	end;
/

/**
 * retrieving the city_block row record for the best matching IP address
 * use it in stored procedures. For details, check README.md
 */
create or replace function getCityBlock (ip in varchar2)
	return city_blocks%ROWTYPE
	is ret city_blocks%ROWTYPE;
	begin
		select *
		into ret
		from (
			select
				city_blocks.*
			from (
				select
					:ip,
					to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
					to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
					to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
					to_number(regexp_substr(:ip, '\d+', 1, 4)) numip,
					bitand(
						to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
						to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
						to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
						to_number(regexp_substr(:ip, '\d+', 1, 4)),
						power(2, 32) - 1  - (power(2, rownum - 1) - 1)
					) as masked_numip,
					33 - rownum as generated_network_bits
				from dual
				connect by rownum <= 32
			) src, city_blocks
			where masked_network = masked_numip and significant_bits <= generated_network_bits
			order by generated_network_bits desc, significant_bits desc
		) where rownum <= 1;
		
		return ret;
	end;
/

create or replace function getCityBlockNetwork (ip in varchar2)
	return varchar2
	is ret city_blocks%ROWTYPE;
	begin
        ret := getCityBlock(ip);
		return ret.network;
	end;
/
