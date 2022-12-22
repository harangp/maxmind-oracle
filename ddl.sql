/**
 * MaxMind tables for GeoIP2 / GeoLite2 databases. Extended and indexed for maximum query efficiency
 * Author: Harang Péter
 */

---
--- Accessing country-level information
---

create table country_blocks (
	network varchar2(19) not null,
	geoname_id number not null,
	registered_country_geoname_id number,
	represented_country_geoname_id number,
	is_anonymous_proxy number not null,
	is_satellite_provider number(1) not null,
	significant_bits number as (to_number(regexp_substr(network, '\d+', 1, 5))),
	bitmask number as (bitand(4294967295 * power(2, 32 - to_number(regexp_substr(network, '\d+', 1, 5))), 4294967295)),
	masked_network number as (bitand(
		to_number(regexp_substr(network, '\d+', 1, 1)) * 16777216 +
		to_number(regexp_substr(network, '\d+', 1, 2)) * 65536 +
		to_number(regexp_substr(network, '\d+', 1, 3)) * 256 +
		to_number(regexp_substr(network, '\d+', 1, 4)),
		bitand(4294967295 * power(2, 32 - to_number(regexp_substr(network, '\d+', 1, 5))), 4294967295)
	))
);

create index idx_country_blocks_masked_network on country_blocks (masked_network, significant_bits) compress 1 compute statistics;
create index idx_country_blocks_network on country_blocks (network) compress 1 compute statistics;

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
					ip,
					to_number(regexp_substr(ip, '\d+', 1, 1)) * 16777216 +
					to_number(regexp_substr(ip, '\d+', 1, 2)) * 65536 +
					to_number(regexp_substr(ip, '\d+', 1, 3)) * 256 +
					to_number(regexp_substr(ip, '\d+', 1, 4)) numip
				from dual
			) src, country_blocks
			where masked_network in (
				select 
					bitand(numip, bitand(4294967295 * power(2, rownum-1), 4294967295))
				from dual
				connect by rownum <= 32
			)
			order by significant_bits desc
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
					ip,
					to_number(regexp_substr(ip, '\d+', 1, 1)) * 16777216 +
					to_number(regexp_substr(ip, '\d+', 1, 2)) * 65536 +
					to_number(regexp_substr(ip, '\d+', 1, 3)) * 256 +
					to_number(regexp_substr(ip, '\d+', 1, 4)) numip
				from dual
			) src, country_blocks
			where masked_network in (
				select 
					bitand(numip, bitand(4294967295 * power(2, rownum-1), 4294967295))
				from dual
				connect by rownum <= 32
			)
			order by significant_bits desc
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
	geoname_id number not null,
	registered_country_geoname_id number,
	represented_country_geoname_id number,
	is_anonymous_proxy number(1) not null,
	is_satellite_provider number(1) not null,
	postal_code varchar2(18),
	latitude number,
	longitude number,
	accuracy_radius number,
	significant_bits number as (to_number(regexp_substr(network, '\d+', 1, 5))),
	bitmask number as (bitand(4294967295 * power(2, 32 - to_number(regexp_substr(network, '\d+', 1, 5))), 4294967295)),
	masked_network number as (bitand(
		to_number(regexp_substr(network, '\d+', 1, 1)) * 16777216 +
		to_number(regexp_substr(network, '\d+', 1, 2)) * 65536 +
		to_number(regexp_substr(network, '\d+', 1, 3)) * 256 +
		to_number(regexp_substr(network, '\d+', 1, 4)),
		bitand(4294967295 * power(2, 32 - to_number(regexp_substr(network, '\d+', 1, 5))), 4294967295)
	))
);

create index idx_city_blocks_masked_network on city_blocks (masked_network, significant_bits) compress 1 compute statistics;

create table city_locations (
	geoname_id number not null,
	locale_code char(2),
	continent_code char(2),
	continent_name varchar2(128),
	country_iso_code char(2),
	country_name  varchar2(128),
	subdivision_1_iso_code varchar2(2),
	subdivision_1_name varchar(128),
	subdivision_2_iso_code varchar2(2),
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
					ip,
					to_number(regexp_substr(ip, '\d+', 1, 1)) * 16777216 +
					to_number(regexp_substr(ip, '\d+', 1, 2)) * 65536 +
					to_number(regexp_substr(ip, '\d+', 1, 3)) * 256 +
					to_number(regexp_substr(ip, '\d+', 1, 4)) numip
				from dual
			) src, city_blocks
			where masked_network in (
				select 
					bitand(numip, bitand(4294967295 * power(2, rownum-1), 4294967295))
				from dual
				connect by rownum <= 32
			)
			order by significant_bits desc
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
					ip,
					to_number(regexp_substr(ip, '\d+', 1, 1)) * 16777216 +
					to_number(regexp_substr(ip, '\d+', 1, 2)) * 65536 +
					to_number(regexp_substr(ip, '\d+', 1, 3)) * 256 +
					to_number(regexp_substr(ip, '\d+', 1, 4)) numip
				from dual
			) src, city_blocks
			where masked_network in (
				select 
					bitand(numip, bitand(4294967295 * power(2, rownum-1), 4294967295))
				from dual
				connect by rownum <= 32
			)
			order by significant_bits desc
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
