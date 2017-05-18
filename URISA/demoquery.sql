/*****************************************************************************************
Open Source GIS Presentation Postgis Demo Queries and notes
Matt Brown and Ryan Creel
8/24/2016
****************************************************************************************/

--https://www.postgresql.org/download/windows/ - download and install - check spatial extensions
--Add Server in pgAdmin
--update pga.cong, posgresql.conf, and create new rules for windows firewall to allow 5432.

--create a new database - lower case if you want to use ArcMap!
--right click top of tree in pgAdmin or create in psql

--spatially enable database
--this allows you to use spatial functions and types

CREATE EXTENSION POSTGIS;

--check to see if postgis is installed

select * from spatial_ref_sys where srid = 4326; --WGS84 spatial reference

--create a schema to hold data - lower case

CREATE schema urisa_workshop;

--will come back to this later

--import some data in qgis - could also use gdal or pgsql2shp

Select * from urisa_workshop.mtbrk_streets_wgs84 limit 100;


--Common Alabama Coordinate Systems
--esri srid 102630
--NAD 83 state plane alabama west US Foot
--esri srid 102629
--NAD 83 state plane alabama east US Foot 
--EPSG:26916
--UTM NAD83 16N meters
--EPSG:4326
--WGS84 Lat/Lon
--EPSG:3857 900913
--Web Mercator aka google

select * from spatial_ref_sys where srid = 102630; 

--not an EPSG coordinate system - has to be added manually

--http://spatialreference.org/ref/esri/102630/postgis/
--not going to work as-is - ERROR:  new row for relation "spatial_ref_sys" violates check constraint "spatial_ref_sys_srid_check"
--INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) values ( 9102630, 'esri', 102630, '+proj=tmerc +lat_0=30 +lon_0=-87.5 +k=0.9999333333333333 +x_0=600000.0000000001 +y_0=0 +ellps=GRS80 +datum=NAD83 +to_meter=0.3048006096012192 +no_defs ', 'PROJCS["NAD_1983_StatePlane_Alabama_West_FIPS_0102_Feet",GEOGCS["GCS_North_American_1983",DATUM["North_American_Datum_1983",SPHEROID["GRS_1980",6378137,298.257222101]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["Transverse_Mercator"],PARAMETER["False_Easting",1968500],PARAMETER["False_Northing",0],PARAMETER["Central_Meridian",-87.5],PARAMETER["Scale_Factor",0.9999333333333333],PARAMETER["Latitude_Of_Origin",30],UNIT["Foot_US",0.30480060960121924],AUTHORITY["EPSG","102630"]]');

--You must remove the leading 9 in the srid so that 9102630 becomes 102630

INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext) 
    values ( 102630, 'esri', 102630, '+proj=tmerc +lat_0=30 +lon_0=-87.5 +k=0.9999333333333333 +x_0=600000.0000000001 +y_0=0 +ellps=GRS80 +datum=NAD83 +to_meter=0.3048006096012192 +no_defs ', 'PROJCS["NAD_1983_StatePlane_Alabama_West_FIPS_0102_Feet",GEOGCS["GCS_North_American_1983",DATUM["North_American_Datum_1983",SPHEROID["GRS_1980",6378137,298.257222101]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]],PROJECTION["Transverse_Mercator"],PARAMETER["False_Easting",1968500],PARAMETER["False_Northing",0],PARAMETER["Central_Meridian",-87.5],PARAMETER["Scale_Factor",0.9999333333333333],PARAMETER["Latitude_Of_Origin",30],UNIT["Foot_US",0.30480060960121924],AUTHORITY["EPSG","102630"]]');

--change to workshop schema
--create a table to hold reprojected data and fewer fields

/*Starting here we will create a service area by buffering roads, parcel centroids, and lines between the parcel centroids and their nearest corresponding road by 200' */

create table workshop.mtbrk_streets_sp (
    gid serial primary key, 
    cfcc character varying(3), 
    name character varying(100),
    type character varying(16),
    geom geometry(MultiLineString, 102630));

--insert data into table reprojecting geometry

INSERT into workshop.mtbrk_streets_sp (cfcc, name, type, geom)
    SELECT cfcc, name, type, st_transform(geom, 102630) as geom 
    FROM workshop.mtbrk_streets_wgs84;

