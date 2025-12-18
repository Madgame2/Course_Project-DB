ALTER SESSION set CONTAINER = KPDB_GAMESTORE;


CREATE OR REPLACE PACKAGE guest_pkg IS
    
    PROCEDURE get_game_page
    (
        p_page_id IN NUMBER,
        p_response OUT CLOB
    );
    
    
    PROCEDURE get_game_pages_filtered(
        p_developer_id IN NUMBER    DEFAULT NULL,
        p_title_search IN NVARCHAR2 DEFAULT NULL,
        p_genre_id     IN NUMBER    DEFAULT NULL,
        p_order_by     IN NVARCHAR2 DEFAULT 'TITLE', -- 'TITLE' или 'PRICE'
        p_order_dir    IN NVARCHAR2 DEFAULT 'ASC', -- 'ASC' или 'DESC'
        p_response     OUT CLOB
    );
    
    
    PROCEDURE TryDownload(
        p_offer_id  IN NUMBER,
        p_response  OUT CLOB
    );
    
    PROCEDURE register_guest(
        p_username IN NVARCHAR2,
        p_password IN NVARCHAR2,
        p_email    IN NVARCHAR2,
        p_response OUT CLOB
    ); 
    
    PROCEDURE login_guest(
        p_email    IN NVARCHAR2,
        p_password IN NVARCHAR2,
        p_response OUT CLOB
    );
        
END guest_pkg;
/



CREATE OR REPLACE PACKAGE BODY guest_pkg IS
    
PROCEDURE get_game_page(p_page_id IN NUMBER, p_response OUT CLOB)
IS
    v_status      VARCHAR2(125);
    v_followers   NUMBER;
    v_screenshots CLOB;
    v_offers      CLOB;
    v_json        CLOB;
BEGIN
    -- 1. Получаем статус и проверяем, что страница существует И она Active
    SELECT s.Status
    INTO v_status
    FROM GamePages gp
    JOIN GamePagesStatuses s ON gp.Status = s.StatusID
    WHERE gp.PageID = p_page_id 
      AND s.Status = 'Active'; -- Фильтр только для активных страниц

    -- 2. Считаем подписчиков
    SELECT COUNT(*) INTO v_followers
    FROM Folowers
    WHERE GamePageId = p_page_id;
    
    -- 3. Получаем вложенные JSON (скриншоты и предложения)
    v_screenshots := get_screenshots_json(p_page_id);
    v_offers      := get_offers_json(p_page_id);

    -- 4. Формируем итоговый JSON
    v_json := JSON_OBJECT(
                  'page_id'     VALUE p_page_id,
                  'followers'   VALUE v_followers,
                  'status'      VALUE v_status,
                  'screenshots' VALUE v_screenshots, -- Предполагается, что функция возвращает JSON тип или строку
                  'offers'      VALUE v_offers
              );

    p_response := v_json;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_response := '{"status":"ERROR","message":"Page not found or is not active"}';
    WHEN OTHERS THEN
        p_response := '{"status":"ERROR","message":"DB error: ' || SQLERRM || '"}';
