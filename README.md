# Using MaxMind's GeoIP/GeoLite2 database within Oracle RMDBS

MaxMind has a nice geo ip database which assigns known IP ranges with geocoordinates. Looking up geo-address information from IP addresses are more-and more essential in today's data-driven processes. MaxMind provides the data in various forms, and some tools that optimize the lookup process as well. However, I often find, that these methods are not fit for certain applications, where there are no integration methods available, and the processing is purely done in the database (think of datawarehouses or old-school fraud-monitoring software). I mostly work with Oracle, and I haven't found a ready-made solution for this, so I'll share mine with the general public.

## What will you find here
Essentially this repo only contains the DDL script, some snipetts for documentation, an this readme file where I try to explain the approach I'm using.

## Status

### Changelog

- **1.1.0** - New functions
- **1.0.1** - Bugfixes / typos
- **1.0.0** - Initial/original concept, only for retreiving geoname_id's of the respective location tables.

### Currently working on

- Function to return resultset

### Known issues

- This concept only handles IPv4 addresses, though it could be extended to IPv6 as well
- Reverse lookup is not implemented (eg.: find the ip ranges for a certain geolocation)

### TODO

- Document update / Article on Medium

## Usage

### Preparation

Just **run the `ddl.sql`** in your favourite Oracle database. It will create the:

- structures for storing country blocks and city blocks
- stored procedures to look up geoIP coordinate of `varchar2` type, either in the country or in the city blocks

The next step is **importing the data** from MaxMind's CSV files. Every table is designed according to the CSV files' structure, so you can use your preferred way of importing. More on that is here: 

- http://www.dba-oracle.com/tips_sqlldr_loader.htm
- https://docs.oracle.com/en/database/oracle/property-graph/22.4/spgdg/importing-data-csv-files.html

If you just want to fiddle, there's a small sample you can insert. Just **run the `sample.sql`** after you created the database.

### Functions

Upon invoking either function, they will return **a key, that can be looked up from their respective _locations table**:

- `getCountryGeoNameId()` returns the field to be looked up from `country_locations.geoname_id`
- `getCityGeoNameId()` returns the field to be looked up from `city_locations.geoname_id`

Use these functions, if you are interested in looking up the country/continent/city/etc detailed information.

If you want to **get access to the block record** in a stored procedure, you might want to use other functions:

- `getCountryBlock()` returns the one row of `country_blocks` that most matches the input ip address
- `getCityBlock()` returns the one row of `city_blocks` that most matches the input ip address

These will return the row itself, which can be further accessed in the inside of a stored procedure. Get the ids, access the data, make further lookups if you need extra information from the location tables. 

If you want to **get an id for retrieving the block record** (for example because you want to use it in a simple select) then there are convenience functions to do so:

- `getCountryBlockNetwork()` returns he `network` column of the found country block
- `getCityBlockNetwork()` returns the `network` column of the found city block

You can use the result to look up the whole record by id. Altough the structure doesn't define the `network` to be a primary key, but it is pretty much is.

#### Example for getCityGeoNameId():

``` SQL
select * 
from city_locations
where geoname_id = getCityGeoNameId('1.0.71.10');
```
returns this:

| GEONAME_ID | LOCALE_CODE | CONTINENT_CODE | CONTINENT_NAME | COUNTRY_ISO_CODE | COUNTRY_NAME | SUBDIVISION_1_ISO_CODE | SUBDIVISION_1_NAME | SUBDIVISION_2_ISO_CODE | SUBDIVISION_2_NAME | CITY_NAME | METRO_CODE | TIME_ZONE | IS_IN_EUROPEAN_UNION |
| - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| 2078025 | en | OC | Oceania | AU | Australia | SA | South Australia | - | - | Adelaide | - | Australia/Adelaide | 0 |

Please note, that MaxMind organizes it's data in a way that the city-level database also contains the country-level database, so for your lookups, you don't have to use both information.

Also note, that if you are cross-referencing the `geoname_id` from wrong table, you'll get bad results. This seem to be trivial, but I've seen many db programmers fall for this mistake.

#### Example for getCityBlock():

``` SQL
declare
  myrow city_blocks%ROWTYPE;
begin
  myrow := getCityBlock('1.0.71.10');

  dbms_output.put_line('Lat: ' || myrow.latitude || ' Long: ' ||  myrow.longitude);
end;
/
```
which putputs this:
```
Statement processed.
Lat: -34.9281 Long:138.5999
```

#### Example for getCityBlockNetwork()

``` SQL
select * 
from city_blocks 
where network = getCityBlockNetwork('1.0.71.10');
```
returns this:

| NETWORK | GEONAME_ID | REGISTERED_COUNTRY_GEONAME_ID | REPRESENTED_COUNTRY_GEONAME_ID | IS_ANONYMOUS_PROXY | IS_SATELLITE_PROVIDER | POSTAL_CODE | LATITUDE | LONGITUDE | ACCURACY_RADIUS | SIGNIFICANT_BITS | BITMASK | MASKED_NETWORK |
| - | - | - | - | - | - | - | - | - | - | - | - | - |
| 1.0.0.0/24 | 2078025 | 2077456 |   | 0 | 0 | 5000 | -34.9281 | 138.5999 | 1000 | 24 | 4294967040 | 16777216|

## Concepts of the solution

### Goals

- Should not use any data transformation scripts upoon loading the raw data from the files
- Rely on indexing as little as possible - just the bare essentials, because index regeneration could take up significant time
- Use an O(1) / O(log(n)) algorithm if it's possible

### The challenge

The database contains the geolocation of an **IP range** - and not individual IP addresses. You can find more on the range / subnet topic here: 
- https://en.wikipedia.org/wiki/Subnetwork
- https://www.interfacett.com/blogs/how-to-interpret-subnet-masks-in-network-environments/

The main thing is, if you examine the `country_blocks.network` field, you'll find data something like this: `192.168.5.64/26`, which is a text representation, so it must be transformed to be worked with.

There can be **more subnets that match your query** against a the database - and this is totally normal. You have your ISP's internal subnet, your ISP's global subnet, your country's subnet, regional, etc. The challenge is to **find the one that has the largest match** for the IP you are trying to geolocate. It's obvious, that matching text input against text in the database column (and essentially doing calculations in query time) won't result in an efficient solution, so we'll have to design a different approach.

### Solution design

#### Table structure

There's a lesser known (albeit an old) existing feature called **function-based virtual columns**. The main concept is that you can add a column, that is derived from the original (physical) columns through some expression(s), so the value can be calculated from the original data on-the-fly, or even stored upon creation/modification. If the calculation/expression is deterministic (meaning it will yield the same output for the same input), it can be used for other purposes as well - in our case to be **included in an index**.

Comparing characters, or character chains is less effective than **comparing numbers**. IPv4 addresses are essentially 32 bit unsigned integers, so comparing one or multiple integers to one input number yields a significant performance gain running on modern processors using a vector/matrix instruction set. An additional gain, is that storing numbers instead of `varchar2` **take up less space** both on the disk and in memory.

The aboved mentioned approaches combined, we'd generate virtual columns that extract and calculate:
- the significant bits
- the bitmask based on the significant bits
- the masked network number

All of them are based only on the string given in the `network` field.

#### IP to number conversion

The IP address comes in the usual format of `192.168.5.64`, and also, the IP range is like this: `192.168.5.64/26`. So to retrieve the numerical representation into the integer, we have to split/convert/shift/add the numbers. Thanks for regexp, this can be easily done like this*:

``` SQL
select 
  to_number(regexp_substr(ip, '\d+', 1, 1)) * 16777216 +
  to_number(regexp_substr(ip, '\d+', 1, 2)) * 65536 +
  to_number(regexp_substr(ip, '\d+', 1, 3)) * 256 +
  to_number(regexp_substr(ip, '\d+', 1, 4)) as numip
from dual
```
*considering the address comes in the variable `ip`

#### Query

Upon querying the input address, there's the problem of comparing the IP range to a number that is specifically masked for the defined range (the `/xx` part of the network field, or the `significant_bits` field we've just calculated) - this would mean, that for each record, we would have to generate the masked address of the input IP address, and compare it against the masked network number (found in the virtual column). Instead, we **generate all the possible masked variants of the input address** - there are 32 of them - and select those from the lookup table.

``` SQL
select 
  bitand(numip, bitand(4294967295 * power(2, rownum-1), 4294967295))
from dual
connect by rownum <= 32
```
Notice, that `numip` is the numerical representation of the IP address we try to look up

From this on, it is quite simple: just select all the records that match the masked_network field. Order descending the results based on the `significant_bits` virtual column, and selecting the first elemet yields our best match, which is the result we'd like to get.

#### Index design

This means, we'll have to generate only one index on the `masked_network` field, and we are good to go. Using this technique, instead of lengthy scans, we have 32 index-based direct id lookups, which the database can further parallelize during execution.

If you try this method, you'll get a nearly optimal solution on the latest Oracle releases. My experience is that if you try to use this approach with small dataset (partial import), it works fine, but for the whole dataset the db tries to outsmart you by doing full-table scans, since it needs to fetch the data for the `significant_bits` column, and Ora doesn't like that. The optimal approach is to **include the `significant_bits` field to the index**, and then it can be used for sorting.

## Contribution, discussion, etc

This project won't be maintained, it is just an example of how to solve seemingly complex problems in Oracle.

## License

As noted in the LICENSE.md file, this work is licensed under Creative Commons BY-NC 4.0 **If you found it useful, please leave a star.** Thanks.

For commercial usage, please conatact the author.
