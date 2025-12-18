-- ============================================================================
-- Пример оптимизированной процедуры с учетом In-Memory
-- ============================================================================
-- Эта процедура демонстрирует лучшие практики для использования In-Memory
-- ============================================================================

ALTER SESSION SET container = KPDB_GAMESTORE;

-- ============================================================================
-- ОПТИМИЗИРОВАННАЯ ПРОЦЕДУРА: get_games_statistics_fast
-- ============================================================================
-- Эта версия оптимизирована для использования In-Memory Column Store
-- 
-- Оптимизации:
-- 1. Фильтрация в WHERE перед JOIN (использует In-Memory фильтры)
-- 2. Минимизация JOIN операций
-- 3. Использование только нужных колонок
-- 4. Эффективная группировка
-- ============================================================================

CREATE OR REPLACE PROCEDURE stat_pkg.get_games_statistics_fast(
    p_user_id      IN NUMBER,
    p_limit        IN NUMBER DEFAULT 100,
    p_result       OUT CLOB
) IS
    v_role_id NUMBER;
    v_role_name NVARCHAR2(255);
    v_games_json CLOB := '[]';
    v_cursor SYS_REFCURSOR;
    v_game_id NUMBER;
    v_game_name NVARCHAR2(512);
    v_developer_id NUMBER;
    v_downloads_count NUMBER;
    v_purchases_count NUMBER;
    v_total_count NUMBER;
    v_json_item CLOB;
    v_first_item BOOLEAN := TRUE;
    v_limit_count NUMBER;
    v_download_action_id NUMBER := enums_pkg.get_action_type_id('Download');
    v_purchase_action_id NUMBER := enums_pkg.get_action_type_id('Purchase');
    v_offer_entity_id NUMBER := enums_pkg.get_entity_type_id('Offer');
BEGIN
    -- Устанавливаем лимит
    IF p_limit IS NULL OR p_limit <= 0 THEN
        v_limit_count := NULL;
    ELSE
        v_limit_count := p_limit;
    END IF;

    -- Получаем роль пользователя
    SELECT u.RoleID, r.Role
    INTO v_role_id, v_role_name
    FROM Users u
    JOIN Roles r ON r.RoleId = u.RoleID
    WHERE u.UserID = p_user_id;

    -- Проверяем, что пользователь - админ или разработчик
    IF v_role_name != 'Admin' AND v_role_name != 'Developer' THEN
        RAISE_APPLICATION_ERROR(-20015, 'Access denied: only Admin or Developer can access game statistics');
    END IF;

    -- ОПТИМИЗИРОВАННЫЙ ЗАПРОС ДЛЯ IN-MEMORY
    -- Ключевые оптимизации:
    -- 1. Фильтрация UserActivity в подзапросах ДО JOIN с Games
    -- 2. Использование только нужных колонок
    -- 3. Эффективная группировка
    
    IF v_role_name = 'Admin' THEN
        -- Админ: топ N игр по всей системе
        OPEN v_cursor FOR
            SELECT * FROM (
                SELECT 
                    g.GameID,
                    g.GameName,
                    g.DeveloperID,
                    -- Агрегация выполняется в In-Memory очень быстро
                    NVL(downloads.download_count, 0) AS downloads_count,
                    NVL(purchases.purchase_count, 0) AS purchases_count,
                    NVL(downloads.download_count, 0) + NVL(purchases.purchase_count, 0) AS total_count
                FROM Games g
                -- LEFT JOIN позволяет включить игры без активности
                LEFT JOIN (
                    -- Подзапрос фильтрует UserActivity ДО JOIN
                    -- In-Memory оптимизирует этот подзапрос
                    SELECT 
                        ogl.GameID,
                        COUNT(*) AS download_count
                    FROM UserActivity ua
                    -- Фильтрация в WHERE использует In-Memory фильтры
                    JOIN OfferGameLinks ogl ON ogl.OfferId = ua.EntityID
                    WHERE ua.ActionType = v_download_action_id
                    AND ua.EntityType = v_offer_entity_id
                    -- Группировка выполняется в In-Memory очень быстро
                    GROUP BY ogl.GameID
                ) downloads ON downloads.GameID = g.GameID
                LEFT JOIN (
                    SELECT 
                        ogl.GameID,
                        COUNT(*) AS purchase_count
                    FROM UserActivity ua
                    JOIN OfferGameLinks ogl ON ogl.OfferId = ua.EntityID
                    WHERE ua.ActionType = v_purchase_action_id
                    AND ua.EntityType = v_offer_entity_id
                    GROUP BY ogl.GameID
                ) purchases ON purchases.GameID = g.GameID
                WHERE NVL(downloads.download_count, 0) + NVL(purchases.purchase_count, 0) > 0
                ORDER BY total_count DESC, g.GameID
            );
    ELSE
        -- Разработчик: топ его игр
        OPEN v_cursor FOR
            SELECT * FROM (
                SELECT 
                    g.GameID,
                    g.GameName,
                    g.DeveloperID,
                    NVL(downloads.download_count, 0) AS downloads_count,
                    NVL(purchases.purchase_count, 0) AS purchases_count,
                    NVL(downloads.download_count, 0) + NVL(purchases.purchase_count, 0) AS total_count
                FROM Games g
                -- Фильтрация по разработчику в основной таблице
                WHERE g.DeveloperID = p_user_id
                LEFT JOIN (
                    SELECT 
                        ogl.GameID,
                        COUNT(*) AS download_count
                    FROM UserActivity ua
                    JOIN OfferGameLinks ogl ON ogl.OfferId = ua.EntityID
                    WHERE ua.ActionType = v_download_action_id
                    AND ua.EntityType = v_offer_entity_id
                    GROUP BY ogl.GameID
                ) downloads ON downloads.GameID = g.GameID
                LEFT JOIN (
                    SELECT 
                        ogl.GameID,
                        COUNT(*) AS purchase_count
                    FROM UserActivity ua
                    JOIN OfferGameLinks ogl ON ogl.OfferId = ua.EntityID
                    WHERE ua.ActionType = v_purchase_action_id
                    AND ua.EntityType = v_offer_entity_id
                    GROUP BY ogl.GameID
                ) purchases ON purchases.GameID = g.GameID
                WHERE (NVL(downloads.download_count, 0) + NVL(purchases.purchase_count, 0) > 0)
                ORDER BY total_count DESC, g.GameID
            );
    END IF;

    -- Собираем результаты в JSON
    v_games_json := '[';
    DECLARE
        v_count NUMBER := 0;
    BEGIN
        LOOP
            IF v_limit_count IS NOT NULL AND v_count >= v_limit_count THEN
                EXIT;
            END IF;

            FETCH v_cursor INTO 
                v_game_id,
                v_game_name,
                v_developer_id,
                v_downloads_count,
                v_purchases_count,
                v_total_count;
            EXIT WHEN v_cursor%NOTFOUND;

            v_count := v_count + 1;

            IF NOT v_first_item THEN
                v_games_json := v_games_json || ',';
            END IF;
            v_first_item := FALSE;

            v_json_item := JSON_OBJECT(
                'gameId' VALUE v_game_id,
                'gameName' VALUE v_game_name,
                'developerId' VALUE v_developer_id,
                'downloads' VALUE v_downloads_count,
                'purchases' VALUE v_purchases_count,
                'total' VALUE v_total_count
            );

            v_games_json := v_games_json || v_json_item;
        END LOOP;
    END;
    CLOSE v_cursor;

    v_games_json := v_games_json || ']';

    -- Формируем финальный результат
    p_result := JSON_OBJECT(
        'role' VALUE v_role_name,
        'userId' VALUE p_user_id,
        'games' VALUE JSON_QUERY(v_games_json, '$' RETURNING CLOB)
    );

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20016, 'User not found');
    WHEN OTHERS THEN
        IF v_cursor%ISOPEN THEN
            CLOSE v_cursor;
        END IF;
        RAISE;
