CREATE OR REPLACE FUNCTION foss4g.st_splitstreet(streetgid integer, splitpoint geometry) RETURNS text AS
$$
DECLARE
    result text := '';
    street record;
    lf integer; --left from address
    lt integer; --left to address
    rf integer; --right from address
    rt integer; --right to address
    new_lt integer;
    new_rt integer;
    new_lf integer;
    new_rf integer;
    interpolate float;
    geom1 geometry;
    geom2 geometry;
BEGIN
    IF st_geometrytype(splitpoint) = 'ST_Point' THEN--make sure the geometry is a point
      --get the values for the street with the requested gid - point should not be within a distance of the end of the line from call - check for completeness in case called outside of the new streets workflow?
       select * into street from foss4g.streets where gid = streetgid;
       splitpoint := st_closestpoint(street.geom, st_setsrid(splitpoint, 4326)); --convert the splitpoint to the closest point on the line
       geom1 := st_multi(st_geometryn(st_split(st_snap(street.geom, splitpoint, .000001), splitpoint), 1)); --first portion of split geometry
       geom2 := st_multi(st_geometryn(st_split(st_snap(street.geom, splitpoint, .000001), splitpoint), 2)); --second portion of split geometry
       lf := street.l_f_add::numeric::integer;
       lt := street.l_t_add::numeric::integer;
       rf := street.r_f_add::numeric::integer;
       rt := street.r_t_add::numeric::integer;
       --STANDARD DIRECTION (Ranges increase with the direction of the street
       if (lf < lt and rf < rt) or (lt < lf and rt < rf) or (lf = 0 or lt = 0 or rf = 0 or rt = 0) or lt = lf or rt = rf then --ranges are consistent or zero values and have matching address parity
          interpolate := st_linelocatepoint(st_linemerge(street.geom), splitpoint); -- find the percentage along the line where the point falls
          --Left side calculation
          If lf < lt or rf < rt then
          IF lf = 0 or lt = 0 THEN --If any left values are zero, set all left values to zero
             lf := 0;
             lt := 0;
             new_lf := 0;
             new_lt := 0;
          ELSEIF lf = lt THEN
             new_lf := lf;
             new_lt := lt;
          ELSE  
             new_lt := lf + floor((lt-lf) * interpolate);
             if mod(floor((lt-lf) * interpolate)::integer, 2) = 1 then
            new_lt := new_lt -1;
             end if;
             new_lf = new_lt + 2;
          END IF;
          --Right side calculation
          IF rf = 0 or rt = 0 THEN --If any right side values are zero, set all right side values to zero
             rf := 0;
             rt := 0;
             new_rf := 0;
             new_rt := 0;
          ELSEIF rf = rt THEN
             new_rf := rf;
             new_rt := rt;
          ELSE
             new_rt := rf + floor((rt-rf) * interpolate);
             if mod(floor((rt-rf) * interpolate)::integer, 2) = 1 then
            new_rt := new_rt - 1;
             end if;
             new_rf = new_rt + 2;
          END IF;                            
          result := 'OK STANDARD DIRECTION ' || street.streetname || ' left first:' || lf || '-' || new_lt || ' left second: ' || new_lf || '-' || lt || ' right first: ' || rf || '-' || new_rt || ' right second: ' || new_rf || '-' || rt || ' ' || interpolate::text;
    
       --REVERSE DIRECTION
          ELSE

          IF lf = 0 or lt = 0 THEN --If any left values are zero, set all left values to zero
             lf := 0;
             lt := 0;
             new_lf := 0;
             new_lt := 0;
          ELSE  
             new_lt := lf - ceiling((lf-lt) * interpolate);
             if mod(ceiling((lf-lt) * interpolate)::integer, 2) = 1 then
            new_lt := new_lt + 1;
             end if;
             new_lf = new_lt - 2;
          END IF;
          --Right side calculation
          IF rf = 0 or rt = 0 THEN --If any right side values are zero, set all right side values to zero
             rf := 0;
             rt := 0;
             new_rf := 0;
             new_rt := 0;
          ELSE
             new_rt := rf - ceiling((rf-rt) * interpolate);
             if mod(ceiling((rf-rt) * interpolate)::integer, 2) = 1 then
            new_rt := new_rt + 1;
             end if;
             new_rf = new_rt - 2;
          END IF;
          result := 'OK REVERSE DIRECTION ' || street.streetname || ' left first:' || lf || '-' || new_lt || ' left second: ' || new_lf || '-' || lt || ' right first: ' || rf || '-' || new_rt || ' right second: ' || new_rf || '-' || rt || ' ' || interpolate::text;

          END IF;
          INSERT INTO foss4g.streets
        (cfcc, l_f_add, l_t_add, r_f_add, r_t_add, prefix, name, type, suffix, placename, countyname, geom, strplace, streetname)
          VALUES
        (street.cfcc, lf, new_lt, rf, new_rt, street.prefix, street.name, street.type, street.suffix, street.placename, street.countyname, geom1, street.strplace, street.streetname);

          INSERT INTO foss4g.streets
        (cfcc, l_f_add, l_t_add, r_f_add, r_t_add, prefix, name, type, suffix, placename, countyname, geom, strplace, streetname)
          VALUES
        (street.cfcc, new_lf, lt, new_rf, rt, street.prefix, street.name, street.type, street.suffix, street.placename, street.countyname, geom2, street.strplace, street.streetname);
      DELETE FROM foss4g.streets where gid = streetgid;
       else
          result := 'mixed parity street address ranges for gid ' || streetgid;
       end if;   
    ELSE
       result := streetgid::text || ' Point is not a point';
    END IF;
    
    return result;
END;
$$
LANGUAGE 'plpgsql' VOLATILE;
