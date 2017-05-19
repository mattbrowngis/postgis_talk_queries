--use lat/lon toolbar to collect point in WKT format
--replace points with copied WKT
select foss4g.st_splitstreet(
    (select 
        gid 
    from 
        foss4g.streets 
    where 
        st_dwithin(
        geom, st_geomfromewkt('SRID=4326;POINT(-86.8102497945 33.4758455892)'), .00005) limit 1
     ), 
        st_geomfromewkt('SRID=4326;POINT(-86.8102497945 33.4758455892)'))