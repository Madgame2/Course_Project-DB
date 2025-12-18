ALTER SESSION set CONTAINER = KPDB_GAMESTORE;

CREATE OR REPLACE FUNCTION hash_password(p_password NVARCHAR2)
RETURN VARCHAR2
IS
    v_hash NUMBER;
BEGIN
    v_hash := DBMS_UTILITY.GET_HASH_VALUE(p_password, 1, 999999999);
    RETURN TO_CHAR(v_hash);
END;
/

CREATE OR REPLACE FUNCTION get_screenshots_json(p_page_id NUMBER)
RETURN CLOB IS
    v_clob CLOB := '[]';
BEGIN
    SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'screenshot_id' VALUE id,
                    'link' VALUE screenshotLink
                )
           )
    INTO v_clob
    FROM Screenshots
    WHERE GamePageID = p_page_id;

    RETURN NVL(v_clob, '[]');
END get_screenshots_json;
/

CREATE OR REPLACE FUNCTION get_game_genres_json(p_game_id NUMBER)
RETURN CLOB IS
    v_clob CLOB := '[]';
BEGIN
    SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'genre_id' VALUE g.genreId,
                    'genre' VALUE g.genre
                )
           )
    INTO v_clob
    FROM Games_ganers gg
    JOIN Geners g ON gg.Ganer_ID = g.genreId
    WHERE gg.GameID = p_game_id;

    RETURN NVL(v_clob, '[]');
END get_game_genres_json;
/

CREATE OR REPLACE FUNCTION get_offer_games_json(p_offer_id NUMBER)
RETURN CLOB IS
    v_clob CLOB := '[]';
BEGIN
    SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'game_id' VALUE g.GameID,
                    'name' VALUE g.GameName,
                    'developer_id' VALUE g.DeveloperID,
                    'genres' VALUE get_game_genres_json(g.GameID)
                )
           )
    INTO v_clob
    FROM OfferGameLinks ogl
    JOIN Games g ON ogl.GameID = g.GameID
    WHERE ogl.OfferId = p_offer_id;

    RETURN NVL(v_clob, '[]');
END get_offer_games_json;
/

CREATE OR REPLACE FUNCTION get_offers_json(p_page_id NUMBER)
RETURN CLOB IS
    v_clob CLOB := '[]';
BEGIN
    SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'offer_id' VALUE o.OfferId,
                    'title' VALUE o.Tittle,
                    'description' VALUE o.Description,
                    'price' VALUE o.Price,
                    'currency' VALUE o.Currency,
                    'games' VALUE get_offer_games_json(o.OfferId)
                )
           )
    INTO v_clob
    FROM Offers o
    WHERE o.PageID = p_page_id;

    RETURN NVL(v_clob, '[]');
END get_offers_json;
/


