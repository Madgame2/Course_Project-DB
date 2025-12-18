

ALTER SESSION SET CONTAINER = KPDB_GAMESTORE;



-- docker exec -it <container_name> mkdir -p /opt/oracle/json_export
-- docker exec -it <container_name> chown oracle:oinstall /opt/oracle/json_export
-- docker exec -it <container_name> chmod 777 /opt/oracle/json_export

-- Создаем Oracle директорию (требуются права DBA)
CREATE OR REPLACE DIRECTORY JSON_EXPORT_DIR AS '/opt/oracle/json_export';

-- Предоставляем права на чтение/запись
GRANT READ, WRITE ON DIRECTORY JSON_EXPORT_DIR TO APP_USER;
GRANT READ, WRITE ON DIRECTORY JSON_EXPORT_DIR TO ADMIN;

-- Проверяем создание директории
SELECT directory_name, directory_path 
FROM all_directories 
WHERE directory_name = 'JSON_EXPORT_DIR';

SELECT 'Директория JSON_EXPORT_DIR успешно создана!' AS status FROM DUAL;


