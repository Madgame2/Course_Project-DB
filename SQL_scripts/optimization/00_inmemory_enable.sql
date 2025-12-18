
SET SERVEROUTPUT ON;
ALTER SESSION SET container = KPDB_GAMESTORE;

DECLARE
    v_inmemory_size NUMBER;
    v_inmemory_available VARCHAR2(3);
    v_count NUMBER;
BEGIN
    -- Проверяем, включена ли опция In-Memory
    SELECT COUNT(*)
    INTO v_count
    FROM v$parameter
    WHERE name = 'inmemory_size';
    
    IF v_count > 0 THEN
        v_inmemory_available := 'YES';
        SELECT NVL(TO_NUMBER(value), 0)
        INTO v_inmemory_size
        FROM v$parameter
        WHERE name = 'inmemory_size';
    ELSE
        v_inmemory_available := 'NO';
        v_inmemory_size := 0;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('In-Memory доступен: ' || v_inmemory_available);
    DBMS_OUTPUT.PUT_LINE('Размер In-Memory: ' || ROUND(v_inmemory_size/1024/1024/1024, 2) || ' GB');
    DBMS_OUTPUT.PUT_LINE('');
    
    IF v_inmemory_size = 0 THEN
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('ВНИМАНИЕ: In-Memory не настроен!');
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Для включения In-Memory выполните (требуются права DBA):');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('1. Подключитесь к CDB$ROOT как SYSDBA:');
        DBMS_OUTPUT.PUT_LINE('   ALTER SESSION SET CONTAINER = CDB$ROOT;');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('2. Установите размер In-Memory (рекомендуется 4-8 GB):');
        DBMS_OUTPUT.PUT_LINE('   ALTER SYSTEM SET inmemory_size = 4G SCOPE=SPFILE;');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('3. Перезапустите базу данных');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('4. После перезапуска выполните этот скрипт снова');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Продолжаем выполнение скрипта...');
        DBMS_OUTPUT.PUT_LINE('(In-Memory будет включен для таблиц, но данные');
        DBMS_OUTPUT.PUT_LINE(' не будут загружаться в память до настройки параметра)');
        DBMS_OUTPUT.PUT_LINE('');
    ELSE
        DBMS_OUTPUT.PUT_LINE('In-Memory доступен и настроен');
        DBMS_OUTPUT.PUT_LINE('');
    END IF;
END;
/

-- Проверяем использование памяти (только если In-Memory настроен)
BEGIN
    DECLARE
        v_inmemory_size NUMBER;
    BEGIN
        SELECT NVL(TO_NUMBER(value), 0)
        INTO v_inmemory_size
        FROM v$parameter
        WHERE name = 'inmemory_size';
        
        IF v_inmemory_size > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Использование памяти In-Memory:');
            DBMS_OUTPUT.PUT_LINE('');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Пропускаем, если In-Memory не настроен
    END;
END;
/

SELECT 
    pool,
    ROUND(allocated_bytes/1024/1024/1024, 2) AS allocated_gb,
    ROUND(used_bytes/1024/1024/1024, 2) AS used_gb,
    ROUND(populate_bytes/1024/1024/1024, 2) AS populate_gb
FROM v$inmemory_area
WHERE ROWNUM <= 10; -- Ограничиваем вывод, чтобы избежать ошибок


-- UserActivity - самая важная таблица для аналитики
PROMPT Включение In-Memory для UserActivity...
ALTER TABLE UserActivity INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY HIGH;

-- Исключаем колонки, которые не используются в аналитике
ALTER TABLE UserActivity 
NO INMEMORY (Details, IpAddress, UserAgent);


-- Users - используется для группировки по странам и ролям
PROMPT Включение In-Memory для Users...
ALTER TABLE Users INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;

-- Исключаем колонки, которые не используются в аналитике
ALTER TABLE Users 
NO INMEMORY (PasswordHash, Avatar_uri);


-- Games - основная таблица игр
PROMPT Включение In-Memory для Games...
ALTER TABLE Games INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;


-- OfferGameLinks - связующая таблица для аналитики
PROMPT Включение In-Memory для OfferGameLinks...
ALTER TABLE OfferGameLinks INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;


-- Games_ganers - связь игр с жанрами
PROMPT Включение In-Memory для Games_ganers...
ALTER TABLE Games_ganers INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;


-- Geners - справочник жанров
PROMPT Включение In-Memory для Geners...
ALTER TABLE Geners INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY LOW;



-- Folowers - подписчики игр
PROMPT Включение In-Memory для Folowers...
ALTER TABLE Folowers INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;



-- GamePages - страницы игр
PROMPT Включение In-Memory для GamePages...
ALTER TABLE GamePages INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;



-- Offers - предложения
PROMPT Включение In-Memory для Offers...
ALTER TABLE Offers INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;


-- Принудительно запускаем загрузку таблиц в память

BEGIN
    -- Принудительная загрузка через SELECT
    FOR rec IN (
        SELECT table_name 
        FROM user_tables 
        WHERE table_name IN (
            'USERACTIVITY', 'USERS', 'GAMES', 'OFFERGAMELINKS',
            'GAMES_GANERS', 'GENERS', 'FOLOWERS', 'GAMEPAGES', 'OFFERS'
        )
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || rec.table_name || ' WHERE ROWNUM <= 1';
            DBMS_OUTPUT.PUT_LINE('  Загрузка ' || rec.table_name || '...');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  Предупреждение: ' || rec.table_name || ' - ' || SQLERRM);
        END;
    END LOOP;
END;
/

-- Проверяем статус загрузки всех таблиц
SELECT 
    segment_name AS "Таблица",
    CASE populate_status
        WHEN 'STARTED' THEN 'Загрузка начата'
        WHEN 'COMPLETED' THEN 'Загружена'
        WHEN 'QUEUED' THEN 'В очереди'
        WHEN 'POPULATING' THEN 'Загружается...'
        ELSE populate_status
    END AS "Статус",
    ROUND(inmemory_size/1024/1024, 2) AS "Размер (MB)",
    ROUND(bytes_not_populated/1024/1024, 2) AS "Осталось (MB)",
    inmemory_priority AS "Приоритет",
    inmemory_compression AS "Сжатие"
FROM v$im_segments
WHERE segment_name IN (
    'USERACTIVITY', 'USERS', 'GAMES', 'OFFERGAMELINKS',
    'GAMES_GANERS', 'GENERS', 'FOLOWERS', 'GAMEPAGES', 'OFFERS'
)
ORDER BY 
    CASE inmemory_priority
        WHEN 'HIGH' THEN 1
        WHEN 'MEDIUM' THEN 2
        WHEN 'LOW' THEN 3
        ELSE 4
    END,
    inmemory_size DESC NULLS LAST;

-- Детальная информация по самой важной таблице
SELECT 
    column_name AS "Колонка",
    CASE inmemory_compression
        WHEN 'FOR QUERY HIGH' THEN 'Высокое сжатие'
        WHEN 'FOR QUERY LOW' THEN 'Низкое сжатие'
        WHEN 'NO INMEMORY' THEN '✗ Не в памяти'
        ELSE inmemory_compression
    END AS "Сжатие"
FROM v$im_column_level
WHERE owner = USER
AND table_name = 'USERACTIVITY'
ORDER BY column_name;


