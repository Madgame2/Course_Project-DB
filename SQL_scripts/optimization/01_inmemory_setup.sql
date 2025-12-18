
ALTER SESSION SET container = KPDB_GAMESTORE;

SELECT 
    parameter_name,
    parameter_value
FROM v$parameter
WHERE parameter_name LIKE '%inmemory%';

-- Проверяем размер доступной памяти для In-Memory
SELECT 
    pool,
    ROUND(allocated_bytes/1024/1024/1024, 2) AS allocated_gb,
    ROUND(used_bytes/1024/1024/1024, 2) AS used_gb
FROM v$inmemory_area;


-- Устанавливаем размер In-Memory Column Store (если еще не настроено)
-- Требуются права DBA
-- ALTER SYSTEM SET inmemory_size = 4G SCOPE=SPFILE;

-- ============================================================================
-- 3. ВКЛЮЧЕНИЕ IN-MEMORY ДЛЯ КЛЮЧЕВЫХ ТАБЛИЦ
-- ============================================================================
-- Таблицы, которые активно используются в аналитических запросах

-- UserActivity - самая важная таблица для аналитики
ALTER TABLE UserActivity INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY HIGH;

-- Users - используется для группировки по странам и ролям
ALTER TABLE Users INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;

-- Games - основная таблица игр
ALTER TABLE Games INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;

-- OfferGameLinks - связующая таблица для аналитики
ALTER TABLE OfferGameLinks INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;

-- Games_ganers - связь игр с жанрами
ALTER TABLE Games_ganers INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;

-- Geners - справочник жанров
ALTER TABLE Geners INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY LOW;

-- Folowers - подписчики игр
ALTER TABLE Folowers INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;

-- GamePages - страницы игр
ALTER TABLE GamePages INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;

-- Offers - предложения
ALTER TABLE Offers INMEMORY 
MEMCOMPRESS FOR QUERY HIGH
PRIORITY MEDIUM;


ALTER TABLE UserActivity 
NO INMEMORY (Details, IpAddress, UserAgent);

-- Users: включаем только аналитические колонки
ALTER TABLE Users 
NO INMEMORY (PasswordHash, Avatar_uri);



SELECT
    segment_name,
    inmemory_size,
    populate_status
FROM v$im_segments;

SELECT 
    owner,
    segment_name,
    inmemory_size,
    bytes_not_populated,
    populate_status,
    inmemory_priority,
    inmemory_compression
FROM v$im_segments
WHERE segment_name IN (
    'USERACTIVITY', 'USERS', 'GAMES', 'OFFERGAMELINKS',
    'GAMES_GANERS', 'GENERS', 'FOLOWERS', 'GAMEPAGES', 'OFFERS'
)
ORDER BY inmemory_size DESC NULLS LAST;

-- Детальная информация по таблице UserActivity
SELECT 
    column_name,
    inmemory_compression,
    inmemory_duplicate
FROM v$im_column_level
WHERE owner = USER
AND table_name = 'USERACTIVITY';


ALTER TABLE UserActivity INMEMORY;


SELECT 
    segment_name,
    populate_status,
    ROUND(bytes_not_populated/1024/1024, 2) AS mb_not_populated,
    ROUND(inmemory_size/1024/1024, 2) AS mb_in_memory
FROM v$im_segments
WHERE segment_name = 'USERACTIVITY';


SELECT 
    sql_id,
    sql_text,
    inmemory_io,
    inmemory_io_bytes,
    inmemory_io_saved_bytes
FROM v$sql
WHERE inmemory_io > 0
ORDER BY inmemory_io_bytes DESC
FETCH FIRST 10 ROWS ONLY;

-- Статистика использования In-Memory
SELECT 
    pool,
    ROUND(allocated_bytes/1024/1024/1024, 2) AS allocated_gb,
    ROUND(used_bytes/1024/1024/1024, 2) AS used_gb,
    ROUND(populate_bytes/1024/1024/1024, 2) AS populate_gb
FROM v$inmemory_area;




