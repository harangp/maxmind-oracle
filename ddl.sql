-- country blocks table
-- standard data structure is extended with virtual columns precalculating the number representation of the (masked)network address
create table country_blocks (
	network varchar2(19) not null,
	geoname_id number not null,
	registered_country_geoname_id number,
	represented_country_geoname_id number,
	is_anonymous_proxy number(1) not null,
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

-- this index will be used to query the country_blocks table
create index idx_country_blocks_masked_network on country_blocks (masked_network, significant_bits) compress 1 compute statistics;

-- country lookup table. geoname_id equals from the country_blocks.geoname_id. Foreign keys are not used as it would slow down data upload
create table country_locations (
	geoname_id number not null,
	locale_code char(2),
	continent_code char(2),
	continent_name varchar2(128),
	country_iso_code char(2),
	country_name  varchar2(128),
	is_in_european_union number(1)
);

-- for fast id-based lookup
create index idx_country_locations_geoname on country_locations (geoname_id) compute statistics;

-- function to retreive the geoname_id for a given ip address
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

-- city blocks table
-- standard data structure is extended with virtual columns precalculating the number representation of the (masked)network address
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
	accuracy_radious number,
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

-- this index will be used to query the country_blocks table
create index idx_city_blocks_masked_network on city_blocks (masked_network, significant_bits) compress 1 compute statistics;

-- country lookup table. geoname_id equals from the country_blocks.geoname_id. Foreign keys are not used as it would slow down data upload
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

-- for fast id-based lookup
create index idx_city_locations_geoname on city_locations (geoname_id) compute statistics;

-- function to retreive the geoname_id for a given ip address
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
