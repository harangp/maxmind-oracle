# Using MaxMind's GeoIP/GeoLite2 database within Oracle RMDBS

MaxMind has a nice geo ip database which assigns known IP ranges with geocoordinates. Looking up geo-address information from IP addresses are more-and more essential in today's data-driven processes. MaxMind provides the data in various forms, and some tools that optimize the lookup process as well. However, I often find, that these methods are not fit for certain applications, where there are no integration methods available, and the processing is purely done in the database (think of datawarehouses or old-school fraud-monitoring software). I mostly work with Oracle, and I haven't found a ready-made solution for this, so I'll share mine with the general public.

## What will you find here
Essentially this repo only contains the DDL script, some snipetts for documentation, an this readme file where I try to explain the approach I'm using.

## Status

### Changelog

Currently working on main: IPv6 lookups

- **1.2.0** - New functions: retrieve data by location
- **1.1.2** - Further optimalizations and bugfixes
- **1.1.1** - Bugfix in sorting for retrieving the correct id
- **1.1.0** - New functions
- **1.0.1** - Bugfixes / typos
- **1.0.0** - Initial/original concept, only for retreiving geoname_id's of the respective location tables.

### Known issues

- This concept only handles IPv4 addresses, though it could be extended to IPv6 as well

## Usage

### Preparation

Just **run the `ddl.sql`** in your favourite Oracle database. It will create the:

- structures for storing country blocks and city blocks
- stored procedures to look up geoIP coordinate of `varchar2` type, either in the country or in the city blocks

The next step is **importing the data** from MaxMind's CSV files. Every table is designed according to the CSV files' structure, so you can use your preferred way of importing. More on that is here: 

- http://www.dba-oracle.com/tips_sqlldr_loader.htm
- https://docs.oracle.com/en/database/oracle/property-graph/22.4/spgdg/importing-data-csv-files.html

If you just want to fiddle, there's a small sample you can insert. Just **run the `sample.sql`** after you created the database.

