create table if not exists foss4g.divisions (
gid serial primary key,
code character varying (15),
geom geometry(MultiPolygon, 4326));

with fullarea as 
    (select 
        st_convexhull(st_buffer(st_union(geom), .005)) as geom 
     from 
         foss4g.bhmbuffer1000),

horizontalsplit as (
select 
    st_setsrid(
	st_makeline(
	    st_makepoint(st_xmax(geom), (st_ymax(geom) + st_ymin(geom)) / 2), 
	    st_makepoint(st_xmin(geom), (st_ymax(geom) + st_ymin(geom)) / 2)
	), 4326) as geom
from 
    fullarea),
	
verticalsplit as (
select 
    st_setsrid(
	st_makeline(
	    st_makepoint((st_xmax(geom) + st_xmin(geom)) / 2, st_ymax(geom)), 
	    st_makepoint((st_xmax(geom) + st_xmin(geom)) / 2, st_ymin(geom))
	), 4326) as geom
from 
    fullarea)

insert into foss4g.divisions (geom, code)	
select 
    st_multi(
        (st_dump(
            st_split(
                st_split(a.geom, b.geom), c.geom)
                )).geom
             ) as geom, 
    'bhmfoss4g_' || 
    (st_dump(
        st_split(
            st_split(a.geom, b.geom), c.geom)
            )).path[1] as code 
	from fullarea a, horizontalsplit b, verticalsplit c;