END get_game_page;
    
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

    -- Рекорды для хранения данных
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

    -- 2. Динамический SQL с явным использованием алиасов (v. и gp.)
    -- Используем v.PageID и т.д., чтобы избежать ORA-00918
    v_sql := 'SELECT DISTINCT v.PageID, v.PageTittle, v.DeveloperId, v.ViewLink
              FROM OfferGamesWithGenres v
              JOIN GamePages gp ON v.PageID = gp.PageID
              WHERE gp.Status = ' || v_status_active_id;

    -- Фильтр по разработчику
    IF p_developer_id IS NOT NULL THEN
        v_sql := v_sql || ' AND v.DeveloperId = ' || p_developer_id;
    END IF;

    -- Фильтр по названию (с защитой от кавычек)
    IF p_title_search IS NOT NULL AND p_title_search <> '' THEN
        v_sql := v_sql || ' AND LOWER(v.PageTittle) LIKE ''%' || LOWER(REPLACE(p_title_search, '''', '''''')) || '%''';
    END IF;

    -- Фильтр по жанру
    IF p_genre_id IS NOT NULL THEN
        v_sql := v_sql || ' AND v.Ganer_ID = ' || p_genre_id;
    END IF;

    -- Сортировка (явно указываем v. столбец)
    IF UPPER(p_order_by) = 'PRICE' THEN
        v_sql := v_sql || ' ORDER BY MAX(v.Price)'; -- Используем MAX т.к. есть DISTINCT
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

    -- Удаляем лишнюю запятую после последней страницы
    IF SUBSTR(v_json, -1, 1) = ',' THEN
        v_json := SUBSTR(v_json, 1, LENGTH(v_json)-1);
    END IF;

    v_json := v_json || ']';
    p_response := v_json;

EXCEPTION
    WHEN OTHERS THEN
        -- Закрываем курсоры, если они остались открыты при ошибке
        IF c_pages%ISOPEN THEN CLOSE c_pages; END IF;
        IF c_offers%ISOPEN THEN CLOSE c_offers; END IF;
        p_response := '{"status":"error","message":"Внутренняя ошибка: ' || REPLACE(SQLERRM, '"', '\"') || '"}';
END;





    
    PROCEDURE TryDownload
    (
        p_offer_id  IN NUMBER,
        p_response  OUT CLOB
    )
    IS
        v_price          NUMBER(10,2);
        v_game_id        NUMBER;
        v_download_link  VARCHAR2(512);
    BEGIN
    
        BEGIN
            SELECT Price
            INTO v_price
            FROM Offers
            WHERE OfferId = p_offer_id;
    
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_response := '{"status":"error","message":"Оффер не найден"}';
                RETURN;
        END;
        
        IF v_price > 0 THEN
            p_response := '{"status":"error","message":"Эта игра платная"}';
            RETURN;
        END IF;
        
        
    FOR rec IN (
        SELECT g.GameID, g.DownloadLink
        FROM OfferGameLinks ogl
        JOIN Games g ON g.GameID = ogl.GameID
        WHERE ogl.OfferId = p_offer_id
    ) LOOP
        IF rec.DownloadLink IS NULL THEN
            p_response := '{"status":"error","message":"Ссылка на скачивание недоступна для игры ' 
                          || rec.GameID || '"}';
            RETURN;
        END IF;
    END LOOP;
    

    DECLARE
        v_links CLOB := '[';
    BEGIN
            FOR rec IN (
                SELECT g.DownloadLink
                FROM OfferGameLinks ogl
                JOIN Games g ON g.GameID = ogl.GameID
                WHERE ogl.OfferId = p_offer_id
            ) LOOP
                IF v_links != '[' THEN
                    v_links := v_links || ',';
                END IF;
                v_links := v_links || '"' || rec.DownloadLink || '"';
            END LOOP;
            v_links := v_links || ']';
    
            p_response := '{"status":"success","downloads":' || v_links || '}';
        END;
    
    EXCEPTION
        WHEN OTHERS THEN
            p_response := '{"status":"error","message":"Внутренняя ошибка: ' || SQLERRM || '"}';
        
    END TryDownload;

    PROCEDURE login_guest(
        p_email    IN NVARCHAR2,
        p_password IN NVARCHAR2,
        p_response OUT CLOB
    )
    IS
        v_user_id      NUMBER;
        v_password_db  NVARCHAR2(255);
        v_password     NVARCHAR2(255);
        v_is_active    NUMBER;
    BEGIN
        IF p_email IS NULL OR p_password IS NULL THEN
            p_response := '{"status":"error","message":"Email и пароль обязательны"}';
            RETURN;
        END IF;
        
        BEGIN
            SELECT userid, passwordhash, isactive
            INTO v_user_id, v_password_db, v_is_active
            FROM users
            WHERE LOWER(email) = LOWER(p_email);

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_response := '{"status":"error","message":"Неверный email или пароль"}';
                RETURN;
        END;
        
        v_password := hash_password(p_password);
        
        IF v_password_db <> v_password THEN
            p_response := '{"status":"error","message":"Неверный email или пароль"}';
            RETURN;
        END IF;
        
        UPDATE Users set isactive = 1 where userId =  v_user_id;
        p_response :=
            '{"status":"success","user_id":' || v_user_id || '}';
            
    EXCEPTION
        WHEN OTHERS THEN
            p_response := '{"status":"error","message":"Внутренняя ошибка: ' || SQLERRM || '"}';
    END login_guest;

    PROCEDURE register_guest(
        p_username IN NVARCHAR2,
        p_password IN NVARCHAR2,
        p_email    IN NVARCHAR2,
        p_response OUT CLOB
    ) IS
            v_user_id NUMBER;
            v_json    CLOB;
            v_exists  NUMBER;
            
            DEFAULT_AVATAR CONSTANT NVARCHAR2(255) := 'default_avatar.png';
            DEFAULT_COUNTRY CONSTANT NVARCHAR2(255) := 'Unknown';
        BEGIN
        
        IF p_email IS NULL THEN
            p_response := '{"status":"error","message":"Email не может быть пустым"}';
            RETURN;
        END IF;
    
        IF NOT REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
            p_response := '{"status":"error","message":"Email имеет неверный формат"}';
            RETURN;
        END IF;
    
        SELECT COUNT(*)
        INTO v_exists
        FROM users
        WHERE LOWER(Email) = LOWER(p_email);
    
        IF v_exists > 0 THEN
            p_response := '{"status":"error","message":"Email уже используется"}';
            RETURN;
        END IF;
    
        
        INSERT INTO Users (
            Email,
            NickName,
            PasswordHash,
            RoleID,
            CreatedAt,
            IsActive,
            Avatar_uri,
            Country
        )
        VALUES (
            p_email,
            p_username,
            hash_password(p_password),      
            1,
            CURRENT_TIMESTAMP,
            0,
            DEFAULT_AVATAR,
            DEFAULT_COUNTRY
        )
        RETURNING UserID INTO v_user_id;    
        
        
        v_json := '{"status":"success","user_id":' || v_user_id || '}';
        p_response := v_json;
        
    EXCEPTION
    
        WHEN DUP_VAL_ON_INDEX THEN
            p_response := '{"status":"error","message":"Email  уже используются"}';
    
        WHEN VALUE_ERROR THEN
            p_response := '{"status":"error","message":"Некорректные входные данные"}';
    
        WHEN OTHERS THEN
    
            p_response := '{"status":"error","message":"Внутренняя ошибка: ' || SQLERRM || '"}';
    
    END register_guest;
    
END guest_pkg;
/


GRANT EXECUTE ON app_user.guest_pkg TO GUEST;










