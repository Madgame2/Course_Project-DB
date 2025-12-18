

SET SERVEROUTPUT ON;
ALTER SESSION SET CONTAINER = KPDB_GAMESTORE;

DECLARE
    v_file_handle UTL_FILE.FILE_TYPE;
    v_json_data CLOB;
    v_file_path VARCHAR2(255) := 'USERACTIVITY_EXPORT.json'; 
    v_row_count NUMBER := 0;
    v_first_row BOOLEAN := TRUE;
    

    CURSOR c_user_activity IS
        SELECT 
            ID,
            UserID,
            ActionType,
            EntityType,
            EntityID,
            Details,
            CreatedAt,
            IpAddress,
            UserAgent
        FROM UserActivity
        ORDER BY ID;
    
BEGIN




    v_file_handle := UTL_FILE.FOPEN('JSON_EXPORT_DIR', 'USERACTIVITY_EXPORT.json', 'W', 32767);
    

    UTL_FILE.PUT_LINE(v_file_handle, '[');
    

    FOR rec IN c_user_activity LOOP
        IF NOT v_first_row THEN
            UTL_FILE.PUT_LINE(v_file_handle, ',');
        END IF;
        v_first_row := FALSE;
        

        v_json_data := '{' ||
            '"ID":' || rec.ID || ',' ||
            '"UserID":' || rec.UserID || ',' ||
            '"ActionType":' || rec.ActionType || ',' ||
            '"EntityType":' || rec.EntityType || ',' ||
            '"EntityID":' || rec.EntityID || ',' ||
            '"Details":' || 
                CASE 
                    WHEN rec.Details IS NULL THEN 'null'
                    ELSE '"' || REPLACE(REPLACE(REPLACE(rec.Details, '\', '\\'), '"', '\"'), CHR(10), '\n') || '"'
                END || ',' ||
            '"CreatedAt":' ||
                CASE 
                    WHEN rec.CreatedAt IS NULL THEN 'null'
                    ELSE '"' || TO_CHAR(rec.CreatedAt, 'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM') || '"'
                END || ',' ||
            '"IpAddress":' ||
                CASE 
                    WHEN rec.IpAddress IS NULL THEN 'null'
                    ELSE '"' || REPLACE(REPLACE(rec.IpAddress, '\', '\\'), '"', '\"') || '"'
                END || ',' ||
            '"UserAgent":' ||
                CASE 
                    WHEN rec.UserAgent IS NULL THEN 'null'
                    ELSE '"' || REPLACE(REPLACE(REPLACE(rec.UserAgent, '\', '\\'), '"', '\"'), CHR(10), '\n') || '"'
                END ||
            '}';
        
        UTL_FILE.PUT_LINE(v_file_handle, v_json_data);
        v_row_count := v_row_count + 1;
    END LOOP;
    

    UTL_FILE.PUT_LINE(v_file_handle, ']');
    

    UTL_FILE.FCLOSE(v_file_handle);
    
    DBMS_OUTPUT.PUT_LINE('Экспортировано строк: ' || v_row_count);
    

    IF v_row_count > 0 THEN
        DELETE FROM UserActivity;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Данные успешно удалены из таблицы UserActivity');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Нет данных для экспорта');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('Экспорт завершен. Файл: USERACTIVITY_EXPORT.json');
    
EXCEPTION
    WHEN UTL_FILE.INVALID_PATH THEN
        DBMS_OUTPUT.PUT_LINE('ОШИБКА: Неверный путь к файлу. Убедитесь, что директория JSON_EXPORT_DIR существует.');
        DBMS_OUTPUT.PUT_LINE('Выполните: @schema/setup_docker_directory.sql');
        DBMS_OUTPUT.PUT_LINE('И создайте директорию в Docker: docker exec -it <container> mkdir -p /opt/oracle/json_export');
        IF UTL_FILE.IS_OPEN(v_file_handle) THEN
            UTL_FILE.FCLOSE(v_file_handle);
        END IF;
    WHEN UTL_FILE.INVALID_OPERATION THEN
        DBMS_OUTPUT.PUT_LINE('ОШИБКА: Невозможно выполнить операцию с файлом. Проверьте права доступа.');
        IF UTL_FILE.IS_OPEN(v_file_handle) THEN
            UTL_FILE.FCLOSE(v_file_handle);
        END IF;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ОШИБКА: ' || SQLERRM);
        IF UTL_FILE.IS_OPEN(v_file_handle) THEN
            UTL_FILE.FCLOSE(v_file_handle);
        END IF;
        RAISE;
END;
/

