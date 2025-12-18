
ALTER SESSION SET CONTAINER = KPDB_GAMESTORE;

CREATE OR REPLACE PROCEDURE print_clob(
    p_clob IN CLOB,
    p_chunk_size IN NUMBER DEFAULT 3000
) IS
    v_offset NUMBER := 1;
    v_chunk VARCHAR2(32767);
    v_clob_length NUMBER;
    v_actual_size NUMBER;
BEGIN
    IF p_clob IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('(NULL)');
        RETURN;
    END IF;
    
    v_clob_length := DBMS_LOB.GETLENGTH(p_clob);
    
    IF v_clob_length = 0 THEN
        DBMS_OUTPUT.PUT_LINE('(EMPTY)');
        RETURN;
    END IF;
    
    -- Выводим CLOB частями (используем меньший размер для безопасности с многобайтовыми символами)
    WHILE v_offset <= v_clob_length LOOP
        -- Определяем фактический размер для чтения (не больше оставшегося)
        v_actual_size := LEAST(p_chunk_size, v_clob_length - v_offset + 1);
        
        -- Читаем часть CLOB
        v_chunk := DBMS_LOB.SUBSTR(p_clob, v_actual_size, v_offset);
        
        -- Выводим только если не пусто
        IF v_chunk IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE(v_chunk);
        END IF;
        
        v_offset := v_offset + v_actual_size;
    END LOOP;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error printing CLOB: ' || SQLERRM);
        RAISE;
END print_clob;
/


GRANT EXECUTE ON app_user.print_clob TO GUEST;
GRANT EXECUTE ON app_user.print_clob TO USER_APP;

GRANT EXECUTE ON app_user.print_clob TO ADMIN;