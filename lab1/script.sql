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
