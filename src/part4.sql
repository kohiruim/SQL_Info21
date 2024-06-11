-- part 4.1

CREATE TABLE IF NOT EXISTS new_table_1
(
    new_column text
);
CREATE TABLE IF NOT EXISTS new_table_2
(
    new_column text
);

DROP PROCEDURE IF EXISTS delete_tables(TableName text);
CREATE OR REPLACE PROCEDURE delete_tables(TableName text)
    LANGUAGE plpgsql
AS
$$
BEGIN
    FOR TableName IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_name LIKE TableName || '%'
        LOOP
            EXECUTE 'DROP TABLE IF EXISTS ' || TableName || ' CASCADE';
        END LOOP;
END;
$$;

-- CALL delete_tables('new_table');

-- part 4.2

DROP FUNCTION IF EXISTS fnc_1(num INTEGER);
CREATE OR REPLACE FUNCTION fnc_1(num INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql AS
$$
BEGIN
    num := 1;
END;
$$;

DROP FUNCTION IF EXISTS fnc_2(num INTEGER);
CREATE OR REPLACE FUNCTION fnc_2(num INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql AS
$$
BEGIN
    num := 2;
END;
$$;

CREATE OR REPLACE PROCEDURE get_scalar_functions_with_params(OUT function_count INTEGER)
    LANGUAGE plpgsql AS
$$
BEGIN
    WITH f AS (SELECT STRING_AGG(proname || '(' || PG_GET_FUNCTION_ARGUMENTS(pg_proc.oid) || ')',
                                 E'\n') AS functions
               FROM pg_proc
                        JOIN pg_namespace pn ON pg_proc.pronamespace = pn.oid
               WHERE pn.nspname = 'public' -- в текущей бд
                 AND prokind = 'f'         -- функция
                 AND proargtypes != ''     -- не пустые аргументы функции
                 AND proretset = FALSE     -- не множество
                 AND prorettype <> 2278    -- oid с типом 'void'
               GROUP BY proname)
    SELECT COUNT(*)
    FROM f
    INTO function_count;
END;
$$;

-- CALL get_scalar_functions_with_params(NULL);


-- 4.3) процедура, которая уничтожает все SQL DML триггеры в бд. 
-- Выходной параметр - количество уничтоженных триггеров

CREATE OR REPLACE PROCEDURE prc_drop_trgg(INOUT count INTEGER DEFAULT 0)
    LANGUAGE plpgsql AS
$$
DECLARE
    trg_name varchar;
    tbl_name varchar;
BEGIN
    FOR tbl_name, trg_name IN (SELECT event_object_table AS table_name, trigger_name FROM information_schema.triggers)
        LOOP
            EXECUTE FORMAT('DROP TRIGGER IF EXISTS %I ON %I', trg_name, tbl_name);
            count = count + 1;
        END LOOP;
END;
$$;

-- CALL prc_drop_trgg();

-- 4.4) процедура с входным параметром
-- выводит имена и описания типа объектов (хранимых процедур и скалярных функций), 
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.

CREATE OR REPLACE PROCEDURE prc_output_info_objects(cursor REFCURSOR, input varchar)
AS
$$
BEGIN
    OPEN cursor FOR
        SELECT routine_name, routine_type
        FROM INFORMATION_SCHEMA.ROUTINES AS routines
        WHERE routines.specific_schema = 'public'
          AND routine_name LIKE CONCAT('%', input, '%');

END;
$$ LANGUAGE plpgsql;



-- BEGIN;
-- CALL prc_output_info_objects('refcursor', 'check');
-- FETCH ALL IN "refcursor";
-- COMMIT;

-- BEGIN;
-- CALL prc_output_info_objects('refcursor', 'verter');
-- FETCH ALL IN "refcursor";
-- COMMIT;