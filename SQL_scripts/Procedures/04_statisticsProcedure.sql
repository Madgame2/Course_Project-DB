



CREATE OR REPLACE VIEW V_GAMES_STATISTICS AS
SELECT 
    g.GameID,
    TO_CHAR(g.GameName) as GameName, -- Принудительно в VARCHAR2
    g.DeveloperID,
    COUNT(f.UserId) as followers_count,
    ROUND(AVG(f.Rating), 2) as avg_rating
FROM Games g
LEFT JOIN OfferGameLinks ogl ON g.GameID = ogl.GameID
LEFT JOIN Offers o ON ogl.OfferId = o.OfferId
LEFT JOIN GamePages gp ON o.PageID = gp.PageID
LEFT JOIN Folowers f ON gp.PageID = f.GamePageId
GROUP BY g.GameID, TO_CHAR(g.GameName), g.DeveloperID;


CREATE OR REPLACE PACKAGE stat_pkg
is

    PROCEDURE check_useractivity_access(
        p_user_id      IN NUMBER,
        p_activity_id  IN NUMBER
    );

    PROCEDURE get_user_statistics(
        p_user_id      IN NUMBER,
        p_target_user_id IN NUMBER,
        p_result       OUT CLOB
    );

    PROCEDURE get_games_statistics(
        p_user_id      IN NUMBER,
        p_limit        IN NUMBER DEFAULT 100,
        p_result       OUT CLOB
    );

    PROCEDURE get_top_genres_by_countries(
        p_limit        IN NUMBER DEFAULT 10,
        p_result       OUT CLOB
    );

    PROCEDURE get_top_games_by_followers(
        p_user_id      IN NUMBER,
        p_limit        IN NUMBER DEFAULT 100,
        p_result       OUT CLOB
    );

end stat_pkg;
/

