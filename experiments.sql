---
--- This file holds the experiments you can run on the tables defined in ddl.sql
--- Main discussion points about the algorithms in the comments
--- 

--- declarations for IP adresses. if you run the sql-s in sql developer, you'll e prompted for a value, and that's fine.
var ip varchar2(15)
exec :ip := '195.228.33.5'

--- plain-vanilla solution, where we have to calculate the masekd ip for each network according to the network's significant bit setting 
--- runtime: 41 sec / query
--- full table scan is performed, as expected.
select
    src.*, country_blocks.*
from (
    select
        :ip,
        to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
        to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
        to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
        to_number(regexp_substr(:ip, '\d+', 1, 4)) numip
    from dual
) src, country_blocks
where bitand(src.numip, bitmask) = masked_network
order by significant_bits desc;

-- using ip ranges to utilize inexes. upper bound is calculated on-the fly, but at lease ora might take advantage that not all the masked_networks
-- have to be taken into consideration.
-- runtime: 41 sec / query
-- that didn't help much. this was an unexpected result
select
    src.*, country_blocks.*
from (
    select
        :ip,
        to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
        to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
        to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
        to_number(regexp_substr(:ip, '\d+', 1, 4)) numip
    from dual
) src, country_blocks
where src.numip between masked_network and masked_network + power(2, 32-significant_bits)
order by significant_bits desc;

-- masked network field holds the lower bound (inclusive) of the ip range
-- upper_bound field holds the last good ip address (inclusive) of the ip range
-- index is used for both lower and upper bound, which is more effective
-- runtime: 31 sec
-- I'd expected more performance gain from this approach, though 25% doesn't seem bad.
-- Still, this response time is unacceptable.
select
    src.*, country_blocks.*
from (
    select
        :ip,
        to_number(regexp_substr(:ip, '\d+', 1, 1)) * 16777216 +
        to_number(regexp_substr(:ip, '\d+', 1, 2)) * 65536 +
        to_number(regexp_substr(:ip, '\d+', 1, 3)) * 256 +
        to_number(regexp_substr(:ip, '\d+', 1, 4)) numip
    from dual
) src, country_blocks
where src.numip >= masked_network and src.numip <= upper_bound
order by significant_bits desc;

-- Calculating masks. The trick is that rownum goes from 1 to 32, which needs to be taken into consideration
select
    32 - rownum + 1 as network_bits,
    rownum - 1 as host_bits,
    power(2, 32) - 1  - (power(2, rownum - 1) - 1) as network_mask,
    power(2, rownum - 1) - 1 as host_bits_mask
from dual
connect by rownum <= 32;
