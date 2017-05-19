select 
    st_npoints(geom) 
from 
    foss4g.bhmfoss4g 
order by 
    st_npoints(geom) desc;

select 
    st_npoints(st_subdivide(geom)) 
from 
    foss4g.bhmfoss4g 
order by 
    st_npoints(st_subdivide(geom)) desc;

select 
    st_isvalidreason(st_subdivide(geom)) 
from 
    foss4g.bhmfoss4g;

select 
    st_geometrytype(st_subdivide(geom)) 
from 
    foss4g.bhmfoss4g;

create table if not exists foss4g.subdivided (
gid serial primary key,
code character varying(15),
geom geometry(MultiPolygon, 4326));

insert into 
    foss4g.subdivided(code, geom)
select
    code, 
    st_multi(
        st_subdivide(geom)
    ) as geom 
from
    foss4g.bhmfoss4g;
        
    