--extract centroids from parcels
--check fields to verify field renaming

--select * from workshop.mtbrk_parcels_wgs84 limit 5;

--create table and insert data

create table workshop.mtbrk_centroids (
    gid serial primary key,
    name character varying(100),
    type character varying(16),
    geom geometry(Point, 102630));


INSERT INTO workshop.mtbrk_centroids (name, type, geom)
    SELECT add_stre_1 as name, add_suffix as type, st_transform(st_centroid(geom), 102630) as geom 
    FROM workshop.mtbrk_parcels_wgs84; 

--find closest point on lines to centroids 

/*
WITH dissolved as (  
    SELECT name, type, st_linemerge(st_union(geom)) as geom 
    FROM  workshop.mtbrk_streets_sp 
    GROUP BY NAME, type)
	
SELECT st_closestpoint(b.geom, a.geom) from workshop.mtbrk_centroids a, dissolved b
    WHERE a.name = b.name and 
	a.type = b.type and 
	st_distance(a.geom, b.geom) > 200;  
*/

--create table to hold data to buffer - geometry column - multi types in one table

CREATE TABLE workshop.fake_gas_data (
    gid serial primary key,
    geom geometry(Geometry, 102630));

--insert roads

INSERT INTO workshop.fake_gas_data (geom)
    select geom from workshop.mtbrk_streets_sp;

--insert meters

INSERT INTO workshop.fake_gas_data (geom)
    SELECT geom from workshop.mtbrk_centroids;

--clean up some messy predirectional data and non-matching roads

update workshop.mtbrk_centroids set name = 'EAST BRIARCLIFF' where gid in (
    select a.gid from workshop.mtbrk_centroids a,  workshop.mtbrk_parcels_wgs84 b 
    where st_within(st_transform(a.geom, 4326), b.geom) and 
	b.add_stre_1 = 'BRIARCLIFF' and
	b.add_pre_di  = 'E');

update workshop.mtbrk_centroids set name = 'EAST BRIARCLIFF' where gid in (
    select a.gid from workshop.mtbrk_centroids a, workshop.mtbrk_parcels_wgs84 b 
    where st_within(st_transform(a.geom, 4326), b.geom) and 
	b.add_stre_1 = 'BRIARCLIFF' and
	b.add_pre_di  = 'E');

update workshop.mtbrk_streets_sp set name = 'PUMP HOUSE' where  name = 'PUMP HOUSE CAHABA';

--create line from centroid to closest point on road- insert into fake gas line table

WITH dissolved as ( 
    SELECT name, type, st_linemerge(st_union(geom)) as geom 
    FROM  workshop.mtbrk_streets_sp 
    GROUP BY NAME, type)
	

INSERT INTO workshop.fake_gas_data (geom) 
    SELECT st_makeline(a.geom, st_closestpoint(b.geom, a.geom)) 
    FROM workshop.mtbrk_centroids a, dissolved b
    WHERE a.name = b.name and 
    a.type = b.type and 
    st_distance(a.geom, b.geom) between 200 and 2000;


--buffer streets and lines by 200' - around 50 seconds 

CREATE TABLE workshop.fake_sa (
    gid serial primary key,
    geom geometry(MultiPolygon, 102630));

Insert into workshop.fake_sa (geom) 
    SELECT st_multi((st_dump(st_union(st_buffer(geom, 200)))).geom) as geom
    FROM workshop.fake_gas_data;

--subdivide service area for performance

CREATE TABLE workshop.fake_sa_split (
    gid serial primary key,
    code character varying (10),
    geom geometry(MultiPolygon, 102630));

INSERT INTO workshop.fake_sa_split (code, geom)
    SELECT 'MTBRK01' as code, 
    st_multi(st_collectionextract(st_makevalid(st_subdivide(geom)), 3)) as geom
    FROM workshop.fake_sa;

--clean up intermediate tables

DROP TABLE workshop.fake_sa;
DROP TABLE workshop.fake_gas_data;
DROP TABLE workshop.mtbrk_streets_sp;
DROP TABLE workshop.mtbrk_centroids;