CREATE OR REPLACE PACKAGE user_pkg IS
    
    PROCEDURE get_game_pages_filtered(
        p_developer_id IN NUMBER    DEFAULT NULL,
        p_title_search IN NVARCHAR2 DEFAULT NULL,
        p_genre_id     IN NUMBER    DEFAULT NULL,
        p_order_by     IN NVARCHAR2 DEFAULT 'TITLE', -- 'TITLE' или 'PRICE'
        p_order_dir    IN NVARCHAR2 DEFAULT 'ASC', -- 'ASC' или 'DESC'
        p_response     OUT CLOB
    );
    
    
    PROCEDURE set_game_review(
        p_user_id   IN NUMBER,
        p_game_id   IN NUMBER,
        p_rating    IN NUMBER,   
        p_comment   IN VARCHAR2, 
        p_response  OUT CLOB
    );
        
    
    PROCEDURE download_free_offer(
        p_user_id   IN NUMBER,
        p_offer_id  IN NUMBER,
        p_response  OUT CLOB
    );
    
    PROCEDURE download_library_game(
        p_user_id  IN NUMBER,
        p_game_id  IN NUMBER,
        p_response OUT CLOB
    );

    PROCEDURE get_game_page
    (
        p_page_id   IN NUMBER,
        p_user_id   IN NUMBER,
        p_ip        IN VARCHAR2 DEFAULT NULL,
        p_useragent IN VARCHAR2 DEFAULT NULL,
        p_response  OUT CLOB
    );

    PROCEDURE get_user_library(
        p_user_id IN NUMBER,
        p_response OUT CLOB
    );

    PROCEDURE complete_purchase(
        p_transaction_id IN NUMBER,
        p_response       OUT CLOB
    );


    PROCEDURE purchase_game_pending(
        p_user_id        IN NUMBER,
        p_offer_id       IN NUMBER,
        p_use_balance    IN NUMBER,       -- 1 = использовать баланс, 0 = внешний платёж
        p_payment_method IN NVARCHAR2,    -- если внешний платёж
        p_response       OUT CLOB
    );


    PROCEDURE add_balance_transaction(
        p_user_id IN NUMBER,
        p_amount IN NUMBER,
        p_payment_method IN NVARCHAR2,
        p_response OUT CLOB
    );



    PROCEDURE get_profile(
        p_user_id IN NUMBER,
        p_response OUT CLOB
    );
    
    PROCEDURE update_email(
        p_user_id IN NUMBER,
        p_new_email IN NVARCHAR2,
        p_response OUT CLOB
    );
    
    PROCEDURE update_nickname(
        p_user_id IN NUMBER,
        p_new_nickname IN NVARCHAR2,
        p_response OUT CLOB
    );
    
    PROCEDURE update_password(
        p_user_id IN NUMBER,
        p_old_password IN NVARCHAR2,
        p_new_password IN NVARCHAR2,
        p_response OUT CLOB
    );
    
    PROCEDURE update_profile(
        p_user_id IN NUMBER,
        p_avatar_uri IN NVARCHAR2,
        p_country IN NVARCHAR2,
        p_response OUT CLOB
    );

END user_pkg;
/



CREATE OR REPLACE PACKAGE BODY user_pkg IS

    FUNCTION make_json(p_status VARCHAR2, p_message VARCHAR2) RETURN CLOB IS
        v_clob CLOB;
    BEGIN
        v_clob := '{"status":"' || p_status || '","message":"' || p_message || '"}';
        RETURN v_clob;
    END;
    
    
PROCEDURE get_game_pages_filtered(
    p_developer_id IN NUMBER    DEFAULT NULL,
    p_title_search IN NVARCHAR2 DEFAULT NULL,
    p_genre_id     IN NUMBER    DEFAULT NULL,
    p_order_by     IN NVARCHAR2 DEFAULT 'TITLE', 
    p_order_dir    IN NVARCHAR2 DEFAULT 'ASC', 
    p_response     OUT CLOB
)
IS
    v_json CLOB := '[';
    v_sql  CLOB;

    TYPE page_rec IS RECORD (
        PageID      NUMBER,
        PageTittle  NVARCHAR2(512),
        DeveloperId NUMBER,
        ViewLink    NVARCHAR2(512)
    );

    TYPE offer_rec IS RECORD (
        OfferID  NUMBER,
        Price    NUMBER(10,2),
        Tittle   NVARCHAR2(512),
        Currency NVARCHAR2(6)
    );

    TYPE ref_cursor IS REF CURSOR;
    c_pages  ref_cursor;
    c_offers ref_cursor;

    r_page  page_rec;
    r_offer offer_rec;
    
    v_status_active_id NUMBER;
