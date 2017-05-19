create table if not exists foss4g.bhmfoss4g (
gid serial primary key,
code character varying(15),
geom geometry(MultiPolygon, 4326));

insert into foss4g.bhmfoss4g (code, geom)
select 
  b.code,
  st_multi(st_intersection(a.geom, b.geom)) as geom 
from 
    foss4g.bhmbuffer1000 a, foss4g.divisions b
where 
    st_intersects(a.geom, b.geom);

