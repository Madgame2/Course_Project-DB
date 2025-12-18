

SET SERVEROUTPUT ON;
ALTER SESSION SET CONTAINER = KPDB_GAMESTORE;

DECLARE
    v_file_handle UTL_FILE.FILE_TYPE;
    v_json_content CLOB;
    v_line VARCHAR2(32767);
    v_json_data JSON_ARRAY_T;
    v_json_obj JSON_OBJECT_T;
    v_count NUMBER := 0;
    v_errors NUMBER := 0;
    
BEGIN
    -- Читаем JSON файл
    v_file_handle := UTL_FILE.FOPEN('JSON_EXPORT_DIR', 'USERACTIVITY_EXPORT.json', 'R', 32767);
    
    -- Читаем весь файл в CLOB
    BEGIN
        LOOP
            BEGIN
                UTL_FILE.GET_LINE(v_file_handle, v_line);
                v_json_content := v_json_content || v_line || CHR(10);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    EXIT;
            END;
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END;
    
    UTL_FILE.FCLOSE(v_file_handle);
    
    -- Парсим JSON
    v_json_data := JSON_ARRAY_T(v_json_content);
    
    DBMS_OUTPUT.PUT_LINE('Найдено записей в JSON: ' || v_json_data.get_size());
    
    -- Обрабатываем каждую запись
    FOR i IN 0 .. v_json_data.get_size() - 1 LOOP
        DECLARE
            v_user_id NUMBER;
            v_action_type NUMBER;
            v_entity_type NUMBER;
            v_entity_id NUMBER;
            v_details NVARCHAR2(255);
            v_created_at TIMESTAMP WITH TIME ZONE;
            v_ip_address VARCHAR2(45);
            v_user_agent VARCHAR(512);
            v_created_at_str VARCHAR2(100);
        BEGIN
            v_json_obj := JSON_OBJECT_T(v_json_data.get(i));
            
            -- Извлекаем значения в переменные
            v_user_id := v_json_obj.get_number('UserID');
            v_action_type := v_json_obj.get_number('ActionType');
            v_entity_type := v_json_obj.get_number('EntityType');
            v_entity_id := v_json_obj.get_number('EntityID');
            
            -- Обрабатываем строковые поля с проверкой на NULL
            IF v_json_obj.get('Details').is_null THEN
                v_details := NULL;
            ELSE
                v_details := v_json_obj.get_string('Details');
            END IF;
            
            IF v_json_obj.get('CreatedAt').is_null THEN
                v_created_at := NULL;
            ELSE
                v_created_at_str := v_json_obj.get_string('CreatedAt');
                v_created_at_str := REGEXP_REPLACE(REGEXP_REPLACE(v_created_at_str, 'T', ' '), 'Z$', '+00:00');
                v_created_at := TO_TIMESTAMP_TZ(v_created_at_str, 'YYYY-MM-DD HH24:MI:SS.FF TZH:TZM');
            END IF;
            
            IF v_json_obj.get('IpAddress').is_null THEN
                v_ip_address := NULL;
            ELSE
                v_ip_address := v_json_obj.get_string('IpAddress');
            END IF;
            
            IF v_json_obj.get('UserAgent').is_null THEN
                v_user_agent := NULL;
            ELSE
                v_user_agent := v_json_obj.get_string('UserAgent');
            END IF;
            
            -- Вставляем данные в таблицу
            INSERT INTO UserActivity (
                UserID,
                ActionType,
                EntityType,
                EntityID,
                Details,
                CreatedAt,
                IpAddress,
                UserAgent
            ) VALUES (
                v_user_id,
                v_action_type,
                v_entity_type,
                v_entity_id,
                v_details,
                v_created_at,
                v_ip_address,
                v_user_agent
            );
            
            v_count := v_count + 1;
            
            -- Коммитим каждые 100 записей для производительности
            IF MOD(v_count, 100) = 0 THEN
                COMMIT;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_errors := v_errors + 1;
                DBMS_OUTPUT.PUT_LINE('Ошибка при импорте записи ' || i || ': ' || SQLERRM);
                -- Продолжаем обработку остальных записей
        END;
    END LOOP;
    
    -- Финальный коммит
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Импортировано успешно: ' || v_count || ' записей');
    IF v_errors > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Ошибок при импорте: ' || v_errors);
    END IF;
    
EXCEPTION
    WHEN UTL_FILE.INVALID_PATH THEN
        DBMS_OUTPUT.PUT_LINE('ОШИБКА: Файл USERACTIVITY_EXPORT.json не найден в директории JSON_EXPORT_DIR');
        DBMS_OUTPUT.PUT_LINE('Скопируйте файл в Docker контейнер:');
        DBMS_OUTPUT.PUT_LINE('docker cp USERACTIVITY_EXPORT.json <container>:/opt/oracle/json_export/');
        IF UTL_FILE.IS_OPEN(v_file_handle) THEN
            UTL_FILE.FCLOSE(v_file_handle);
        END IF;
    WHEN UTL_FILE.INVALID_OPERATION THEN
        DBMS_OUTPUT.PUT_LINE('ОШИБКА: Невозможно прочитать файл. Проверьте права доступа.');
        IF UTL_FILE.IS_OPEN(v_file_handle) THEN
            UTL_FILE.FCLOSE(v_file_handle);
        END IF;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ОШИБКА: ' || SQLERRM);
        IF UTL_FILE.IS_OPEN(v_file_handle) THEN
            UTL_FILE.FCLOSE(v_file_handle);
        END IF;
        ROLLBACK;
        RAISE;
END;
/