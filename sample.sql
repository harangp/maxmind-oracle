-- cleanup
delete from city_blocks;
delete from city_locations;
commit;

-- city blocks test recordset from GeoLite2-City-CSV_20200407
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.0.0/24',2078025,2077456,null,0,0,5000,-34.9281,138.5999,1000);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.1.0/24',1814991,1814991,null,0,0,null,34.7725,113.7266,50);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.2.0/23',1814991,1814991,null,0,0,null,34.7725,113.7266,50);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.4.0/22',2077456,2077456,null,0,0,null,-33.4940,143.2104,1000);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.8.0/21',1814991,1814991,null,0,0,null,34.7725,113.7266,50);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.16.0/20',1861060,1861060,null,0,0,null,35.6900,139.6900,500);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.32.0/19',1814991,1814991,null,0,0,null,34.7725,113.7266,50);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.64.0/23',1862415,1861060,null,0,0,734-0011,34.3401,132.4439,10);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.66.0/23',1863018,1861060,null,0,0,738-0041,34.3426,132.3071,20);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.68.0/24',6822110,1861060,null,0,0,732-0011,34.2982,133.0858,50);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.69.0/24',1862415,1861060,null,0,0,731-5151,34.3831,132.5851,50);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.70.0/24',1862415,1861060,null,0,0,731-0111,34.4501,132.4884,10);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.71.0/24',1863018,1861060,null,0,0,738-0051,34.3830,132.5459,10);
insert into city_blocks (network, geoname_id,registered_country_geoname_id,represented_country_geoname_id,is_anonymous_proxy,is_satellite_provider,postal_code,latitude,longitude,accuracy_radius) values ('1.0.72.0/23',1862413,1861060,null,0,0,736-0014,34.3668,132.5529,50);

commit;

-- city_locations. should contain all the geoname_id's that city_blocks references
/*
	select distinct geoname_id from (
		select geoname_id from city_blocks union
		select registered_country_geoname_id from city_blocks union
		select represented_country_geoname_id from city_blocks 
	) src
where geoname_id is not null
*/
insert into city_locations (geoname_id,locale_code,continent_code,continent_name,country_iso_code,country_name,subdivision_1_iso_code,subdivision_1_name,subdivision_2_iso_code,subdivision_2_name,city_name,metro_code,time_zone,is_in_european_union) values (1814991,'en','AS','Asia','CN','China',null,null,null,null,null,null,'Asia/Shanghai',0);
insert into city_locations (geoname_id,locale_code,continent_code,continent_name,country_iso_code,country_name,subdivision_1_iso_code,subdivision_1_name,subdivision_2_iso_code,subdivision_2_name,city_name,metro_code,time_zone,is_in_european_union) values (1861060,'en','AS','Asia','JP','Japan',null,null,null,null,null,null,'Asia/Tokyo',0);
insert into city_locations (geoname_id,locale_code,continent_code,continent_name,country_iso_code,country_name,subdivision_1_iso_code,subdivision_1_name,subdivision_2_iso_code,subdivision_2_name,city_name,metro_code,time_zone,is_in_european_union) values (1862413,'en','AS','Asia','JP','Japan',34,'Hiroshima',null,null,null,null,'Asia/Tokyo',0);
insert into city_locations (geoname_id,locale_code,continent_code,continent_name,country_iso_code,country_name,subdivision_1_iso_code,subdivision_1_name,subdivision_2_iso_code,subdivision_2_name,city_name,metro_code,time_zone,is_in_european_union) values (1862415,'en','AS','Asia','JP','Japan',34,'Hiroshima',null,null,'Hiroshima',null,'Asia/Tokyo',0);
insert into city_locations (geoname_id,locale_code,continent_code,continent_name,country_iso_code,country_name,subdivision_1_iso_code,subdivision_1_name,subdivision_2_iso_code,subdivision_2_name,city_name,metro_code,time_zone,is_in_european_union) values (1863018,'en','AS','Asia','JP','Japan',34,'Hiroshima',null,null,'Hatsukaichi',null,'Asia/Tokyo',0);
insert into city_locations (geoname_id,locale_code,continent_code,continent_name,country_iso_code,country_name,subdivision_1_iso_code,subdivision_1_name,subdivision_2_iso_code,subdivision_2_name,city_name,metro_code,time_zone,is_in_european_union) values (2077456,'en','OC','Oceania','AU','Australia',null,null,null,null,null,null,'Australia/Sydney',0);
insert into city_locations (geoname_id,locale_code,continent_code,continent_name,country_iso_code,country_name,subdivision_1_iso_code,subdivision_1_name,subdivision_2_iso_code,subdivision_2_name,city_name,metro_code,time_zone,is_in_european_union) values (2078025,'en','OC','Oceania','AU','Australia','SA','South Australia',null,null,'Adelaide',null,'Australia/Adelaide',0);
insert into city_locations (geoname_id,locale_code,continent_code,continent_name,country_iso_code,country_name,subdivision_1_iso_code,subdivision_1_name,subdivision_2_iso_code,subdivision_2_name,city_name,metro_code,time_zone,is_in_european_union) values (6822110,'en','AS','Asia','JP','Japan',34,'Hiroshima',null,null,'Higashi-Hiroshima',null,'Asia/Tokyo',0);

commit;
