

SET SERVEROUTPUT ON;

ALTER SESSION SET CONTAINER = CDB$ROOT;

-- Проверяем текущее значение
SELECT 
    name,
    value,
    display_value,
    CASE 
        WHEN value = '0' THEN 'НЕ НАСТРОЕН'
        ELSE 'НАСТРОЕН: ' || display_value
    END AS status
FROM v$parameter
WHERE name = 'inmemory_size';


ALTER SYSTEM SET inmemory_size = 4G SCOPE=SPFILE;


SELECT 
    name,
    value,
    display_value,
    isdefault,
    issys_modifiable
FROM v$parameter
WHERE name = 'inmemory_size';