There's a slight chance, you don't have access sqlloader, and you want to use Oracle SQL Developer. Yu can use the import function, however, you'll find out, that it can not import data into already existing tables. Instead, import the files into tables starting with `IMP_*`, and then merge / move the data into the final table set. You will find scripts for that in the `merge.sql` file in this repo. This approach can be reused with enterprise solutions, where data has to be allways in place, and we don't have handy tools like we have in development environments, because of automation reasons. If you use an atomic update (as deleting everything from the *_blocks and *_location tables, update them with `insert into select`, and then do a `commit`, just make sure your rollback segment is large enough to handle the use-case.

### Functions

Upon invoking either of the *GeoNameId functions, they will return **a key, that can be looked up from their respective _locations table**:

- `getCountryGeoNameId()` returns the field to be looked up from `country_locations.geoname_id`
- `getCityGeoNameId()` returns the field to be looked up from `city_locations.geoname_id`
- `getCityGeoNameIdByLocation()` returns the field to be looked up from `city_locations` and `v_city_locations`

Use these functions, if you are interested in looking up the country/continent/city/etc detailed information.

If you want to **get access to the block record** in a stored procedure, you might want to use other functions:

- `getCountryBlock()` returns the one row of `country_blocks` that most matches the input ip address
- `getCityBlock()` returns the one row of `city_blocks` that most matches the input ip address

These will return the respective row itself, which can be further used in the inside of a stored procedure. Get the ids, access the data, make further lookups if you need extra information from the location tables. 

If you want to **get an id for retrieving the block record** (for example because you want to use it in a simple select) then there are convenience functions to do so:

- `getCountryBlockNetwork()` returns he `network` column of the found country block
- `getCityBlockNetwork()` returns the `network` column of the found city block

You can use the result to look up the whole record by id. Altough the structure doesn't define the `network` to be a primary key, but it is pretty much is.

#### View(s)

The solution only uses the (materialized) view `v_city_locations`, which collects information on the `city_locations` and `city_blocks` tables. This is needed as the `city_blocks` are large but redundant, synthetizing it's relevant information, and filtering for valid cities is a great help.


| Field | Type | Nullable | Description |
| - | - | - | - |
| **GEONAME_ID** | number | no | Id that can bell looked up from city_blocks and city_locations. Only contains ids where city name is a given. As the block table contains country and continent level information, it's important not to incclude those |
| **CITY_BLOCK_COUNT** | number | no | how many country block was used caclulating the lat/long values |
| **DISTINCT_COORDINATES_COUNT** | number | no | how many different coordinates belong to this geoname - if this number is 1, every location was the same for each block |
| **AVG_LAT**  | number | no | average of latitude coordinates coming from blocks |
| **AVG_LON**  | number | no | average of longitude coordinates coming from blocks |
| **STDDEV_LAT**  | number | no | Standard deviation for latitude coordinates. If 0, every latitude value was the same. |
| **STDDEV_LON** | number | no | Standard deviation for longitude coordinates. If 0, every longitude value was the same. |


#### Example for getCityGeoNameId():

``` SQL
select * 
from city_locations
where geoname_id = getCityGeoNameId('1.0.71.10');
```
returns this:

| GEONAME_ID | LOCALE_CODE | CONTINENT_CODE | CONTINENT_NAME | COUNTRY_ISO_CODE | COUNTRY_NAME | SUBDIVISION_1_ISO_CODE | SUBDIVISION_1_NAME | SUBDIVISION_2_ISO_CODE | SUBDIVISION_2_NAME | CITY_NAME | METRO_CODE | TIME_ZONE | IS_IN_EUROPEAN_UNION |
| - | - | - | - | - | - | - | - | - | - | - | - | - | - |
| 1863018 | en | AS | Asia | JP | Japan | 34 | Hiroshima | - | - | Hatsukaichi | - | Asia/Tokyo | 0 |

Please note, that MaxMind organizes it's data in a way that the city-level database also contains the country-level database, so for your lookups, you don't have to use both information.

Also note, that if you are cross-referencing the `geoname_id` from wrong table, you'll get bad results. This seem to be trivial, but I've seen many db programmers fall for this mistake.

#### Example for getCityGeoNameIdByLocations():

``` SQL
select getCityGeoNameIdByLocation(59.9454, 30.5558, 50) as geomane_id from dual;
```

returns this:

| GEONAME_ID |
| - |
| 546213 |

which looks up this from `v_city_location`:

| GEONAME_ID | CITY_BLOCK_COUNT | DISTINCT_COORDINATES_COUNT | AVG_LAT | AVG_LON | STDDEV_LAT | STDDEV_LON |
| - | - | - | - | - | - | - |
| 546213 | 1 | 1 | 59,9454| 30,5558 | 0 | 0 |

and this from `city_locations`:

| GEONAME_ID | LOCALE_CODE | CONTINENT_CODE | CONTINENT_NAME | COUNTRY_ISO_CODE | COUNTRY_NAME | SUBDIVISION_1_ISO_CODE | SUBDIVISION_1_NAME | SUBDIVISION_2_ISO_CODE | SUBDIVISION_2_NAME | CITY_NAME | METRO_CODE | TIME_ZONE | IS_IN_EUROPEAN_UNION |
| - | - | - | - | - | - | - | - | - | - | - | - | - | - |
|546213 | en | EU | Europe | RU | Russia | LEN | Leningradskaya Oblast' |  |  | Yanino Pervoye |  | Europe/Moscow | 0 |


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
which outputs this:
```
Statement processed.
Lat: 34.383 Long: 132.5459
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
| 1.0.71.0/24 | 1863018 | 1861060 | - | 0 | 0 | 687 | 34.383 | 132.5459 | 10 | 24 | 4294967040 | 16795392|

## Concepts of the geoIP retrieval solution

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

#### Query designs

There are multiple approaches we can take on retrieving the most suitable range.

##### Plain vanilla solution

The ip address is in the range, if we apply the bitmask to the ip address, and compare it to the masked_network value.

``` SQL
select
    src.*, city_blocks.*, masked_network + power(2, 32-significant_bits) - 1
from (
    select
      ip,
      to_number(regexp_substr(ip, '\d+', 1, 1)) * 16777216 +
      to_number(regexp_substr(ip, '\d+', 1, 2)) * 65536 +
      to_number(regexp_substr(ip, '\d+', 1, 3)) * 256 +
      to_number(regexp_substr(ip, '\d+', 1, 4)) as numip
    from dual
) src, city_blocks
where bitand(src.numip, bitmask) = masked_network
order by significant_bits desc;
```

If multiple ranges are found, the one with the most significant_bits should be selected.

The problem with this design is, that the database has to apply a bitwise AND operation to the ip address according to all of the bitmasks of all records. AND-ing lot's of numbers is fast, but we should strive for a better solution.

##### Using BETWEEN

As we have the ip ranges in a numeric form, we can easily do a select where the `numip` is between the lower and higher end of the range. With our table, it's quite simple:

``` SQL
select
    src.*, city_blocks.*, masked_network + power(2, 32-significant_bits) - 1
from (
    select
      ip,
      to_number(regexp_substr(ip, '\d+', 1, 1)) * 16777216 +
      to_number(regexp_substr(ip, '\d+', 1, 2)) * 65536 +
      to_number(regexp_substr(ip, '\d+', 1, 3)) * 256 +
      to_number(regexp_substr(ip, '\d+', 1, 4)) as numip
    from dual
) src, city_blocks
where src.numip between masked_network and masked_network + power(2, 32-significant_bits)
order by significant_bits desc;
```
Lower bound of the range is essentially the `masked_network` value, and higher bound is calculated by adding the maximum value (which is `32 - significant_bits`) to the host bits. If multiple ranges are found, the one with the most significant_bits should be selected.

This method seems computationally heavier, than the previous one. However, with this approach opens up a possibility: put the calculated higher bound into a virtual column and index it together with `masked_network`.

Note, that simply creating an index, which contains this calculated value is not optimal, as calculated indexes can't include virtual columnt's values - which is a bummer.

##### Generating masked IPs and directly select them - the "sounds good, doesn't work" approach

Upon querying the input address, there's the problem of comparing the IP range to a number that is specifically masked for the defined range (the `/xx` part of the network field, or the `significant_bits` field we've just calculated) - this would mean, that for each record, we would have to generate the masked address of the input IP address, and compare it against the masked network number (found in the virtual column). Instead, we **generate all the possible masked variants of the input address** - there are 32 of them - and select those from the lookup table.

The presumed performance gain comes from the fact that it's faster to find exact matches in an index than ranges. Let's try it! But first, check how easily we can generate the masked adresses of a particular ip address:

``` SQL
select
  bitand(numip, power(2, 32) - 1  - (power(2, rownum - 1) - 1)) as masked_numip,
  33 - rownum as generated_network_bits
from dual
connect by rownum <= 32
```
Notice, that `numip` is the numerical representation of the IP address we try to look up.

The first intuition is that this is an elegant solution, as we can pass it to a `WHERE masked_network IN ()` clause matching the `masked_network` field. Order descending the results based on the `masked_network` and `significant_bits` virtual columns, and selecting the first elemet yields our best match, which is the result we'd like to get.

**However, this doesn't work.** The problem is that with this, we might have cases where a range is missing, and a lower order generated masked value might match a higher tier range. Here's an example:

```
Range: 128.0.0.0/32 -> this means, that we only look for this specific ip address
IP: 128.0.0.1
Calculated masked ip-s:
- 128.0.0.1, significant bits:32
- 128.0.0.0, significant bits: 31..1

128.0.0.1 with significant bits 31 to 1 will match with 128.0.0.0 and result a faulty answer.
```

##### Using inner table JOIN

Let's address the problem with the previous solution. We have to create a table where the masked versions of the ip address are generated alongside with the information of how long of a mask was applied. Joining this inner table with the large one is nearly trivial:

``` SQL
select
    src.*, country_blocks.*
from (
    -- this select creates a masked list of ip addresses
    select
        :ip,
        -- this just generates the numerical representation of the ip address
        to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
        to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
        to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
        to_number(regexp_substr(:ip, '\d+', 1, 4)) numip,
        bitand(
            -- we have to recreate it, because sql doesn't allow to reuse values we've already
            --  calculated, and also doesn't have a native function like MySQL does
            -- you might want to outsource this into a function
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
order by generated_network_bits desc, significant_bits desc;
```

Please note the `significant_bits <= generated_network_bits` clause, which takes care of matching ranges with different significant bits. Also, `generated_network_bits` should be used for sorting first, as we are interested in the largest matching.

This solution seems a bit overengineered, and it is. However there are some positives:

- as significant bits can be stored as NUMBER(2) values, space and memory can be saved
- index building will be faster, as no complicated math is involved with the generation
- index will be smaler as well, because of the reduced range

This approach enables a 50 msec retrieval time on a free Oracle Cloud 23i instance, from wifi, so it's not really scientific. On-prem (or closely coupled) solutions should respond faster.

#### Index design

This means, we'll have to generate only one index on the `masked_network` field, and we are good to go. Using this technique, instead of lengthy scans, we have 32 index-based direct id lookups, which the database can further parallelize during execution.

If you try this method, you'll get a nearly optimal solution on the latest Oracle releases. My experience is that if you try to use this approach with small dataset (partial import), it works fine, but for the whole dataset the db tries to outsmart you by doing full-table scans, since it needs to fetch the data for the `significant_bits` column, and Ora doesn't like that. The optimal approach is to **include the `significant_bits` field to the index**, and then it can be used for sorting.

## Concepts of city retrieval based on lat/long coordinates

### Goals

There are numerious city location databases circulating around on the internet. However, getting a reliable and updated source is a nuisance, if we already have something simmilar imported into our database. The goal of this use-case is to input a geocoordinate and a range, and receive the best matching city reference information from MaxMind's GeoCity Light dataset.

- Get it as fast as possible
- Approcimate results are acceptable

The (current) main goal is to use this algorithm in a fraud-monitoring solution, where approximations are natural, and even the "we can't find a close-by city for this ip address" has an important meaning.

### The challenge

The GeoLite City database holds the geolocation coordinates in the "blocks" file, which contains the network ranges. This file is large (the 2020 file contains 3.2 million records), and if we want an exact solution, we have to match each and every record's location to the input, calculate the distance with the Heaversine formula, and choose the closest location. This is obviously a demanding task on millinos of records, so we need some smart decisions and heavy optimalizations to find a faster way. 

### Solution design

#### Algorithm design

The first idea is to **restrict the number of rows** to perform the difficult calculations based on a crude filter. We draw a boundary "box", which presumably includes the coordinates. But this means, if we are not "close enough" to one point, we might be on a place where we can't find any relevant solution. We can check this, if we prepare a map, which groups the block records for their truncated lat/long values. 

![image](https://github.com/user-attachments/assets/830dd9bc-e10d-4bd6-8269-299ddccfbed7)

As it seems, we'd be missing most of the Sahara desert, the Amazonas, the Himalayas, the Gobi desert, most of the *stan countries, Siberia, and the northen part of Canada. But that's not a problem, as these parts of the globe are unhabited, so no problem if we can't identify the nearest city.

Let's continue how can we **calculate the boundary**. The GeoLite database defines the coordinates as latitude and longitude in degrees, as we usually used to: -90 to 90 degrees for latitude, and -180 to 180 degrees for longitude. The easiest way to calculate a boundary, is to add / substract certain degrees to the coordinates of the point we want to identify, and search withing this boundary with `where` clauses. If we want to have a bounding box which includes a circle with radius `r`, we can calculate:
- latitude as `[lat - r/222, lat + r/222]`, as 1 degree of latitude is 111 km,
- longitude as `[lon - r/222/cos(lat), lon + r/222/cos(lat)]`
So on the equator, we have a square, but the further we go to the poles, the area takes up a shape of a rectangle lying on it's longer side.

We should **examine the location distribution**, as I'd figure that structure in the data will come handy in index design. There shouldn't be a big surprise, as the number of recors should follow the geography of the continents:
![image](https://github.com/user-attachments/assets/a6438ea3-d87d-4ba0-ba3d-a31fff44d20a)
So most of the points are in the northern hemisphere.
![image](https://github.com/user-attachments/assets/5615b3de-5abc-4ad3-b4a8-ccb1a5de0902)
And we can see clear distinction of he Americas, Eurpoe + Africa, India, and east Asia.
It's important to note, that longitudal coordinates despite the clumps of the contintens are more evenly spred out, so this information should be taken into consideration when designing indexes.

I've mentioned, that **calculating the distance** between two points on a sphere is not trivial. However, if we stick to our restriction of only searching within a relatively small cirlce (let's say: 200 km), we can use the **Equirectangular approximation**, which gives a pretty decent result, and saves us from trigonometry-heavy calculations:

`6371 * sqrt(power((latitude - :lat) * 3.1415 / 180, 2) + power(cos((latitude + :lat) / 2 * 3.1415 / 180)*(longitude - :lon) * 3.1415 / 180, 2)) `

where:
- 6371 is the Earth's radius
- we are calculating the difference of latitudes in degrees and converting them to radians
- we are calculating the difference of longitude in degrees and converting them to radians
- longitude difference is adjusted by the cosine of the middle point of the latitudes 

During some initial testing, I noticed, that many of the blocks pointed to the same geolocation_id values. This piqued my interest, so I checked the cardinality of the data:
- 120.563 records in city_locations
- 117.397 distinct geoname_id found in the city_blocks table
- 146.971 different lat/long pairs in the city_blocks table

This means for me, that if we are only interested in the cities anywas, **we are better to enrich the city_locations table with location information**, as it would make the queried dataset smaller by a magnitude. Only one check remains: we need to be sure, we don't make a big mistake by averaging out the location coordinates. This can be done pretty simply with SQL:

```SQL
select 
    cl.geoname_id,
    count(*) city_block_count,
    count(distinct '' || latitude || longitude) distinct_coordinates_count,
    avg(cb.latitude) avg_lat, 
    avg(cb.longitude) avg_lon, 
    stddev(cb.latitude) stddev_lat,
    stddev(cb.longitude) stddev_lon
from city_blocks cb, city_locations cl
where cl.geoname_id = cb.geoname_id and cl.city_name is not null
group by cl.geoname_id
having stddev(cb.latitude) + stddev(cb.longitude) > 0
order by stddev(cb.latitude) + stddev(cb.longitude) desc;
```

Most of the geolocation_ids have only one range, so most of the time the standard deviation is zero, so it's trivial. Examining the more complex cases, it turns out only 10-20-is locations are problematic, but otherwise, the standard deviation is pretty low. Interestingly, one of the errorneous record was in Hungary: one of the block record pointed to Tokaj (small city at the center of a famous wine region), and the other is at Nagykálló, 42 km away from each other. I consider these irregularities which can be easily corrected in MaxMind's future releases (might be already done so).

The last remaing though is using **location / spatial queries** which are Oracle-specific things - in a later phase, I'd like to try them. But not now.

#### Table structure

It is tempting to enhance the `city_locations` table with virtual columns, as we did with the `city_blocks`. Unfortunately, this won't work, as it can't contain data from other tables. Views are for that. But there's a catch: views can't be indexed, and that would be a hindrance on our goal of writing super efficient selects. However. There's a thing in Oracle called **materialized views**, which are essentially tables (SQL developer even refuses to show them under the "Views" tab), which can be either manually or automatically updated, and can have indexes on it's columns:

```SQL
create MATERIALIZED view V_CITY_LOCATIONS
BUILD IMMEDIATE 
REFRESH COMPLETE
AS
select 
    cl.geoname_id,
    count(*) city_block_count,
    count(distinct '' || latitude || longitude) distinct_coordinates_count,
    avg(cb.latitude) avg_lat, 
    avg(cb.longitude) avg_lon, 
    stddev(cb.latitude) stddev_lat, 
    stddev(cb.longitude) stddev_lon
from city_blocks cb, city_locations cl
where cl.geoname_id = cb.geoname_id and cl.city_name is not null
group by cl.geoname_id;
```

Essentially, this view will prepare the location data and metrics in a consumable format.

#### Query designs

Let's put all these things together, and create a query, which incorporates the materialized view, the adjusted range, and distance calculationss:

```SQL
select 
    avg_lat,
    avg_lon,
    stddev_lat + stddev_lon as accuracy,
    6371 * sqrt(
      power((avg_lat - :lat) * 3.1415 / 180, 2) +
      power(cos((avg_lat + :lat) / 2 * 3.1415 / 180) * (avg_lon - :lon) * 3.1415 / 180, 2)
    ) as distance,
    city_locations.*
from v_city_locations, city_locations
where 1 = 1
    and avg_lat > :lat - :range / 222
    and avg_lat < :lat + :range / 222
    and avg_lon > :lon - :range / 222 / cos(:lat * 3.1415 / 180)
    and avg_lon < :lon + :range / 222 / cos(:lat * 3.1415 / 180)
    and v_city_locations.geoname_id = city_locations.geoname_id    
order by
    distance asc
;
```

It's a simple, basic join, nothing fancy, but effective. If we want to reduce the calculation burdern, we can ommit the `6371 * sqrt(...)` part, as it is just scaling the distance. For sorting purposes, the omission of this part is totally fine.

#### Index design

If you look at the map, green squares usually have 10-ish locations, yellow have 1000-10000-is records, orange ones have above 10.000 records (check California, and the middle of the US). These are too much, so my dream of using super-fast bitmap indexes on the truncated values of the lat/long coordinates went up in flames. One thing is that the filter would be less selective, the problem would be that the values could not be used directly from the index, and Ora needs to fetch the records. Unfortunately, Oracle tends to do a full table scan in these cases, which is not good.

Instead, I went with the good old **simple index solution (b-tree)**, which can incorporate the latitude and longitude values, and can be reused for filtering. One important thing is to choose the order of latitude and longitude in the index. As I've shown before, longitude coordinates are more spread-out along the axis, so they are more "selective" which makes the search's cardinality lower.

`create index idx_v_city_locations_lat_long_geoname on v_city_locations (avg_lon, avg_lat, geoname_id) compress 1 compute statistics;`

Note, that geoname_id is added to the index as well. slightly increases the size of the index, but we don't need to fetch from the table if we'd want to do joins further down the line.

This index can be super fast on tables with 100.000-ish records. Also, note, that this is only possible because we are using materialized view.

## Contribution, discussion, etc

This project won't be maintained, it is just an example of how to solve seemingly complex problems in Oracle.

## License

As noted in the LICENSE.md file, this work is licensed under Creative Commons BY-NC 4.0 **If you found it useful, please leave a star.** Thanks.

For commercial usage, please conatact the author.