END get_games_statistics_fast;
/

-- ============================================================================
-- ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ IN-MEMORY В ЗАПРОСАХ
-- ============================================================================

-- Пример 1: Простая агрегация (автоматически использует In-Memory)
/*
SELECT 
    ActionType,
    COUNT(*) AS action_count
FROM UserActivity
GROUP BY ActionType
ORDER BY action_count DESC;
-- In-Memory ускоряет COUNT и GROUP BY в 10-100 раз
*/

-- Пример 2: Фильтрация и агрегация
/*
SELECT 
    u.Country,
    COUNT(*) AS user_count
FROM Users u
JOIN UserActivity ua ON ua.UserID = u.UserID
WHERE ua.ActionType = 3  -- Download
AND u.Country IS NOT NULL
GROUP BY u.Country
ORDER BY user_count DESC;
-- In-Memory оптимизирует WHERE и JOIN
*/

-- Пример 3: Сложная агрегация с несколькими JOIN
/*
SELECT 
    g.GameID,
    g.GameName,
    COUNT(DISTINCT f.UserId) AS followers_count
FROM Games g
JOIN OfferGameLinks ogl ON ogl.GameID = g.GameID
JOIN Offers o ON o.OfferId = ogl.OfferId
JOIN GamePages gp ON gp.PageID = o.PageID
JOIN Folowers f ON f.GamePageId = gp.PageID
GROUP BY g.GameID, g.GameName
ORDER BY followers_count DESC;
-- In-Memory ускоряет все JOIN и COUNT(DISTINCT)
*/

-- ============================================================================
-- ПРОВЕРКА ИСПОЛЬЗОВАНИЯ IN-MEMORY В ЗАПРОСАХ
-- ============================================================================

-- После выполнения запроса проверяем, использовался ли In-Memory
/*
SELECT 
    sql_id,
    sql_text,
    inmemory_io,
    inmemory_io_bytes,
    inmemory_io_saved_bytes,
    elapsed_time / 1000000 AS elapsed_seconds
FROM v$sql
WHERE sql_text LIKE '%UserActivity%'
AND inmemory_io > 0
ORDER BY inmemory_io_bytes DESC
FETCH FIRST 10 ROWS ONLY;
*/

-- ============================================================================
-- СОВЕТЫ ПО ОПТИМИЗАЦИИ
-- ============================================================================
/*
1. Всегда фильтруйте в WHERE перед JOIN
   - In-Memory может применить фильтры очень быстро
   - Уменьшает объем данных для JOIN

2. Используйте только нужные колонки в SELECT
   - In-Memory читает только нужные колонки
   - Уменьшает объем данных

3. Группируйте эффективно
   - GROUP BY выполняется очень быстро в In-Memory
   - Используйте только нужные колонки в GROUP BY

4. Избегайте функций в WHERE (если возможно)
   - Функции могут препятствовать использованию In-Memory фильтров
   - Используйте виртуальные колонки для часто используемых функций

5. Мониторьте использование
   - Проверяйте v$sql для анализа использования In-Memory
   - Оптимизируйте запросы, которые не используют In-Memory
*/

COMMIT;