CREATE OR REPLACE PACKAGE BODY stat_pkg
is
    
    
    PROCEDURE check_useractivity_access(
        p_user_id      IN NUMBER,
        p_activity_id  IN NUMBER
    ) IS
        v_role_id       NUMBER;
        v_owner_user_id NUMBER;
        v_entity_type   NUMBER;
        v_entity_id     NUMBER;
        v_game_entity_id NUMBER := enums_pkg.get_entity_type_id('Game');
        v_offer_entity_id NUMBER := enums_pkg.get_entity_type_id('Offer');
        v_gamepage_entity_id NUMBER := enums_pkg.get_entity_type_id('GamePage');
        v_user_entity_id NUMBER := enums_pkg.get_entity_type_id('User');
    BEGIN
        -- Получаем роль пользователя и данные о сущности из UserActivity
        SELECT u.RoleID, ua.EntityType, ua.EntityID
        INTO v_role_id, v_entity_type, v_entity_id
        FROM Users u
        JOIN UserActivity ua ON ua.ID = p_activity_id
        WHERE u.UserID = p_user_id;

        -- Админ — доступ без ограничений
        IF v_role_id = enums_pkg.get_role_id('Admin') THEN
            RETURN;
        END IF;

        -- Определяем владельца объекта в зависимости от типа сущности
        IF v_entity_type = v_game_entity_id THEN
            -- Game: владелец - DeveloperID
            SELECT DeveloperID INTO v_owner_user_id
            FROM Games
            WHERE GameID = v_entity_id;
            
        ELSIF v_entity_type = v_offer_entity_id THEN
            -- Offer: владелец - developerId через GamePages
            SELECT gp.developerId INTO v_owner_user_id
            FROM Offers o
            JOIN GamePages gp ON gp.PageID = o.PageID
            WHERE o.OfferId = v_entity_id;
            
        ELSIF v_entity_type = v_gamepage_entity_id THEN
            -- GamePage: владелец - developerId
            SELECT developerId INTO v_owner_user_id
            FROM GamePages
            WHERE PageID = v_entity_id;
            
        ELSIF v_entity_type = v_user_entity_id THEN
            -- User: EntityID сам является UserID владельца
            v_owner_user_id := v_entity_id;
            
        ELSE
            RAISE_APPLICATION_ERROR(-20013, 'Unknown entity type');
        END IF;

        -- Не админ: доступ только к объектам, которыми владеет пользователь
        IF v_owner_user_id != p_user_id THEN
            RAISE_APPLICATION_ERROR(
                -20011,
                'Access denied: you can access only activity on your own objects'
            );
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20012, 'User, Activity record or Entity not found');
    END check_useractivity_access;
    
    
    PROCEDURE get_user_statistics(
        p_user_id      IN NUMBER,
        p_target_user_id IN NUMBER,
        p_result       OUT CLOB
    ) IS
        v_activities_json CLOB := '[]';
        v_statistics_json CLOB := '{}';
        v_activity_count NUMBER := 0;
        v_cursor SYS_REFCURSOR;
        v_activity_id NUMBER;
        v_action_type_name VARCHAR2(125);
        v_entity_type_name VARCHAR2(125);
        v_entity_id NUMBER;
        v_created_at TIMESTAMP WITH TIME ZONE;
        v_details NVARCHAR2(255);
        v_action_type_id NUMBER;
        v_entity_type_id NUMBER;
        v_json_item CLOB;
        v_first_item BOOLEAN := TRUE;
        -- Для статистики используем коллекцию
        TYPE t_action_stats IS TABLE OF NUMBER INDEX BY VARCHAR2(125);
        v_action_stats t_action_stats;
        v_action_key VARCHAR2(125);
    BEGIN
        -- Проверяем существование целевого пользователя
        BEGIN
            SELECT UserID INTO v_activity_id
            FROM Users
            WHERE UserID = p_target_user_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20014, 'Target user not found');
        END;

        -- Открываем курсор для всех записей активности целевого пользователя
        OPEN v_cursor FOR
            SELECT 
                ua.ID,
                at.Type AS ActionTypeName,
                et.EntityName AS EntityTypeName,
                ua.EntityID,
                ua.CreatedAt,
                ua.Details,
                ua.ActionType,
                ua.EntityType
            FROM UserActivity ua
            JOIN ActionTypes at ON at.ActionType = ua.ActionType
            JOIN EntityTypes et ON et.TypeID = ua.EntityType
            WHERE ua.UserID = p_target_user_id
            ORDER BY ua.CreatedAt DESC;

        -- Собираем доступные записи активности и статистику
        v_activities_json := '[';
        LOOP
            FETCH v_cursor INTO 
                v_activity_id, 
                v_action_type_name, 
                v_entity_type_name,
                v_entity_id,
                v_created_at,
                v_details,
                v_action_type_id,
                v_entity_type_id;
            EXIT WHEN v_cursor%NOTFOUND;

            -- Проверяем доступ к этой записи активности
            BEGIN
                check_useractivity_access(p_user_id, v_activity_id);
                
                -- Если доступ разрешен, добавляем запись в JSON
                IF NOT v_first_item THEN
                    DBMS_LOB.APPEND(v_activities_json, ',');
                END IF;
                v_first_item := FALSE;
                
                -- Формируем JSON вручную с явным преобразованием в CLOB
                v_json_item := TO_CLOB('{') ||
                    TO_CLOB('"id":') || TO_CLOB(TO_CHAR(v_activity_id)) ||
                    TO_CLOB(',"actionType":"') || TO_CLOB(REPLACE(REPLACE(v_action_type_name, '\', '\\'), '"', '\"')) || TO_CLOB('"') ||
                    TO_CLOB(',"actionTypeId":') || TO_CLOB(TO_CHAR(v_action_type_id)) ||
                    TO_CLOB(',"entityType":"') || TO_CLOB(REPLACE(REPLACE(v_entity_type_name, '\', '\\'), '"', '\"')) || TO_CLOB('"') ||
                    TO_CLOB(',"entityTypeId":') || TO_CLOB(TO_CHAR(v_entity_type_id)) ||
                    TO_CLOB(',"entityId":') || TO_CLOB(TO_CHAR(v_entity_id)) ||
                    TO_CLOB(',"createdAt":"') || TO_CLOB(TO_CHAR(v_created_at, 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"')) || TO_CLOB('"') ||
                    TO_CLOB(',"details":') || 
                    CASE WHEN v_details IS NULL THEN TO_CLOB('null')
                         ELSE TO_CLOB('"') || TO_CLOB(REPLACE(REPLACE(REPLACE(v_details, '\', '\\'), '"', '\"'), CHR(10), '\n')) || TO_CLOB('"')
                    END ||
                    TO_CLOB('}');
                
                -- Используем DBMS_LOB.APPEND для безопасной конкатенации CLOB
                DBMS_LOB.APPEND(v_activities_json, v_json_item);
                v_activity_count := v_activity_count + 1;
                
                -- Обновляем статистику по типам действий
                IF v_action_stats.EXISTS(v_action_type_name) THEN
                    v_action_stats(v_action_type_name) := v_action_stats(v_action_type_name) + 1;
                ELSE
                    v_action_stats(v_action_type_name) := 1;
                END IF;
                
            EXCEPTION
                WHEN OTHERS THEN
                    -- Пропускаем записи, к которым нет доступа
                    NULL;
            END;
        END LOOP;
        CLOSE v_cursor;
        
        -- Закрываем массив (если не было записей, получится '[]')
        DBMS_LOB.APPEND(v_activities_json, ']');

        -- Формируем JSON статистики из коллекции
        IF v_action_stats.COUNT > 0 THEN
            v_statistics_json := '{';
            v_first_item := TRUE;
            v_action_key := v_action_stats.FIRST;
            WHILE v_action_key IS NOT NULL LOOP
                IF NOT v_first_item THEN
                    DBMS_LOB.APPEND(v_statistics_json, ',');
                END IF;
                v_first_item := FALSE;
                -- Используем DBMS_LOB.APPEND для безопасной конкатенации CLOB
                DBMS_LOB.APPEND(v_statistics_json, 
                    '"' || REPLACE(v_action_key, '"', '\"') || '":' || TO_CHAR(v_action_stats(v_action_key)));
                v_action_key := v_action_stats.NEXT(v_action_key);
            END LOOP;
            DBMS_LOB.APPEND(v_statistics_json, '}');
        ELSE
            v_statistics_json := '{}';
        END IF;

        -- Формируем финальный результат
        -- Используем ручное формирование JSON, так как JSON_QUERY не работает внутри JSON_OBJECT
        p_result := '{' ||
            '"userId":' || p_target_user_id || ',' ||
            '"totalActions":' || v_activity_count || ',' ||
            '"activities":' || v_activities_json || ',' ||
            '"statistics":' || v_statistics_json ||
            '}';

    EXCEPTION
        WHEN OTHERS THEN
            IF v_cursor%ISOPEN THEN
                CLOSE v_cursor;
            END IF;
            RAISE;
    END get_user_statistics;
    
    
    PROCEDURE get_games_statistics(
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
        v_limit NUMBER;
        v_download_action_id NUMBER := enums_pkg.get_action_type_id('Download');
        v_purchase_action_id NUMBER := enums_pkg.get_action_type_id('Purchase');
        v_offer_entity_id NUMBER := enums_pkg.get_entity_type_id('Offer');
    BEGIN
        -- Устанавливаем лимит (если передан 0 или NULL, то без ограничений)
        IF p_limit IS NULL OR p_limit <= 0 THEN
            v_limit := NULL;
        ELSE
            v_limit := p_limit;
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

        -- Открываем курсор в зависимости от роли
        IF v_role_name = 'Admin' THEN
            -- Админ: топ 100 игр по всей системе
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
                    WHERE g.DeveloperID = p_user_id
                    AND (NVL(downloads.download_count, 0) + NVL(purchases.purchase_count, 0) > 0)
                    ORDER BY total_count DESC, g.GameID
                );
        END IF;

        -- Собираем результаты в JSON
        v_games_json := '[';
        DECLARE
            v_count NUMBER := 0;
        BEGIN
            LOOP
                -- Проверяем лимит перед FETCH
                IF v_limit IS NOT NULL AND v_count >= v_limit THEN
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

            -- Формируем JSON вручную с явным преобразованием в CLOB
            v_json_item := TO_CLOB('{') ||
                TO_CLOB('"gameId":') || TO_CLOB(TO_CHAR(v_game_id)) ||
                TO_CLOB(',"gameName":"') || TO_CLOB(REPLACE(REPLACE(v_game_name, '\', '\\'), '"', '\"')) || TO_CLOB('"') ||
                TO_CLOB(',"developerId":') || TO_CLOB(TO_CHAR(v_developer_id)) ||
                TO_CLOB(',"downloads":') || TO_CLOB(TO_CHAR(v_downloads_count)) ||
                TO_CLOB(',"purchases":') || TO_CLOB(TO_CHAR(v_purchases_count)) ||
                TO_CLOB(',"total":') || TO_CLOB(TO_CHAR(v_total_count)) ||
                TO_CLOB('}');

                DBMS_LOB.APPEND(v_games_json, v_json_item);
            END LOOP;
        END;
        CLOSE v_cursor;

        v_games_json := v_games_json || ']';

        -- Формируем финальный результат
        p_result := '{' ||
            '"role":"' || REPLACE(v_role_name, '"', '\"') || '",' ||
            '"userId":' || p_user_id || ',' ||
            '"games":' || v_games_json ||
            '}';

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20016, 'User not found');
        WHEN OTHERS THEN
            IF v_cursor%ISOPEN THEN
                CLOSE v_cursor;
            END IF;
            RAISE;
    END get_games_statistics;
    
    
    PROCEDURE get_top_genres_by_countries(
        p_limit        IN NUMBER DEFAULT 10,
        p_result       OUT CLOB
    ) IS
        v_countries_json CLOB := '[]';
        v_cursor SYS_REFCURSOR;
        v_country NVARCHAR2(255);
        v_genre_id NUMBER;
        v_genre_name NVARCHAR2(255);
        v_action_count NUMBER;
        v_json_item CLOB;
        v_country_json CLOB;
        v_first_country BOOLEAN := TRUE;
        v_first_genre BOOLEAN := TRUE;
        v_current_country NVARCHAR2(255);
        v_genres_json CLOB;
        v_download_action_id NUMBER := enums_pkg.get_action_type_id('Download');
        v_purchase_action_id NUMBER := enums_pkg.get_action_type_id('Purchase');
        v_offer_entity_id NUMBER := enums_pkg.get_entity_type_id('Offer');
        v_limit_count NUMBER;
    BEGIN
        -- Устанавливаем лимит
        IF p_limit IS NULL OR p_limit <= 0 THEN
            v_limit_count := NULL;
        ELSE
            v_limit_count := p_limit;
        END IF;

        -- Открываем курсор для статистики по странам и жанрам
        OPEN v_cursor FOR
            SELECT * FROM (
                SELECT 
                    u.Country,
                    gen.genreId,
                    gen.genre,
                    COUNT(*) AS action_count
                FROM UserActivity ua
                JOIN Users u ON u.UserID = ua.UserID
                JOIN OfferGameLinks ogl ON ogl.OfferId = ua.EntityID
                JOIN Games_ganers gg ON gg.GameID = ogl.GameID
                JOIN Geners gen ON gen.genreId = gg.Ganer_ID
                WHERE ua.ActionType IN (v_download_action_id, v_purchase_action_id)
                AND ua.EntityType = v_offer_entity_id
                AND u.Country IS NOT NULL
                GROUP BY u.Country, gen.genreId, gen.genre
                ORDER BY u.Country, action_count DESC, gen.genre
            );

        -- Собираем результаты в JSON, группируя по странам
        v_countries_json := '[';
        v_current_country := NULL;
        v_genres_json := '[';

        DECLARE
            v_count NUMBER := 0;
        BEGIN
            LOOP
                FETCH v_cursor INTO 
                    v_country,
                    v_genre_id,
                    v_genre_name,
                    v_action_count;
                EXIT WHEN v_cursor%NOTFOUND;

                -- Если сменилась страна, закрываем предыдущую и начинаем новую
                IF v_current_country IS NOT NULL AND v_current_country != v_country THEN
                    -- Закрываем массив жанров предыдущей страны
                    v_genres_json := v_genres_json || ']';
                    
                    -- Добавляем страну в результат
                    IF NOT v_first_country THEN
                        v_countries_json := v_countries_json || ',';
                    END IF;
                    v_first_country := FALSE;

                    -- Формируем JSON для страны вручную
                    v_country_json := '{' ||
                        '"country":"' || REPLACE(v_current_country, '"', '\"') || '",' ||
                        '"genres":' || v_genres_json ||
                        '}';
                    v_countries_json := v_countries_json || v_country_json;

                    -- Начинаем новую страну
                    v_current_country := v_country;
                    v_genres_json := '[';
                    v_first_genre := TRUE;
                    v_count := 0;
                ELSIF v_current_country IS NULL THEN
                    -- Первая страна
                    v_current_country := v_country;
                END IF;

                -- Проверяем лимит жанров для текущей страны
                IF v_limit_count IS NULL OR v_count < v_limit_count THEN
                    -- Добавляем жанр
                    IF NOT v_first_genre THEN
                        v_genres_json := v_genres_json || ',';
                    END IF;
                    v_first_genre := FALSE;

                    -- Формируем JSON вручную с явным преобразованием в CLOB
                    v_json_item := TO_CLOB('{') ||
                        TO_CLOB('"genreId":') || TO_CLOB(TO_CHAR(v_genre_id)) ||
                        TO_CLOB(',"genreName":"') || TO_CLOB(REPLACE(REPLACE(v_genre_name, '\', '\\'), '"', '\"')) || TO_CLOB('"') ||
                        TO_CLOB(',"actionCount":') || TO_CLOB(TO_CHAR(v_action_count)) ||
                        TO_CLOB('}');

                    DBMS_LOB.APPEND(v_genres_json, v_json_item);
                    v_count := v_count + 1;
                END IF;
            END LOOP;

            -- Закрываем последнюю страну
            IF v_current_country IS NOT NULL THEN
                v_genres_json := v_genres_json || ']';
                
                IF NOT v_first_country THEN
                    v_countries_json := v_countries_json || ',';
                END IF;

                -- Формируем JSON для страны вручную
                v_country_json := '{' ||
                    '"country":"' || REPLACE(v_current_country, '"', '\"') || '",' ||
                    '"genres":' || v_genres_json ||
                    '}';
                v_countries_json := v_countries_json || v_country_json;
            END IF;
        END;

        CLOSE v_cursor;
        v_countries_json := v_countries_json || ']';

        -- Формируем финальный результат
        p_result := '{' ||
            '"limit":' || NVL(v_limit_count, 0) || ',' ||
            '"countries":' || v_countries_json ||
            '}';

    EXCEPTION
        WHEN OTHERS THEN
            IF v_cursor%ISOPEN THEN
                CLOSE v_cursor;
            END IF;
            RAISE;
    END get_top_genres_by_countries;
    
PROCEDURE get_top_games_by_followers(
    p_user_id      IN NUMBER,
    p_limit        IN NUMBER DEFAULT 100,
    p_result       OUT CLOB
) IS
    v_admin_role_id   NUMBER;
    v_user_role_id    NUMBER;
    v_admin_flag      NUMBER := 0;
    v_first_item      BOOLEAN := TRUE;
    v_buffer          VARCHAR2(32767);
BEGIN
    -- 1. Определяем роль пользователя
    -- Используем твой пакет enums_pkg
    v_admin_role_id := enums_pkg.get_role_id(N'Admin');
    
    SELECT RoleID INTO v_user_role_id 
    FROM Users 
    WHERE UserID = p_user_id;

    IF v_user_role_id = v_admin_role_id THEN
        v_admin_flag := 1;
    END IF;

    -- 2. Инициализируем CLOB
    DBMS_LOB.CREATETEMPORARY(p_result, TRUE);
    v_buffer := '{"games":[';
    DBMS_LOB.WRITEAPPEND(p_result, LENGTH(v_buffer), v_buffer);

    -- 3. Читаем готовые данные из твоего VIEW
    FOR r IN (
        SELECT * FROM (
            SELECT 
                GameID,
                GameName,
                followers_count,
                avg_rating,
                DeveloperID
            FROM V_GAMES_STATISTICS
            WHERE (v_admin_flag = 1 OR DeveloperID = p_user_id)
            ORDER BY followers_count DESC, avg_rating DESC
        )
        WHERE ROWNUM <= p_limit
    ) LOOP
        IF NOT v_first_item THEN
            DBMS_LOB.WRITEAPPEND(p_result, 1, ',');
        END IF;
        v_first_item := FALSE;

        -- Собираем строку JSON из колонок вьюхи
        v_buffer := '{"id":' || r.GameID || 
                    ',"name":"' || REPLACE(r.GameName, '"', '\"') || '"' ||
                    ',"followers":' || r.followers_count || 
                    ',"rating":' || TO_CHAR(NVL(r.avg_rating, 0), 'FM990.99') || '}';
        
        DBMS_LOB.WRITEAPPEND(p_result, LENGTH(v_buffer), v_buffer);
    END LOOP;

    -- 4. Закрываем JSON
    v_buffer := ']}';
    DBMS_LOB.WRITEAPPEND(p_result, LENGTH(v_buffer), v_buffer);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_result := '{"error":"Пользователь не найден"}';
    WHEN OTHERS THEN
        IF DBMS_LOB.ISTEMPORARY(p_result) = 1 THEN
            DBMS_LOB.FREETEMPORARY(p_result);
        END IF;
        p_result := '{"error":"' || REPLACE(SQLERRM, '"', '''') || '"}';
END get_top_games_by_followers;
end  stat_pkg;
/

GRANT EXECUTE ON app_user.stat_pkg TO DEVELOPER;
GRANT EXECUTE ON app_user.stat_pkg TO ADMIN;