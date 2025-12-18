ALTER SESSION set CONTAINER = KPDB_GAMESTORE;


CREATE OR REPLACE PACKAGE developer_pkg IS


    PROCEDURE get_game_page_reviews(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_output       OUT CLOB
    );

    PROCEDURE create_game_page(
        p_developer_id IN NUMBER,
        p_page_title   IN NVARCHAR2,
        p_status_id    IN NUMBER,
        p_view_link    IN VARCHAR2,
        p_output       OUT CLOB
    );

    PROCEDURE update_game_page(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_page_title   IN NVARCHAR2,
        p_status_id    IN NUMBER,
        p_view_link    IN VARCHAR2,
        p_output       OUT CLOB
    );

    PROCEDURE delete_game_page(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_output       OUT CLOB
    );

    PROCEDURE get_offers_by_page(
        p_developer_id IN NUMBER, 
        p_page_id      IN NUMBER,
        p_output       OUT CLOB
    );

    PROCEDURE delete_offer(
        p_developer_id IN NUMBER,
        p_offer_id     IN NUMBER,
        p_output       OUT CLOB
    );

    PROCEDURE update_offer(
        p_developer_id IN NUMBER,
        p_offer_id     IN NUMBER,
        p_title        IN NVARCHAR2,
        p_description  IN NVARCHAR2,
        p_price        IN NUMBER,
        p_currency     IN NVARCHAR2,
        p_game_ids     IN SYS.ODCINUMBERLIST,
        p_output       OUT CLOB
    );


    PROCEDURE add_offer(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_title        IN NVARCHAR2,
        p_description  IN NVARCHAR2,
        p_price        IN NUMBER,
        p_currency     IN NVARCHAR2,
        p_game_ids     IN SYS.ODCINUMBERLIST,
        p_output       OUT CLOB
    );

    PROCEDURE delete_all_screenshots(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_output       OUT CLOB
    );

    PROCEDURE delete_screenshot(
        p_developer_id IN NUMBER,
        p_screenshot_id IN NUMBER,
        p_output       OUT CLOB
    );

    PROCEDURE add_screenshot(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_screenshot   IN VARCHAR2, 
        p_output       OUT CLOB
    );
    
    PROCEDURE add_screenshots_list(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_screenshots  IN SYS.ODCIVARCHAR2LIST,
        p_output       OUT CLOB
    );
    

    PROCEDURE check_developer_role(
        p_user_id IN NUMBER
    );

    PROCEDURE get_all_games(
        p_developer_id IN NUMBER,
        p_output       OUT CLOB
    );

    PROCEDURE add_game(
        p_developer_id IN NUMBER,
        p_game_name    IN NVARCHAR2,
        p_download_link IN VARCHAR2,
        p_game_size    IN NUMBER,
        p_version      IN VARCHAR2,
        p_type         IN NVARCHAR2,
        p_output       OUT CLOB
    );

    PROCEDURE update_game(
        p_developer_id  IN NUMBER,
        p_game_id       IN NUMBER,
        p_game_name     IN NVARCHAR2,
        p_download_link IN VARCHAR2,
        p_game_size     IN NUMBER,   
        p_version       IN NVARCHAR2,
        p_type          IN NVARCHAR2,
        p_output        OUT CLOB
    );
    
    PROCEDURE add_game_genre(
        p_developer_id IN NUMBER,
        p_game_id      IN NUMBER,
        p_genre_name   IN NVARCHAR2,
        p_output       OUT CLOB
    );
    
    PROCEDURE remove_game_genre_by_name(
        p_developer_id IN NUMBER,
        p_game_id      IN NUMBER,
        p_genre_name   IN NVARCHAR2,
        p_output       OUT CLOB
    );
    
    PROCEDURE get_game_page_details(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_output       OUT CLOB
    );
    
END developer_pkg;
/

