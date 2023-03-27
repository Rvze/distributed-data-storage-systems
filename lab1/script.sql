DO
$$
    DECLARE
        row_count INTEGER := 1;
        file      record;
    BEGIN
        for file in
            select pg_database.oid
            from pg_database
            loop
                raise notice '%', file.oid;
            end loop;
    END
$$;


DO
$$
    DECLARE
        row_count INTEGER := 1;
    BEGIN
        FOR file IN
            SELECT oid,
                   (pg_stat_file(filename)).st_ctime AS creation_time,
                   CASE
                       WHEN (pg_stat_file(filename)).st_mode & 128 = 128 THEN 'READ WRITE'
                       ELSE 'READ ONLY'
                       END                           AS status
            FROM pg_database
                     JOIN pg_tablespace ON pg_database.dattablespace = pg_tablespace.oid
                     JOIN pg_file_settings()
                          ON pg_file_settings().setting = pg_tablespace.spcname || '/' || pg_database.datname || '.'
            WHERE pg_database.datname = current_database()
            LOOP
                RAISE NOTICE '% % % %', row_count, file.oid::text, to_timestamp(file.creation_time)::timestamp without time zone, file.status;
                row_count := row_count + 1;
            END LOOP;
    END
$$;

SELECT oid, spcname, pg_tablespace_location(oid) AS path
FROM pg_tablespace;

SELECT c.oid,
       c.relname,
       t.spcname,
       pg_relation_filepath(c.oid) as filename,
       c.relcreatedb
--        pg_stat_file(pg_relation_filepath(c.oid)) as creation_time
FROM pg_class c
         left JOIN pg_tablespace t ON c.reltablespace = t.oid
WHERE c.relkind IN ('r')
  and c.relfilenode != 0;

SELECT c.relname, relfilenode, pg_relation_filepath(relid), reltablespace, stats_start_time AS creation_time
FROM pg_class c
         JOIN pg_stat_all_tables ON c.oid = pg_stat_all_tables.relid
WHERE relkind = 'r'
  AND c.relname = 'crew';

SELECT relname,
       relfilenode,
       pg_relation_filepath(c.oid),
       reltablespace,
       pg_stat_file(('base/' || pg_database_size(current_database()) || '/' || relfilenode)::text) AS creation_time
FROM pg_class c
WHERE relkind = 'r'
  AND relname = 'crew';

select *
from pg_stat_user_tables
where last_vacuum > now() - interval '3 days';

create table bruh
(
    seq serial primary key
);


do
$$
    declare
        row_number      int        = 0;
        file_record     record;
        file_number     varchar(7) = '0000000';
        temp_row_number int        = 0;
        size            int        = 6;
        count           int        = 1;

    begin
        raise notice ' No. FILE#	      CREATION_TIME	          STATUS';
        raise notice '--- -----------   ----------------------  ------------------------------';
        for file_record in select *
                           from pg_class c
                           where relkind = 'r'
            loop
                if temp_row_number >= pow(10::double precision, count::double precision) then
                    file_number = substring(file_number, 0, size);
                    size = size - 1;
                    count = count + 1;
                end if;


                raise notice '%     %       %', row_number, file_number || row_number::varchar,
                    split_part(pg_stat_file(pg_relation_filepath(file_record.oid))::varchar, ',', 4)::timestamp;
                row_number = row_number + 1;
                temp_row_number = temp_row_number + 1;

            end loop;
    end;
$$;

do
$$
    declare
        column_record  record;
        table_id       oid;
        my_column_name text;
        column_number  text;
        column_type    text;
        column_type_id oid;
        column_comment text;
        column_index   text;
        result         text;
    begin
        raise notice 'Таблица: %', :tab_name;
        raise notice 'No  Имя столбца    Атрибуты';
        raise notice '--- -------------- ------------------------------------------';
        select "oid" into table_id from ucheb.pg_catalog.pg_class where "relname" = :tab_name;
        for column_record in select * from ucheb.pg_catalog.pg_attribute where attrelid = table_id
            loop
                if column_record.attnum > 0 then
                    column_number = column_record.attnum;
                    my_column_name = column_record.attname;
                    column_type_id = column_record.atttypid;
                    select typname into column_type from ucheb.pg_catalog.pg_type where oid = column_type_id;

                    if column_record.atttypmod != -1 then
                        column_type = column_type || ' (' || column_record.atttypmod || ')';

                        if column_type = 'int4' then
                            column_type = 'NUMBER';
                        end if;
                    end if;

                    if column_record.attnotnull then
                        column_type = column_type || ' Not null';
                    end if;

                    select description
                    into column_comment
                    from ucheb.pg_catalog.pg_description
                    where objoid = table_id
                      and objsubid = column_record.attnum;
                    column_comment = '"' || column_comment || '"';

                    select pg_catalog.pg_indexes.indexname
                    from pg_indexes,
                         information_schema.columns as inf
                    where pg_indexes.tablename = :tab_name
                      and inf.column_name = my_column_name
                      and indexdef ~ (my_column_name)
                    into column_index;
                    column_index = '"' || column_index || '"';

                    select format('%-3s %-14s %-8s %-2s %s', column_number, my_column_name, 'Type', ':', column_type)
                    into result;
                    raise notice '%', result;

                    if length(column_comment) > 0 then
                        select format('%-18s %-8s %-2s %s', '|', 'Commen', ':', column_comment) into result;
                        raise notice '%', result;
                    end if;

                    if length(column_index) > 0 then
                        select format('%-18s %-8s %-2s %s', '|', 'Index', ':', column_index) into result;
                        raise notice '%', result;
                    end if;
                end if;
            end loop;
    end;
$$ LANGUAGE plpgsql;