BEGIN
    -- 1. Находим ID статуса 'Active'
    BEGIN
        SELECT StatusID INTO v_status_active_id 
        FROM GamePagesStatuses 
        WHERE Status = 'Active';
    EXCEPTION WHEN NO_DATA_FOUND THEN
        p_response := '{"status":"error","message":"Системная ошибка: Статус Active не найден в БД"}';
        RETURN;
    END;


    v_sql := 'SELECT DISTINCT v.PageID, v.PageTittle, v.DeveloperId, v.ViewLink
              FROM OfferGamesWithGenres v
              JOIN GamePages gp ON v.PageID = gp.PageID
              WHERE gp.Status = ' || v_status_active_id;

    -- Фильтр по разработчику
    IF p_developer_id IS NOT NULL THEN
        v_sql := v_sql || ' AND v.DeveloperId = ' || p_developer_id;
    END IF;

    -- Фильтр по названию 
    IF p_title_search IS NOT NULL AND p_title_search <> '' THEN
        v_sql := v_sql || ' AND LOWER(v.PageTittle) LIKE ''%' || LOWER(REPLACE(p_title_search, '''', '''''')) || '%''';
    END IF;

    -- Фильтр по жанру
    IF p_genre_id IS NOT NULL THEN
        v_sql := v_sql || ' AND v.Ganer_ID = ' || p_genre_id;
    END IF;

    -- Сортировка (явно указываем v. столбец)
    IF UPPER(p_order_by) = 'PRICE' THEN
        v_sql := v_sql || ' ORDER BY MAX(v.Price)'; 
    ELSE
        v_sql := v_sql || ' ORDER BY v.PageTittle';
    END IF;

    -- Направление сортировки
    IF UPPER(p_order_dir) = 'DESC' THEN
        v_sql := v_sql || ' DESC';
    ELSE
        v_sql := v_sql || ' ASC';
    END IF;

    -- 3. Формирование результирующего JSON
    OPEN c_pages FOR v_sql;
    LOOP
        FETCH c_pages INTO r_page;
        EXIT WHEN c_pages%NOTFOUND;

        -- Начало объекта страницы
        v_json := v_json || '{"PageID":' || r_page.PageID ||
                  ',"PageTittle":"' || REPLACE(r_page.PageTittle, '"', '\"') || '"' ||
                  ',"DeveloperId":' || r_page.DeveloperId ||
                  ',"ViewLink":"' || NVL(r_page.ViewLink, '') || '"' ||
                  ',"Offers":[';

        -- Вложенный курсор для офферов этой страницы
        OPEN c_offers FOR
            'SELECT OfferId, Price, Tittle, Currency
             FROM Offers
             WHERE PageID = :pid' USING r_page.PageID;

        LOOP
            FETCH c_offers INTO r_offer;
            EXIT WHEN c_offers%NOTFOUND;

            v_json := v_json ||
                      '{"OfferID":' || r_offer.OfferID ||
                      ',"Price":' || r_offer.Price ||
                      ',"Tittle":"' || REPLACE(r_offer.Tittle, '"', '\"') || '"' ||
                      ',"Currency":"' || r_offer.Currency || '"},';
        END LOOP;
        CLOSE c_offers;

        -- Удаляем лишнюю запятую после последнего оффера
        IF SUBSTR(v_json, -1, 1) = ',' THEN
            v_json := SUBSTR(v_json, 1, LENGTH(v_json)-1);
        END IF;

        v_json := v_json || ']},';
    END LOOP;
    CLOSE c_pages;

    IF SUBSTR(v_json, -1, 1) = ',' THEN
        v_json := SUBSTR(v_json, 1, LENGTH(v_json)-1);
    END IF;

    v_json := v_json || ']';
    p_response := v_json;

EXCEPTION
    WHEN OTHERS THEN
        IF c_pages%ISOPEN THEN CLOSE c_pages; END IF;
        IF c_offers%ISOPEN THEN CLOSE c_offers; END IF;
        p_response := '{"status":"error","message":"Внутренняя ошибка: ' || REPLACE(SQLERRM, '"', '\"') || '"}';
END;




    
    
    
PROCEDURE set_game_review(
    p_user_id   IN NUMBER,
    p_game_id   IN NUMBER,
    p_rating    IN NUMBER,
    p_comment   IN VARCHAR2,
    p_response  OUT CLOB
) AS
    v_exists  NUMBER := 0;
    v_altered BOOLEAN := FALSE;
BEGIN
    
    IF p_rating < 1 OR p_rating > 5 THEN
        p_response := '{"success":false,"message":"Rating must be between 1 and 5"}';
        RETURN;
    END IF;

    
    DECLARE
        v_check NUMBER;
    BEGIN
        SELECT 1 INTO v_check FROM GamePages WHERE PageID = p_game_id;
        SELECT 1 INTO v_check FROM Users WHERE UserID = p_user_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_response := '{"success":false,"message":"User or Game does not exist"}';
            RETURN;
    END;

    
    SELECT COUNT(*) INTO v_exists
    FROM Folowers
    WHERE GamePageId = p_game_id AND UserId = p_user_id;

    IF v_exists > 0 THEN

        UPDATE Folowers
        SET Rating = p_rating,
            ReviewComment = p_comment
        WHERE GamePageId = p_game_id AND UserId = p_user_id;
        
        v_altered := TRUE;
    ELSE

        INSERT INTO Folowers (GamePageId, UserId, Rating, ReviewComment)
        VALUES (p_game_id, p_user_id, p_rating, p_comment);
        
        v_altered := FALSE;
    END IF;

    
    p_response := '{"success":true,' 
               || '"message":"' || CASE WHEN v_altered THEN 'Review updated' ELSE 'Review added' END || '",'
               || '"altered":' || CASE WHEN v_altered THEN 'true' ELSE 'false' END 
               || '}';

EXCEPTION
    WHEN OTHERS THEN
        p_response := '{"success":false,"message":"Internal error: ' || SQLERRM || '"}';
END;
    
    
    PROCEDURE download_free_offer(
        p_user_id   IN NUMBER,
        p_offer_id  IN NUMBER,
        p_response  OUT CLOB
    ) IS
        v_is_free      NUMBER;
        v_result       CLOB := '{ "status":"success", "games": [';
        v_first        NUMBER := 1;
        v_action_type  NUMBER := enums_pkg.get_action_type_id('Download');
        v_entity_type  NUMBER := enums_pkg.get_entity_type_id('Offer');
    BEGIN
        p_response := NULL;
    
        -- Проверяем, бесплатный ли оффер
        SELECT COUNT(*)
        INTO v_is_free
        FROM Offers
        WHERE OfferID = p_offer_id
          AND Price = 0;
    
        IF v_is_free = 0 THEN
            p_response := '{"status":"error","message":"This offer is not free"}';
            RETURN;
        END IF;
    
        -- Добавляем игры и ссылки в результат
        FOR rec IN (
            SELECT G.GameID, G.GameName, G.DownloadLink
            FROM OfferGameLinks L
            JOIN Games G ON G.GameID = L.GameID
            WHERE L.OfferID = p_offer_id
        ) LOOP
            IF v_first = 0 THEN
                v_result := v_result || ',';
            END IF;
            v_first := 0;
    
            v_result := v_result ||
                '{ "game_id":' || rec.GameID ||
                ', "name":"' || rec.GameName || '"' ||
                ', "download_url":"' || rec.DownloadLink || '" }';
        END LOOP;
    
        v_result := v_result || ' ] }';
        p_response := v_result;
    
        -- Добавляем запись в таблицу UserActivity
        INSERT INTO UserActivity(
            UserID,
            ActionType,
            EntityType,
            EntityID,
            Details,
            CreatedAt,
            IpAddress,
            UserAgent
        ) VALUES (
            p_user_id,
            v_action_type,
            v_entity_type,
            p_offer_id,
            'Downloaded offer',
            SYSTIMESTAMP,
            NULL,  
            NULL   
        );
    
    EXCEPTION
        WHEN OTHERS THEN
            p_response := '{"status":"error","message":"DB error: ' || SQLERRM || '"}';
            ROLLBACK;
    END download_free_offer;

        
        PROCEDURE download_library_game(
        p_user_id  IN NUMBER,
        p_game_id  IN NUMBER,
        p_response OUT CLOB
    ) IS
        v_in_library   NUMBER;
        v_download_url VARCHAR2(512);
    BEGIN
        p_response := NULL;
    
        -- Проверяем, что игра есть в библиотеке
        SELECT COUNT(*)
        INTO v_in_library
        FROM Libraries
        WHERE UserID = p_user_id
          AND gameIid = p_game_id;
    
        IF v_in_library = 0 THEN
            p_response :=
                '{"status":"error","message":"Game not in user library"}';
            RETURN;
        END IF;
    
        -- Получаем ссылку на скачивание
        SELECT DownloadLink
        INTO v_download_url
        FROM Games
        WHERE GameID = p_game_id;
    
        p_response :=
            '{"status":"success",'||
            '"message":"Download allowed",'||
            '"game_id":' || p_game_id || ','||
            '"download_url":"' || v_download_url || '"}';
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_response :=
                '{"status":"error","message":"Game not found"}';
        WHEN OTHERS THEN
            p_response :=
                '{"status":"error","message":"DB error: '||SQLERRM||'"}';
    END download_library_game;
    
    
    
PROCEDURE get_game_page(
    p_page_id   IN NUMBER,
    p_user_id   IN NUMBER,
    p_ip        IN VARCHAR2 DEFAULT NULL,
    p_useragent IN VARCHAR2 DEFAULT NULL,
    p_response  OUT CLOB
)
IS
    v_status         VARCHAR2(125);
    v_followers      NUMBER;
    v_screenshots    CLOB;
    v_offers         CLOB;
    v_json           CLOB;

    v_action_type_id NUMBER;
    v_entity_type_id NUMBER;
BEGIN

    SELECT s.Status
    INTO v_status
    FROM GamePages gp
    JOIN GamePagesStatuses s ON gp.Status = s.StatusID
    WHERE gp.PageID = p_page_id;


    IF v_status != 'Active' THEN
        p_response := '{"status":"ERROR","message":"This page is not active or hidden"}';
        RETURN;
    END IF;


    SELECT COUNT(*)
    INTO v_followers
    FROM Folowers
    WHERE GamePageId = p_page_id;

    v_screenshots := get_screenshots_json(p_page_id);
    v_offers      := get_offers_json(p_page_id);

    v_json := JSON_OBJECT(
        'page_id'     VALUE p_page_id,
        'followers'   VALUE v_followers,
        'status'      VALUE v_status,
        'screenshots' VALUE v_screenshots,
        'offers'      VALUE v_offers
    );

    p_response := v_json;


    SELECT ActionType INTO v_action_type_id FROM ActionTypes WHERE Type = 'ViewPage';
    SELECT TypeID INTO v_entity_type_id FROM EntityTypes WHERE EntityName = 'GamePage';

    INSERT INTO UserActivity (
        UserID, ActionType, EntityType, EntityID, Details, CreatedAt, IpAddress, UserAgent
    )
    VALUES (
        p_user_id, v_action_type_id, v_entity_type_id, p_page_id,
        'View active game page', SYSTIMESTAMP, p_ip, p_useragent
    );

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_response := '{"status":"ERROR","message":"Page not found"}';

    WHEN OTHERS THEN
        p_response := '{"status":"ERROR","message":"DB error: ' || SQLERRM || '"}';
END get_game_page;
    
    
    PROCEDURE get_user_library(
    p_user_id IN NUMBER,
    p_response OUT CLOB
    ) IS
        TYPE t_library_rec IS RECORD (
            GameID      NUMBER,
            GameName    NVARCHAR2(512),
            DeveloperID NUMBER,
            DownloadLink VARCHAR2(512),
            BoughtIn    TIMESTAMP WITH TIME ZONE
        );
    TYPE t_library_tab IS TABLE OF t_library_rec;
    v_library t_library_tab;
    BEGIN
        -- Получаем игры пользователя
        SELECT g.GameID,
               g.GameName,
               g.DeveloperID,
               g.DownloadLink,
               l.BoughtIn
        BULK COLLECT INTO v_library
        FROM Libraries l
        JOIN Games g ON g.GameID = l.gameIid
        WHERE l.userId = p_user_id;
    
        -- Формируем JSON-ответ
        IF v_library.COUNT = 0 THEN
            p_response := '{"status":"OK","library":[]}';
        ELSE
            p_response := '[';
            FOR i IN 1..v_library.COUNT LOOP
                p_response := p_response || 
                    '{"GameID":' || v_library(i).GameID ||
                    ',"GameName":"' || v_library(i).GameName || '"' ||
                    ',"DeveloperID":' || v_library(i).DeveloperID ||
                    ',"DownloadLink":"' || v_library(i).DownloadLink || '"' ||
                    ',"BoughtIn":"' || TO_CHAR(v_library(i).BoughtIn, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || '"}';
                
                IF i < v_library.COUNT THEN
                    p_response := p_response || ',';
                END IF;
            END LOOP;
            p_response := '{"status":"OK","library":' || p_response || '}';
        END IF;
    
    EXCEPTION
        WHEN OTHERS THEN
            p_response := '{"status":"ERROR","message":"DB error: ' || SQLERRM || '"}';
    END get_user_library;
        
    
    
    
PROCEDURE complete_purchase(
    p_transaction_id IN NUMBER,
    p_response       OUT CLOB
) IS
    v_user_id      NUMBER;
    v_offer_id     NUMBER;
    v_amount       NUMBER(10,2);
    v_currency     NVARCHAR2(6);
    v_use_balance  NUMBER;
    v_user_balance NUMBER(10,2);
    
    -- Динамическое получение ID из пакета enums_pkg
    v_status_pending   NUMBER := enums_pkg.get_transaction_status_id('Pending');
    v_status_completed NUMBER := enums_pkg.get_transaction_status_id('Completed');
    v_action_type      NUMBER := enums_pkg.get_action_type_id('Purchase');
    v_entity_type      NUMBER := enums_pkg.get_entity_type_id('Offer');
    
    v_current_status   NUMBER;
BEGIN
    -- 1. Сначала находим транзакцию, чтобы понять её текущее состояние
    BEGIN
        SELECT Status, UserID, OfferID, Amount, Currency,
               CASE WHEN PaymentMethod = 'Balance' THEN 1 ELSE 0 END
        INTO v_current_status, v_user_id, v_offer_id, v_amount, v_currency, v_use_balance
        FROM Transactions
        WHERE ID = p_transaction_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_response := make_json('ERROR', 'Transaction ID ' || p_transaction_id || ' not found.');
            RETURN;
    END;

    -- 2. Проверяем, находится ли транзакция в нужном статусе (Pending)
    IF v_current_status != v_status_pending THEN
        p_response := make_json('ERROR', 'Transaction is in status ID ' || v_current_status || 
                                '. Expected status: ' || v_status_pending || ' (Pending)');
        RETURN;
    END IF;

    -- 3. Логика оплаты с баланса
    IF v_use_balance = 1 THEN
        SELECT Balance INTO v_user_balance
        FROM Users
        WHERE UserID = v_user_id
        FOR UPDATE; -- Блокировка строки для предотвращения Race Condition

        IF v_user_balance < v_amount THEN
            p_response := make_json('ERROR', 'Insufficient funds. Required: ' || v_amount || ' ' || v_currency);
            RETURN;
        END IF;

        UPDATE Users
        SET Balance = Balance - v_amount
        WHERE UserID = v_user_id;
    END IF;

    -- 4. Обновляем статус транзакции на Completed
    UPDATE Transactions
    SET Status = v_status_completed, 
        CompletedAt = CURRENT_TIMESTAMP
    WHERE ID = p_transaction_id;

    -- 5. Добавляем игры в библиотеку (защита от дубликатов через NOT EXISTS)
    INSERT INTO Libraries(userId, gameIid, BoughtIn)
    SELECT v_user_id, GameID, CURRENT_TIMESTAMP
    FROM OfferGameLinks
    WHERE OfferId = v_offer_id
    AND NOT EXISTS (
        SELECT 1 FROM Libraries WHERE userId = v_user_id AND gameIid = GameID
    );

    -- 6. Логируем активность
    INSERT INTO UserActivity(
        UserID, ActionType, EntityType, EntityID, Details, CreatedAt
    )
    VALUES(
        v_user_id, v_action_type, v_entity_type, v_offer_id,
        'Purchase completed. TrID: ' || p_transaction_id, CURRENT_TIMESTAMP
    );

    COMMIT;
    p_response := make_json('OK', 'Purchase successfully completed.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_response := make_json('ERROR', 'Internal Database Error: ' || SQLERRM);
END complete_purchase;
    
    
 PROCEDURE purchase_game_pending(
    p_user_id        IN NUMBER,
    p_offer_id       IN NUMBER,
    p_use_balance    IN NUMBER,
    p_payment_method IN NVARCHAR2,
    p_response       OUT CLOB
) IS
    v_offer_price      NUMBER(10,2);
    v_final_price      NUMBER(10,2);
    v_offer_currency   NVARCHAR2(6);
    v_total_games      NUMBER;
    v_owned_games      NUMBER;
    v_transaction_id   NUMBER;
    v_method           NVARCHAR2(125);
    v_type_id          NUMBER := enums_pkg.get_transaction_type_id('Payment');
    v_status_id        NUMBER := enums_pkg.get_transaction_status_id('Pending');
BEGIN
    -- 1. Получаем базовую информацию об оффере
    SELECT Price, Currency
    INTO v_offer_price, v_offer_currency
    FROM Offers
    WHERE OfferId = p_offer_id;

    -- 2. Считаем состав оффера и сколько игр уже есть у юзера
    SELECT 
        COUNT(ogl.GameID),
        COUNT(l.gameIid)
    INTO v_total_games, v_owned_games
    FROM OfferGameLinks ogl
    LEFT JOIN Libraries l ON ogl.GameID = l.gameIid AND l.userId = p_user_id
    WHERE ogl.OfferId = p_offer_id;

    -- 3. Проверка: если оффер пуст (техническая ошибка)
    IF v_total_games = 0 THEN
        p_response := make_json('ERROR', 'This offer does not contain any games');
        RETURN;
    END IF;

    -- 4. Логика "Уже куплено" и Скидка
    IF v_owned_games = v_total_games THEN
        -- Если есть все игры из предложения
        p_response := make_json('ERROR', 'You already own all games in this offer');
        RETURN;
    ELSIF v_owned_games > 0 THEN
        -- Расчет скидки: пропорционально количеству отсутствующих игр
        -- Формула: Цена * ((Всего - Есть) / Всего)
        v_final_price := v_offer_price * ((v_total_games - v_owned_games) / v_total_games);
    ELSE
        -- Игр из набора у пользователя нет
        v_final_price := v_offer_price;
    END IF;

    -- 5. Определяем способ оплаты
    IF p_use_balance = 1 THEN
        v_method := N'Balance';
    ELSE
        v_method := p_payment_method;
    END IF;

    -- 6. Создаём транзакцию с итоговой ценой
    INSERT INTO Transactions (
        OfferID, UserID, TYPE, Status, Amount, Currency, CreatedAt, PaymentMethod
    )
    VALUES (
        p_offer_id,
        p_user_id,
        v_type_id,
        v_status_id,
        v_final_price,
        v_offer_currency,
        CURRENT_TIMESTAMP,
        v_method
    )
    RETURNING ID INTO v_transaction_id;

    p_response := make_json('OK', 'Transaction created. Owned games: ' || v_owned_games || 
                                  '/' || v_total_games || '. Final price: ' || v_final_price || 
                                  '; Transaction ID: ' || v_transaction_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_response := make_json('ERROR', 'Offer not found');
    WHEN OTHERS THEN
        p_response := make_json('ERROR', 'DB error: ' || SQLERRM);
END purchase_game_pending;
    
    
    
    PROCEDURE add_balance_transaction(
        p_user_id IN NUMBER,
        p_amount IN NUMBER,
        p_payment_method IN NVARCHAR2,
        p_response OUT CLOB
    ) IS
        v_user_active NUMBER;
        v_new_balance NUMBER(10,2);
        v_transaction_id NUMBER;
        v_type_id NUMBER   := enums_pkg.get_transaction_type_id('Deposit');
        v_status_id NUMBER := enums_pkg.get_transaction_status_id('Completed');
    BEGIN
        IF p_amount <= 0 THEN
            p_response := make_json('ERROR', 'Amount must be greater than zero');
            RETURN;
        END IF;
    
    
        -- Добавляем запись в Transactions (тип = Пополнение, статус = Completed)
        INSERT INTO Transactions (
            OfferID,        
            UserID,
            TYPE,           -- тип транзакции, например 1 = Пополнение
            Status,         -- Completed = 2
            Amount,
            Currency,
            CreatedAt,
            CompletedAt,
            PaymentMethod
        )
        VALUES (
            NULL,
            p_user_id,
            v_type_id,
            v_status_id,
            p_amount,
            'BYN',          
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            p_payment_method
        )
        RETURNING ID INTO v_transaction_id;
    
        -- Обновляем баланс пользователя
        UPDATE Users
        SET Balance = Balance + p_amount
        WHERE UserID = p_user_id;
    
        p_response := make_json('OK', 'Balance updated successfully. Transaction ID: ' || v_transaction_id);
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_response := make_json('ERROR', 'User not found');
        WHEN OTHERS THEN
            p_response := make_json('ERROR', 'DB error: ' || SQLERRM);
    END add_balance_transaction;


    
    
    PROCEDURE get_profile(
        p_user_id  IN NUMBER,
        p_response OUT CLOB
    ) IS
        v_email   Users.Email%TYPE;
        v_nick    Users.NickName%TYPE;
        v_role    Users.RoleID%TYPE;
        v_active  Users.IsActive%TYPE;
        v_avatar  Users.Avatar_uri%TYPE;
        v_country Users.Country%TYPE;
        v_created Users.CreatedAt%TYPE;
        v_Balance Users.Balance %TYPE;
    BEGIN
        SELECT Email, NickName, RoleID, IsActive, Avatar_uri, Country, CreatedAt, Balance
        INTO v_email, v_nick, v_role, v_active, v_avatar, v_country, v_created, v_Balance
        FROM Users
        WHERE UserID = p_user_id;

        p_response :=
            '{"status":"OK","profile":{' ||
            '"email":"'   || v_email   || '",' ||
            '"nickname":"'|| v_nick    || '",' ||
            '"role":'     || v_role    || ','  ||
            '"active":'   || v_active  || ','  ||
            '"avatar":"'  || NVL(v_avatar, '')  || '",' ||
            '"country":"' || NVL(v_country,'') || '",' ||
            '"Balence":"' || v_Balance || '",' ||
            '"created":"' || TO_CHAR(v_created, 'YYYY-MM-DD"T"HH24:MI:SS') ||
            '"}}';

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_response := make_json('ERROR', 'User not found');
    END;
    
    
    PROCEDURE update_email(
        p_user_id IN NUMBER,
        p_new_email IN NVARCHAR2,
        p_response OUT CLOB
    ) IS
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_cnt
        FROM Users
        WHERE Email = p_new_email AND UserID <> p_user_id;

        IF v_cnt > 0 THEN
            p_response := make_json('ERROR', 'Email already in use');
            RETURN;
        END IF;

        UPDATE Users
        SET Email = p_new_email
        WHERE UserID = p_user_id;

        p_response := make_json('OK', 'Email updated');
    END;


    PROCEDURE update_nickname(
        p_user_id IN NUMBER,
        p_new_nickname IN NVARCHAR2,
        p_response OUT CLOB
    ) IS
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_cnt
        FROM Users
        WHERE NickName = p_new_nickname AND UserID <> p_user_id;

        IF p_new_nickname is NULL then
            p_response := make_json('ERROR', 'can not be null');
            RETURN;
        END IF;

        UPDATE Users
        SET NickName = p_new_nickname
        WHERE UserID = p_user_id;

        p_response := make_json('OK', 'Nickname updated');
    END;
    
    
    
    PROCEDURE update_password(
        p_user_id IN NUMBER,
        p_old_password IN NVARCHAR2,
        p_new_password IN NVARCHAR2,
        p_response OUT CLOB
    ) IS
        v_hash_current Users.PasswordHash%TYPE;
        v_hash_old     VARCHAR2(255);
        v_hash_new     VARCHAR2(255);
    BEGIN

        SELECT PasswordHash INTO v_hash_current
        FROM Users
        WHERE UserID = p_user_id;
    

        v_hash_old := hash_password(p_old_password);
    
        IF v_hash_current <> v_hash_old THEN
            p_response := make_json('ERROR', 'Old password is incorrect');
            RETURN;
        END IF;
    

        v_hash_new := hash_password(p_new_password);
    

        UPDATE Users
        SET PasswordHash = v_hash_new
        WHERE UserID = p_user_id;
    
        p_response := make_json('OK', 'Password updated');
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_response := make_json('ERROR', 'User not found');
        WHEN OTHERS THEN
            p_response := make_json('ERROR', 'DB error: ' || SQLERRM);
    END;



    PROCEDURE update_profile(
        p_user_id IN NUMBER,
        p_avatar_uri IN NVARCHAR2,
        p_country IN NVARCHAR2,
        p_response OUT CLOB
    ) IS
    BEGIN
        UPDATE Users
        SET 
            Avatar_uri = p_avatar_uri,
            Country    = p_country
        WHERE UserID = p_user_id;

        p_response := make_json('OK', 'Profile updated');
    END;
    
    
END user_pkg;
/

GRANT EXECUTE ON app_user.user_pkg TO USER_APP;