CREATE OR REPLACE PACKAGE BODY developer_pkg IS

    PROCEDURE get_game_page_details(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_output       OUT CLOB
    ) IS
        v_owner_check NUMBER;
    BEGIN

        BEGIN
            SELECT developerId INTO v_owner_check
            FROM GamePages
            WHERE PageID = p_page_id;
    
            IF v_owner_check != p_developer_id THEN
                p_output := '{"status":"error","message":"Access denied. You are not the owner of this page."}';
                RETURN;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_output := '{"status":"error","message":"Game page not found."}';
                RETURN;
        END;
    

        SELECT JSON_OBJECT(
            'status' VALUE 'success',
            'page_data' VALUE (
                SELECT JSON_OBJECT(
                    'page_id'    VALUE gp.PageID,
                    'title'      VALUE gp.PageTittle,
                    'view_link'  VALUE gp.ViewLink,
                    'status_id'  VALUE gp.Status,
                    'screenshots' VALUE (
                        SELECT JSON_ARRAYAGG(
                            JSON_OBJECT('id' VALUE s.id, 'link' VALUE s.screenshotLink)
                        )
                        FROM Screenshots s WHERE s.GamePageID = gp.PageID
                    ),

                    'offers' VALUE (
                        SELECT JSON_ARRAYAGG(
                            JSON_OBJECT(
                                'offer_id'    VALUE o.OfferId,
                                'title'       VALUE o.Tittle,
                                'description' VALUE o.Description,
                                'price'       VALUE o.Price,
                                'currency'    VALUE o.Currency,
                                'included_games' VALUE (
                                    SELECT JSON_ARRAYAGG(
                                        JSON_OBJECT(
                                            'game_id'   VALUE g.GameID,
                                            'name'      VALUE g.GameName,
                                            'version'   VALUE g.Version,
                                            'size'      VALUE g.GameSize,
                                            -- Жанры конкретной игры
                                            'genres'    VALUE (
                                                SELECT JSON_ARRAYAGG(gn.genre)
                                                FROM Games_ganers gg
                                                JOIN Geners gn ON gg.Ganer_ID = gn.genreId
                                                WHERE gg.GameID = g.GameID
                                            )
                                        )
                                    )
                                    FROM OfferGameLinks ogl
                                    JOIN Games g ON ogl.GameID = g.GameID
                                    WHERE ogl.OfferId = o.OfferId
                                )
                            )
                        )
                        FROM Offers o WHERE o.PageID = gp.PageID
                    )
                )
                FROM GamePages gp
                WHERE gp.PageID = p_page_id
            )
        )
        INTO p_output
        FROM DUAL;
    
    EXCEPTION
        WHEN OTHERS THEN
            p_output := '{"status":"error","message":"' || REPLACE(SQLERRM, '"', '\"') || '"}';
    END get_game_page_details;



PROCEDURE get_game_page_reviews(
    p_developer_id IN NUMBER,
    p_page_id      IN NUMBER,
    p_output       OUT CLOB
) IS
    v_owner_id      NUMBER;
    v_avg_rating    NUMBER(3,2);
    v_total_reviews NUMBER;
BEGIN
    -- 1. Проверка прав собственности
    BEGIN
        SELECT developerId INTO v_owner_id
        FROM GamePages
        WHERE PageID = p_page_id;

        IF v_owner_id != p_developer_id THEN
            p_output := '{"status":"error","message":"Access denied. This is not your game page."}';
            RETURN;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"error","message":"Game page not found."}';
            RETURN;
    END;

    -- 2. Расчет общей статистики
    SELECT 
        NVL(AVG(Rating), 0), 
        COUNT(*)
    INTO 
        v_avg_rating, 
        v_total_reviews
    FROM Folowers
    WHERE GamePageId = p_page_id;

    -- 3. Формирование JSON с отзывами
    SELECT JSON_OBJECT(
        'status'         VALUE 'success',
        'page_id'        VALUE p_page_id,
        'average_rating' VALUE v_avg_rating,
        'total_reviews'  VALUE v_total_reviews,
        'reviews'        VALUE (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'user_id'  VALUE f.UserId,
                    'nickname' VALUE u.NickName,
                    'rating'   VALUE f.Rating,
                    'comment'  VALUE f.ReviewComment,
                    'avatar'   VALUE u.Avatar_uri
                ) ORDER BY f.Rating DESC
            )
            FROM Folowers f
            JOIN Users u ON f.UserId = u.UserID
            WHERE f.GamePageId = p_page_id
        )
    )
    INTO p_output
    FROM DUAL;

