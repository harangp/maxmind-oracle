# Using MaxMind's GeoIP/GeoLite2 database within Oracle RMDBS

MaxMind has a nice geo ip database which assigns known IP ranges with geocoordinates. Looking up geo-address information from IP addresses are more-and more essential in today's data-driven processes. MaxMind provides the data in various forms, and some tools that optimize the lookup process as well. However, I often find, that these methods are not fit for certain applications, where there are no integration methods available, and the processing is purely done in the database (think of datawarehouses or old-school fraud-monitoring software). I mostly work with Oracle, and I haven't found a ready-made solution for this, so I'll share mine with the general public.

## What will you find here
Essentially this repo only contains the DDL script, some snipetts for documentation, an this readme file where I try to explain the approach I'm using.

## Status

### Changelog

- **0.0.1** - Initial commit, just the frame of things

### Currently working on

- Documentation

### Known issues

- This concept only handles IPv4 addresses, though it could be extended to IPv6 as well
- Reverse lookup is not implemented (eg.: find the ip ranges for a certain geolocation)

### TODO

- upload city DDL

## Usage

Just **run the `ddl.sql`** in your favourite Oracle database. It will create the:

- structures for storing country blocks and city blocks
- stored procedures to look up geoIP coordinate of `varchar2` type, either in the country or in the city blocks

The next step is **importing the data** from MaxMind's CSV files. Every table is designed according to the CSV files' structure, so you can use your preferred way of importing. More on that is here: 

- http://www.dba-oracle.com/tips_sqlldr_loader.htm
- https://docs.oracle.com/en/database/oracle/property-graph/22.4/spgdg/importing-data-csv-files.html

Upon invoking either stored procedures, they will return **a key, that can be looked up from their respective _locations table**:

- `getCountryGeoNameId()` returns the field to be looked up from `country_locations.geoname_id`
- `getCityGeoNameId()` returns the field to be looked up from `city_locations.geoname_id`

Please note, that MaxMind organizes it's data in a way that the city-level database also contains the country-level database, so for your lookups, you don't have to use both information.

Also note, that if you are cross-referencing the `geoname_id` from wrong table, you'll get bad results. This seem to be trivial, but I've seen many db programmers fall for this mistake.

## Concepts of the solution

### Goals

- Should not use any data transformation scripts upoon loading the raw data from the files
- Rely on indexing as little as possible - just the bare essentials, because index regeneration could take up significant time
- Use an O(1) / O(log(n)) algorithm if it's possible

### The challenge

The database contains the geolocation of an **IP range** - and not individual IP addresses. You can find more on the range / subnet topic here: https://en.wikipedia.org/wiki/Subnetwork The main thing is, if you examine the country_blocks.network field, you'll find data something like this: `192.168.5.64/26`

There can be **more subnets that match your query** against a the database - and this is totally normal. You have your ISP's internal subnet, your ISP's global subnet, your country's subnet, regional, etc. The challenge is to **find the one that has the largest match** for the IP you are trying to geolocate. It's obvious, that matching text input against text in the database column (and essentially doing calculations in query time) won't result in an efficient solution, so we'll have to design a different approach.

### Solution design

There's a lesser known (albeit an old) existing feature called **function-based virtual columns**. The main concept is that you can add a column, that is derived from the original (physical) columns through some expression(s), so the value can be calculated from the original data on-the-fly, or even stored upon creation/modification. If the calculation/expression is deterministic (meaning it will yield the same output for the same input), it can be used for other purposes as well - in our case to be **included in an index**.

Comparing characters, or character chains is less effective than **comparing numbers**. IPv4 addresses are essentially 32 bit unsigned integers, so comparing one or multiple integers to one input number yields a significant performance gain running on modern processors using a vector/matrix instruction set. An additional gain, is that storing numbers instead of `varchar2` **take up less space** both on the disk and in memory.

The aboved mentioned approaches combined, we'd generate virtual columns that extract and calculate:
- the significant bits
- the bitmask based on the significant bits
- the masked network number
based only on the string given in the `network` field.

Upon querying the input address, there's the problem of comparing the IP range to a number that is specifically masked for the defined range (the `/xx` part of the network field, or the `significant_bits` field we've just calculated) - this would mean, that for each record, we would have to generate the masked address of the input IP address, and compare it against the masked network number (found in the virtual column). Instead, we **generate all the possible masked variants of the input address** - there are 32 of them - and select those from the lookup table. Ordering descending the results based on the `significant_bits` virtual column, and selecting the first elemet yields our best match.

This means, we'll have to generate only one index on the `masked_network` field, and we are good to go. Using this technique, instead of lengthy scans, we have 32 index-based direct id lookups, which the database can further parallelize during execution.

If you try this method, you'll get a nearly optimal solution on the latest Oracle releases. My experience is that if you try to use this approach with small dataset (partial import), it works fine, but for the whole dataset the db tries to outsmart you by doing full-table scans, since it needs to fetch the data for the `significant_bits` column, and Ora doesn't like that. The optimal approach is to **include the `significant_bits` field to the index**, and then it can be used for sorting.

## Contribution, discussion, etc

This project won't be maintained, it is just an example of how to solve seemingly complex problems in Oracle.

## License

As noted in the LICENSE.md file, this work is licensed under Creative Commons BY-NC 4.0

For commercial usage, please conatact the author.