EXCEPTION
    WHEN OTHERS THEN
        p_output := '{"status":"error","message":"DB error: ' || REPLACE(SQLERRM, '"', '\"') || '"}';
END get_game_page_reviews;


PROCEDURE remove_game_genre_by_name(
    p_developer_id IN NUMBER,
    p_game_id      IN NUMBER,
    p_genre_name   IN NVARCHAR2,
    p_output       OUT CLOB
) IS
    v_owner    NUMBER;
    v_genre_id NUMBER;
BEGIN
    
    check_developer_role(p_developer_id);

    BEGIN
        SELECT DeveloperID INTO v_owner 
        FROM Games 
        WHERE GameID = p_game_id;
        
        IF v_owner != p_developer_id THEN
            p_output := '{"status":"error","message":"You can only modify your own games"}';
            RETURN;
        END IF;
    EXCEPTION 
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"error","message":"Game not found"}';
            RETURN;
    END;

    BEGIN
        SELECT genreId INTO v_genre_id 
        FROM Geners 
        WHERE LOWER(genre) = LOWER(p_genre_name);
    EXCEPTION 
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"error","message":"Genre name not found in database"}';
            RETURN;
    END;

    DELETE FROM Games_ganers 
    WHERE GameID = p_game_id 
      AND Ganer_ID = v_genre_id;

    IF SQL%ROWCOUNT > 0 THEN
        p_output := '{"status":"success","message":"Genre ''' || p_genre_name || ''' removed from game"}';
        COMMIT;
    ELSE
        p_output := '{"status":"error","message":"This game does not have the specified genre"}';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_output := '{"status":"error","message":"Internal error: ' || REPLACE(SQLERRM, '"', '\"') || '"}';
END remove_game_genre_by_name;

    PROCEDURE add_game_genre(
        p_developer_id IN NUMBER,
        p_game_id      IN NUMBER,
        p_genre_name   IN NVARCHAR2,
        p_output       OUT CLOB
    ) IS
        v_genre_id NUMBER;
        v_owner    NUMBER;
BEGIN
    
    check_developer_role(p_developer_id);
    BEGIN
        SELECT DeveloperID INTO v_owner FROM Games WHERE GameID = p_game_id;
        IF v_owner != p_developer_id THEN
            p_output := '{"status":"error","message":"Not your game"}';
            RETURN;
        END IF;
    EXCEPTION WHEN NO_DATA_FOUND THEN
        p_output := '{"status":"error","message":"Game not found"}';
        RETURN;
    END;


    BEGIN
        SELECT genreId INTO v_genre_id 
        FROM Geners 
        WHERE LOWER(genre) = LOWER(p_genre_name);
    EXCEPTION WHEN NO_DATA_FOUND THEN
        INSERT INTO Geners (genre) VALUES (p_genre_name)
        RETURNING genreId INTO v_genre_id;
    END;

    BEGIN
        INSERT INTO Games_ganers (GameID, Ganer_ID)
        VALUES (p_game_id, v_genre_id);
    EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
        p_output := '{"status":"success","message":"Genre already linked","genre_id":' || v_genre_id || '}';
        RETURN;
    END;

    p_output := '{"status":"success","message":"Genre added","genre_id":' || v_genre_id || '}';
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_output := '{"status":"error","message":"' || REPLACE(SQLERRM, '"', '\"') || '"}';
END add_game_genre;



   PROCEDURE delete_game_page(
    p_developer_id IN NUMBER,
    p_page_id      IN NUMBER,
    p_output       OUT CLOB
) IS
    v_exists NUMBER;
BEGIN
    -- 1. Проверка существования и прав собственности
    SELECT COUNT(*) INTO v_exists
    FROM GamePages
    WHERE PageID = p_page_id AND developerId = p_developer_id;

    IF v_exists = 0 THEN
        p_output := '{"status":"error","message":"Page not found or access denied"}';
        RETURN;
    END IF;
    

    DELETE FROM Reports WHERE ReportTo_GamePageID = p_page_id;


    DELETE FROM Screenshots WHERE GamePageID = p_page_id;


    DELETE FROM Folowers WHERE GamePageId = p_page_id;


    DELETE FROM OfferGameLinks 
    WHERE OfferId IN (SELECT OfferId FROM Offers WHERE PageID = p_page_id);


    DELETE FROM Transactions 
    WHERE OfferID IN (SELECT OfferId FROM Offers WHERE PageID = p_page_id);


    DELETE FROM Offers WHERE PageID = p_page_id;


    DELETE FROM GamePages WHERE PageID = p_page_id;

    COMMIT;
    p_output := '{"status":"success","message":"Game page and all related data deleted"}';

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_output := '{"status":"error","message":"DB Error: ' || REPLACE(SQLERRM, '"', '''') || '"}';
END delete_game_page;
    


    PROCEDURE update_game_page(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_page_title   IN NVARCHAR2,
        p_status_id    IN NUMBER,
        p_view_link    IN VARCHAR2,
        p_output       OUT CLOB
    ) IS
        v_count NUMBER;
    BEGIN
        p_output := '';
        
        check_developer_role(p_developer_id);
        
        SELECT COUNT(*) INTO v_count
        FROM GamePages
        WHERE PageID = p_page_id
          AND developerId = p_developer_id;

        IF v_count = 0 THEN
            p_output := '{"status":"error","message":"Page not found or access denied"}';
            RETURN;
        END IF;

        UPDATE GamePages
        SET PageTittle = p_page_title,
            Status  = p_status_id,
            ViewLink  = p_view_link
        WHERE PageID = p_page_id;

        p_output := '{"status":"success","message":"Game page updated"}';

    EXCEPTION
        WHEN OTHERS THEN
            p_output := '{"status":"error","message":"' || REPLACE(SQLERRM,'"','''') || '"}';
    END update_game_page;



PROCEDURE get_offers_by_page(
    p_developer_id IN NUMBER, 
    p_page_id      IN NUMBER,
    p_output       OUT CLOB
) IS
    v_json   CLOB := '[';
    v_first  BOOLEAN := TRUE;
    v_owner  NUMBER;
BEGIN
    -- 1. Проверка прав собственности
    BEGIN
        SELECT developerId INTO v_owner 
        FROM GamePages 
        WHERE PageID = p_page_id;
        
        IF v_owner != p_developer_id THEN
            p_output := '{"status":"ERROR","message":"Access denied. Not your page."}';
            RETURN;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"ERROR","message":"Page not found."}';
            RETURN;
    END;

    -- 2. Сбор данных об офферах
    FOR rec IN (
        SELECT o.OfferId, o.Tittle, o.Description, o.Price, o.Currency,
               LISTAGG(g.GameName, ',') WITHIN GROUP (ORDER BY g.GameName) AS Games
        FROM Offers o
        LEFT JOIN OfferGameLinks ogl ON o.OfferId = ogl.OfferId
        LEFT JOIN Games g ON ogl.GameID = g.GameID
        WHERE o.PageID = p_page_id
        GROUP BY o.OfferId, o.Tittle, o.Description, o.Price, o.Currency
        ORDER BY o.OfferId
    ) LOOP
        IF NOT v_first THEN
            v_json := v_json || ',';
        END IF;
        v_first := FALSE;

        v_json := v_json || '{"offer_id":' || rec.OfferId ||
                  ',"title":"' || REPLACE(rec.Tittle, '"', '\"') || '"' ||
                  ',"description":"' || REPLACE(rec.Description, '"', '\"') || '"' ||
                  ',"price":' || rec.Price ||
                  ',"currency":"' || rec.Currency || '"' ||
                  ',"games":[' || 
                  CASE 
                    WHEN rec.Games IS NOT NULL THEN '"' || REPLACE(rec.Games, ',', '","') || '"' 
                    ELSE '' 
                  END || ']}';
    END LOOP;

    v_json := v_json || ']';
    p_output := v_json;

EXCEPTION
    WHEN OTHERS THEN
        p_output := '{"status":"ERROR","message":"DB error: ' || REPLACE(SQLERRM, '"', '\"') || '"}';
END get_offers_by_page;


    PROCEDURE delete_all_screenshots(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_output       OUT CLOB
    ) IS
        v_dummy NUMBER;
    BEGIN
        -- Проверяем права разработчика
        SELECT 1 INTO v_dummy
        FROM GamePages
        WHERE PageID = p_page_id
          AND DeveloperId = p_developer_id;

        -- Удаляем все скриншоты
        DELETE FROM Screenshots
        WHERE GamePageID = p_page_id;

        p_output := '{"status":"OK","message":"All screenshots deleted successfully"}';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"ERROR","message":"Page not found or access denied"}';
        WHEN OTHERS THEN
            p_output := '{"status":"ERROR","message":"DB error: '||SQLERRM||'"}';
    END delete_all_screenshots;
    
    PROCEDURE delete_offer(
        p_developer_id IN NUMBER,
        p_offer_id     IN NUMBER,
        p_output       OUT CLOB
    ) IS
        v_page_id NUMBER;
    BEGIN
        check_developer_role(p_developer_id);
    
        -- Проверяем принадлежность оффера разработчику
        SELECT o.PageID INTO v_page_id
        FROM Offers o
        JOIN GamePages g ON o.PageID = g.PageID
        WHERE o.OfferId = p_offer_id
          AND g.DeveloperId = p_developer_id;
    
        -- Удаляем связи с играми
        DELETE FROM OfferGameLinks WHERE OfferId = p_offer_id;
    
        -- Удаляем оффер
        DELETE FROM Offers WHERE OfferId = p_offer_id;
    
        p_output := '{"status":"OK","message":"Offer deleted successfully"}';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"ERROR","message":"Offer not found or access denied"}';
        WHEN OTHERS THEN
            p_output := '{"status":"ERROR","message":"DB error: ' || SQLERRM || '"}';
    END delete_offer;
    
    PROCEDURE update_offer(
        p_developer_id IN NUMBER,
        p_offer_id     IN NUMBER,
        p_title        IN NVARCHAR2,
        p_description  IN NVARCHAR2,
        p_price        IN NUMBER,
        p_currency     IN NVARCHAR2,
        p_game_ids     IN SYS.ODCINUMBERLIST,
        p_output       OUT CLOB
    ) IS
        v_page_id NUMBER;
    BEGIN
        check_developer_role(p_developer_id);
    
        -- Явно указываем таблицу для PageID
        SELECT o.PageID INTO v_page_id
        FROM Offers o
        JOIN GamePages g ON o.PageID = g.PageID
        WHERE o.OfferId = p_offer_id
          AND g.DeveloperId = p_developer_id;
    
        -- Обновляем данные оффера
        UPDATE Offers
        SET Tittle = p_title,
            Description = p_description,
            Price = p_price,
            Currency = p_currency
        WHERE OfferId = p_offer_id;
    
        -- Обновляем привязку игр: удаляем старые и вставляем новые
        DELETE FROM OfferGameLinks WHERE OfferId = p_offer_id;
        FOR i IN 1 .. p_game_ids.COUNT LOOP
            INSERT INTO OfferGameLinks(OfferId, GameID)
            VALUES(p_offer_id, p_game_ids(i));
        END LOOP;
    
        p_output := '{"status":"OK","message":"Offer updated successfully"}';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"ERROR","message":"Offer not found or access denied"}';
        WHEN OTHERS THEN
            p_output := '{"status":"ERROR","message":"DB error: ' || SQLERRM || '"}';
    END update_offer;

    PROCEDURE add_offer(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_title        IN NVARCHAR2,
        p_description  IN NVARCHAR2,
        p_price        IN NUMBER,
        p_currency     IN NVARCHAR2,
        p_game_ids     IN SYS.ODCINUMBERLIST,
        p_output       OUT CLOB
    ) IS
        v_offer_id NUMBER;
        v_dummy NUMBER;
    BEGIN
        -- Проверяем права разработчика и страницу
        check_developer_role(p_developer_id);
        SELECT 1 INTO v_dummy
        FROM GamePages
        WHERE PageID = p_page_id
          AND DeveloperId = p_developer_id;

        -- Вставляем оффер
        INSERT INTO Offers(PageID, Tittle, Description, Price, Currency)
        VALUES(p_page_id, p_title, p_description, p_price, p_currency)
        RETURNING OfferId INTO v_offer_id;

        -- Привязка игр к офферу
        FOR i IN 1 .. p_game_ids.COUNT LOOP
            INSERT INTO OfferGameLinks(OfferId, GameID)
            VALUES(v_offer_id, p_game_ids(i));
        END LOOP;

        p_output := '{"status":"OK","message":"Offer created successfully","OfferId":' || v_offer_id || '}';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"ERROR","message":"Page not found or access denied"}';
        WHEN OTHERS THEN
            p_output := '{"status":"ERROR","message":"DB error: ' || SQLERRM || '"}';
    END add_offer;

    PROCEDURE delete_screenshot(
        p_developer_id IN NUMBER,
        p_screenshot_id IN NUMBER,
        p_output       OUT CLOB
    ) IS
        v_page_id NUMBER;
    BEGIN
        -- Получаем PageID для проверки прав
        SELECT GamePageID INTO v_page_id
        FROM Screenshots s
        JOIN GamePages g ON s.GamePageID = g.PageID
        WHERE s.ID = p_screenshot_id
          AND g.DeveloperId = p_developer_id;

        -- Удаляем скриншот
        DELETE FROM Screenshots
        WHERE id = p_screenshot_id;

        p_output := '{"status":"OK","message":"Screenshot deleted successfully"}';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"ERROR","message":"Screenshot not found or access denied"}';
        WHEN OTHERS THEN
            p_output := '{"status":"ERROR","message":"DB error: '||SQLERRM||'"}';
    END delete_screenshot;

    -- Процедура проверки роли 
    PROCEDURE check_developer_role(
        p_user_id IN NUMBER

    ) IS
        p_output  CLOB;
        v_role NVARCHAR2(255);
    BEGIN
        SELECT r.Role
        INTO v_role
        FROM Users u
        JOIN Roles r ON u.RoleID = r.RoleId
        WHERE u.UserID = p_user_id;

        IF v_role != 'Developer' THEN
            p_output := '{"status":"error","message":"User is not a Developer"}';
            RAISE_APPLICATION_ERROR(-20001, p_output);
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"error","message":"User not found"}';
            RAISE_APPLICATION_ERROR(-20002, p_output);
        WHEN OTHERS THEN
            p_output := '{"status":"error","message":"' || SQLERRM || '"}';
            RAISE;
    END check_developer_role;

    PROCEDURE add_screenshots_list(
        p_developer_id IN NUMBER,
        p_page_id      IN NUMBER,
        p_screenshots  IN SYS.ODCIVARCHAR2LIST,
        p_output       OUT CLOB
    ) IS
        v_dummy NUMBER;
    BEGIN
        -- Проверяем, что пользователь является разработчиком страницы
        check_developer_role(p_developer_id);

        -- Проверяем, что страница существует
        SELECT 1 INTO v_dummy
        FROM GamePages
        WHERE PageID = p_page_id
          AND DeveloperId = p_developer_id;

        -- Вставляем скриншоты
        FOR i IN 1 .. p_screenshots.COUNT LOOP
            INSERT INTO Screenshots(GamePageID, ScreenshotLink)
            VALUES(p_page_id, p_screenshots(i));
        END LOOP;

        p_output := '{"status":"OK","message":"Screenshots added successfully"}';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"ERROR","message":"Page not found or access denied"}';
        WHEN OTHERS THEN
            p_output := '{"status":"ERROR","message":"DB error: '||SQLERRM||'"}';
    END add_screenshots_list;
    
PROCEDURE add_screenshot(
    p_developer_id IN NUMBER,
    p_page_id      IN NUMBER,
    p_screenshot   IN VARCHAR2, 
    p_output       OUT CLOB
) IS
    v_owner       NUMBER;
    v_action_type NUMBER := enums_pkg.get_action_type_id('Added'); 
    v_entity_type NUMBER := enums_pkg.get_entity_type_id('GamePage'); 
BEGIN
    -- 1. Проверка роли разработчика
    check_developer_role(p_developer_id);

    -- 2. Проверка существования страницы и прав собственности
    BEGIN
        SELECT developerId INTO v_owner 
        FROM GamePages 
        WHERE PageID = p_page_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"error","message":"Game page not found"}';
            RETURN;
    END;

    IF v_owner != p_developer_id THEN
        p_output := '{"status":"error","message":"You can only add screenshots to your own pages"}';
        RETURN;
    END IF;

    -- 3. Валидация входной ссылки (не пустая)
    IF p_screenshot IS NULL OR LENGTH(TRIM(p_screenshot)) = 0 THEN
        p_output := '{"status":"error","message":"Screenshot link cannot be empty"}';
        RETURN;
    END IF;

    -- 4. Вставка одного скриншота
    INSERT INTO Screenshots(GamePageID, screenshotLink)
    VALUES(p_page_id, p_screenshot);

    -- 5. Логирование активности
    INSERT INTO UserActivity(UserID, ActionType, EntityType, EntityID, Details, CreatedAt)
    VALUES(p_developer_id, v_action_type, v_entity_type, p_page_id, 'Added screenshot', SYSTIMESTAMP);

    p_output := '{"status":"success"}';
    
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_output := '{"status":"error","message":"' || REPLACE(SQLERRM, '"', '\"') || '"}';
END add_screenshot;
    
    
    
    PROCEDURE create_game_page(
        p_developer_id IN NUMBER,
        p_page_title   IN NVARCHAR2,
        p_status_id    IN NUMBER,
        p_view_link    IN VARCHAR2,
        p_output       OUT CLOB
    ) IS
        v_page_id NUMBER;
        v_action_type NUMBER := enums_pkg.get_action_type_id('CreateNew'); 
        v_entity_type NUMBER := enums_pkg.get_entity_type_id('GamePage'); 
    BEGIN
        check_developer_role(p_developer_id);

        INSERT INTO GamePages(developerId, Status, PageTittle, ViewLink)
        VALUES(p_developer_id, p_status_id, p_page_title, p_view_link)
        RETURNING PageID INTO v_page_id;

        INSERT INTO UserActivity(UserID, ActionType, EntityType, EntityID, Details, CreatedAt)
        VALUES(p_developer_id, v_action_type, v_entity_type, v_page_id, 'Created game page', SYSTIMESTAMP);

        p_output := '{"status":"success","page_id":' || v_page_id || '}';
    EXCEPTION
        WHEN OTHERS THEN
            p_output := '{"status":"error","message":"' || SQLERRM || '"}';
            ROLLBACK;
    END create_game_page;
    
    
    PROCEDURE get_all_games(
        p_developer_id IN NUMBER,
        p_output       OUT CLOB
    ) IS
    BEGIN
        -- Проверка роли разработчика
        check_developer_role(p_developer_id);
    

        SELECT JSON_ARRAYAGG(
                   JSON_OBJECT(
                       'game_id'        VALUE g.GameID,
                       'game_name'      VALUE g.GameName,
                       'download_link'  VALUE g.DownloadLink,
                       'game_size'      VALUE g.GameSize,
                       'version'        VALUE g.Version,
                       'type'           VALUE g.type
                   )
               ) 
        INTO p_output
        FROM Games g
        WHERE g.DeveloperID = p_developer_id;
    
        IF p_output IS NULL THEN
            p_output := '[]';
        END IF;
    
    EXCEPTION
        WHEN OTHERS THEN
            p_output := '{"status":"error","message":"' || SQLERRM || '"}';
    END get_all_games;

  PROCEDURE add_game(
    p_developer_id  IN NUMBER,
    p_game_name     IN NVARCHAR2,
    p_download_link IN VARCHAR2,
    p_game_size     IN NUMBER,
    p_version       IN VARCHAR2,
    p_type          IN NVARCHAR2,
    p_output        OUT CLOB
) IS
    v_game_id       NUMBER;
    v_dummy         NUMBER;
    v_action_type   NUMBER := enums_pkg.get_action_type_id('CreateNew'); -- 5
    v_entity_type   NUMBER := enums_pkg.get_entity_type_id('Game');      -- 1
BEGIN
    check_developer_role(p_developer_id);

    BEGIN
        SELECT 1 INTO v_dummy FROM Games WHERE DownloadLink = p_download_link AND ROWNUM = 1;
        p_output := '{"status":"error","message":"This download link is already assigned to another game"}';
        RETURN;
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL; END;

    BEGIN
        SELECT 1 INTO v_dummy FROM Games 
        WHERE DeveloperID = p_developer_id AND GameName = p_game_name AND ROWNUM = 1;
        p_output := '{"status":"error","message":"You already have a game with this name"}';
        RETURN;
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL; END;

    IF p_game_size <= 0 THEN
        p_output := '{"status":"error","message":"Game size must be greater than 0"}';
        RETURN;
    END IF;

    INSERT INTO Games(DeveloperID, GameName, DownloadLink, GameSize, Version, type)
    VALUES(p_developer_id, p_game_name, p_download_link, p_game_size, p_version, p_type)
    RETURNING GameID INTO v_game_id;

    INSERT INTO UserActivity(UserID, ActionType, EntityType, EntityID, Details, CreatedAt)
    VALUES(p_developer_id, v_action_type, v_entity_type, v_game_id, 
           'Added game: ' || p_game_name, SYSTIMESTAMP);

    p_output := '{"status":"success","game_id":' || v_game_id || '}';
    
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_output := '{"status":"error","message":"Internal error: ' || REPLACE(SQLERRM, '"', '\"') || '"}';
END add_game;




PROCEDURE update_game(
    p_developer_id  IN NUMBER,
    p_game_id       IN NUMBER,
    p_game_name     IN NVARCHAR2,
    p_download_link IN VARCHAR2,
    p_game_size     IN NUMBER,    
    p_version       IN NVARCHAR2,
    p_type          IN NVARCHAR2,
    p_output        OUT CLOB
) IS
    v_owner        NUMBER;
    v_link_exists  NUMBER;
    v_name_exists  NUMBER;
    v_action_type  NUMBER := enums_pkg.get_action_type_id('Updated'); 
    v_entity_type  NUMBER := enums_pkg.get_entity_type_id('Game'); 
BEGIN

    check_developer_role(p_developer_id);


    BEGIN
        SELECT DeveloperID INTO v_owner
        FROM Games
        WHERE GameID = p_game_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_output := '{"status":"error","message":"Game not found"}';
            RETURN;
    END;

    IF v_owner != p_developer_id THEN
        p_output := '{"status":"error","message":"You can only update your own games"}';
        RETURN;
    END IF;


    IF p_game_size <= 0 THEN
        p_output := '{"status":"error","message":"Game size must be greater than 0"}';
        RETURN;
    END IF;


    SELECT COUNT(*) INTO v_name_exists 
    FROM Games 
    WHERE GameName = p_game_name 
      AND DeveloperID = p_developer_id
      AND GameID != p_game_id;

    IF v_name_exists > 0 THEN
        p_output := '{"status":"error","message":"You already have another game with this name"}';
        RETURN;
    END IF;


    SELECT COUNT(*) INTO v_link_exists 
    FROM Games 
    WHERE DownloadLink = p_download_link 
      AND GameID != p_game_id;

    IF v_link_exists > 0 THEN
        p_output := '{"status":"error","message":"This download link is already used by another game"}';
        RETURN;
    END IF;


    UPDATE Games
    SET GameName     = p_game_name,
        DownloadLink = p_download_link,
        GameSize     = p_game_size,  
        Version      = p_version,
        type         = p_type
    WHERE GameID = p_game_id;


    INSERT INTO UserActivity(UserID, ActionType, EntityType, EntityID, Details, CreatedAt)
    VALUES(p_developer_id, v_action_type, v_entity_type, p_game_id, 
           'Updated game: ' || p_game_name || ' (Size: ' || p_game_size || 'MB, v' || p_version || ')', 
           SYSTIMESTAMP);

    p_output := '{"status":"success","game_id":' || p_game_id || '}';
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_output := '{"status":"error","message":"Internal error: ' || REPLACE(SQLERRM, '"', '\"') || '"}';
END update_game;

END developer_pkg;
/



GRANT EXECUTE ON app_user.developer_pkg TO DEVELOPER;