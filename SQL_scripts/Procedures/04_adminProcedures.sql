

CREATE OR REPLACE PACKAGE admin_pkg IS

    PROCEDURE check_admin_access(
        p_user_id IN NUMBER
    );


    PROCEDURE change_user_role(
        p_admin_id IN NUMBER,
        p_user_id  IN NUMBER,
        p_role_id  IN NUMBER
    );

    PROCEDURE get_all_reports(
        p_admin_id IN NUMBER,
        p_result   OUT CLOB
    );

    PROCEDURE get_reports_filtered(
        p_admin_id      IN NUMBER,
        p_target_type_id IN NUMBER DEFAULT NULL,
        p_reporter_id   IN NUMBER DEFAULT NULL,
        p_date_from     IN DATE   DEFAULT NULL,
        p_date_to       IN DATE   DEFAULT NULL,
        p_result        OUT CLOB
    );

    PROCEDURE admin_update_game_page(
        p_admin_id   IN NUMBER,
        p_page_id    IN NUMBER,
        p_page_title IN NVARCHAR2,
        p_status_id  IN NUMBER,
        p_view_link  IN VARCHAR2,
        p_result        OUT CLOB
    );
    
    PROCEDURE admin_delete_game_page(
        p_admin_id IN NUMBER,
        p_page_id  IN NUMBER,
        p_result   OUT CLOB
    );
    
    PROCEDURE admin_delete_offer(
        p_admin_id IN NUMBER,
        p_offer_id IN NUMBER,
        p_result   OUT CLOB
    );
    
    
    PROCEDURE admin_update_game(
        p_admin_id IN NUMBER,
        p_game_id  IN NUMBER,
        p_download_link IN VARCHAR2,
        p_version  IN NVARCHAR2,
        p_type     IN NVARCHAR2,
        p_result OUT CLOB
    );
    
    PROCEDURE admin_delete_screenshot(
        p_admin_id      IN NUMBER,
        p_screenshot_id IN NUMBER
    );
    
    PROCEDURE admin_delete_all_screenshots(
        p_admin_id IN NUMBER,
        p_page_id  IN NUMBER
    );
    
    
    PROCEDURE get_all_transactions(
        p_admin_id IN NUMBER,
        p_result   OUT CLOB
    );
    
    PROCEDURE get_transactions_filtered(
        p_admin_id        IN NUMBER,
        p_user_id         IN NUMBER DEFAULT NULL,
        p_offer_id        IN NUMBER DEFAULT NULL,
        p_type_id         IN NUMBER DEFAULT NULL,
        p_status_id       IN NUMBER DEFAULT NULL,
        p_date_from       IN TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_date_to         IN TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_result          OUT CLOB
    );
    
    PROCEDURE get_transaction_by_id(
        p_admin_id      IN NUMBER,
        p_transaction_id IN NUMBER,
        p_result        OUT CLOB
    );

    
END admin_pkg;
/


CREATE OR REPLACE PACKAGE BODY admin_pkg IS

    PROCEDURE check_admin_access(
        p_user_id IN NUMBER
    ) IS
        v_admin_role_id NUMBER;
        v_count         NUMBER;
    BEGIN
        v_admin_role_id := enums_pkg.get_role_id('Admin');
        
        SELECT COUNT(*)
        INTO v_count
        FROM Users
        WHERE UserID = p_user_id
          AND RoleID = v_admin_role_id;

        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20021,
                'Access denied: administrator privileges required'
            );
        END IF;
        
    END check_admin_access;

   PROCEDURE change_user_role(
    p_admin_id IN NUMBER,
    p_user_id  IN NUMBER,
    p_role_id  IN NUMBER
) IS
    v_admin_role_id NUMBER;
    v_user_exists   NUMBER;
    v_role_exists   NUMBER;
BEGIN
 
    check_admin_access(p_admin_id);

  
    IF p_admin_id = p_user_id THEN
        RAISE_APPLICATION_ERROR(-20011, 'Administrators cannot change their own role.');
    END IF;


    v_admin_role_id := enums_pkg.get_role_id('Admin');
    IF p_role_id = v_admin_role_id THEN
        RAISE_APPLICATION_ERROR(-20010, 'It is forbidden to assign administrator role via this procedure.');
    END IF;


    SELECT COUNT(*) INTO v_user_exists FROM Users WHERE UserID = p_user_id;
    IF v_user_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Target user not found.');
    END IF;

    -- 5. Проверка существования роли
    SELECT COUNT(*) INTO v_role_exists FROM Roles WHERE RoleID = p_role_id;
    IF v_role_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Target role not found.');
    END IF;


    UPDATE Users
    SET RoleID = p_role_id
    WHERE UserID = p_user_id;

    COMMIT; 

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error in change_user_role: ' || SQLERRM);
        RAISE; 
END change_user_role;
    
    PROCEDURE get_all_reports(
        p_admin_id IN NUMBER,
        p_result   OUT CLOB
    ) IS
        v_first BOOLEAN := TRUE;
    BEGIN
        p_result := NULL;
        
        check_admin_access(p_admin_id);
        
        p_result := '[';
        
            FOR r IN (
        SELECT
            ReportID,
            ReportFrom_UserId,
            ReportTo_UserID,
            ReportTo_GamePageID,
            Tittle,
            Message,
            CreatedAt
        FROM Reports
        ORDER BY CreatedAt DESC
    ) LOOP
        
        IF v_first THEN
            v_first := FALSE;
        ELSE
            p_result := p_result || ',';
        END IF;
        
                p_result := p_result || 
            '{' ||
            '"reportId":'     || r.ReportID || ',' ||
            '"ReportFrom_UserId":'       || NVL(TO_CHAR(r.ReportFrom_UserId), 'null') || ',' ||
            '"ReportTo_UserID":'   ||NVL(TO_CHAR(r.ReportTo_UserID), 'null') || ',' ||
            '"ReportTo_GamePageID":'     || NVL(TO_CHAR(r.ReportTo_GamePageID), 'null') || ',' ||
            '"Tittle":"'      || REPLACE(r.Tittle, '"', '\"') || '",' ||
            '"Message":'       || REPLACE(r.Message, '"', '\"') || ',' ||
            '"createdAt":"'   || TO_CHAR(r.CreatedAt, 'YYYY-MM-DD"T"HH24:MI:SS TZH:TZM') || '"' ||
            '}';

    END LOOP;

    p_result := p_result || ']';

    EXCEPTION
        WHEN OTHERS THEN
            p_result := '{"error":"' || REPLACE(SQLERRM, '"', '\"') || '"}';
            DBMS_OUTPUT.PUT_LINE('Error in get_all_reports: ' || SQLERRM);
    END get_all_reports;
    
    PROCEDURE get_reports_filtered(
        p_admin_id       IN NUMBER,
        p_target_type_id IN NUMBER DEFAULT NULL,
        p_reporter_id    IN NUMBER DEFAULT NULL,
        p_date_from      IN DATE   DEFAULT NULL,
        p_date_to        IN DATE   DEFAULT NULL,
        p_result         OUT CLOB
    ) IS
        v_first BOOLEAN := TRUE;
    BEGIN
        
    p_result := NULL;

    check_admin_access(p_admin_id);

    p_result := '[';
    
    FOR r IN (
        SELECT
            ReportID,
            ReportFrom_UserId,
            ReportTo_UserID,
            ReportTo_GamePageID,
            Tittle,
            Message,
            CreatedAt
        FROM Reports
        WHERE
        (p_reporter_id IS NULL OR ReportFrom_UserId = p_reporter_id)
        AND (
                p_target_type_id IS NULL
                OR (p_target_type_id = 1 AND ReportTo_UserID IS NOT NULL)
                OR (p_target_type_id = 2 AND ReportTo_GamePageID IS NOT NULL)
            )
        AND (
                p_date_from IS NULL
                OR CreatedAt >= CAST(p_date_from AS TIMESTAMP)
            )
        AND (
                p_date_to IS NULL
                OR CreatedAt <= CAST(p_date_to AS TIMESTAMP)
            )
        ) LOOP
              IF v_first THEN
            v_first := FALSE;
        ELSE
            p_result := p_result || ',';
        END IF;

        p_result := p_result ||
            '{' ||
            '"reportId":' || r.ReportID || ',' ||
            '"reportFromUserId":' || r.ReportFrom_UserId || ',' ||
            '"reportToUserId":' ||
                CASE
                    WHEN r.ReportTo_UserID IS NULL THEN 'null'
                    ELSE TO_CHAR(r.ReportTo_UserID)
                END || ',' ||
            '"reportToGamePageId":' ||
                CASE
                    WHEN r.ReportTo_GamePageID IS NULL THEN 'null'
                    ELSE TO_CHAR(r.ReportTo_GamePageID)
                END || ',' ||
            '"title":"'   || REPLACE(r.Tittle, '"', '\"') || '",' ||
            '"message":"' || REPLACE(r.Message, '"', '\"') || '",' ||
            '"createdAt":"' ||
                TO_CHAR(r.CreatedAt, 'YYYY-MM-DD"T"HH24:MI:SS TZH:TZM') ||
            '"' ||
            '}';

    END LOOP;
    p_result := p_result || ']';

    EXCEPTION
        WHEN OTHERS THEN
            p_result := '{"error":"' || REPLACE(SQLERRM, '"', '\"') || '"}';
            DBMS_OUTPUT.PUT_LINE('Error in get_reports_filtered: ' || SQLERRM);
    END get_reports_filtered;
    
    PROCEDURE admin_update_game_page(
        p_admin_id   IN NUMBER,
        p_page_id    IN NUMBER,
        p_page_title IN NVARCHAR2,
        p_status_id  IN NUMBER,
        p_view_link  IN VARCHAR2,
        p_result     OUT CLOB
    ) IS
        v_cnt NUMBER;
    BEGIN
        p_result := NULL;
    
        check_admin_access(p_admin_id);
    
        SELECT COUNT(*)
        INTO v_cnt
        FROM GamePages
        WHERE PageID = p_page_id;
    
        IF v_cnt = 0 THEN
            p_result := '{"error":"Game page not found"}';
            RETURN;
        END IF;
        
        SELECT COUNT(*)
        INTO v_cnt
        FROM GamePagesStatuses
        WHERE Status = p_status_id;
    
        IF v_cnt = 0 THEN
            p_result := '{"error":"Invalid game page status"}';
            RETURN;
        END IF;
        
    UPDATE GamePages
    SET
        PageTittle = NVL(p_page_title, PageTittle),
        Status  = NVL(p_status_id, Status),
        ViewLink  = NVL(p_view_link, ViewLink)
    WHERE PageID = p_page_id;

    p_result := 
        '{' ||
        '"status":"success",' ||
        '"message":"Game page updated by administrator",' ||
        '"pageId":' || p_page_id ||
        '}';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_result := '{"error":"' || REPLACE(SQLERRM, '"', '\"') || '"}';
            DBMS_OUTPUT.PUT_LINE(
                'Error in admin_update_game_page: ' || SQLERRM
            );
    END admin_update_game_page;

PROCEDURE admin_delete_game_page(
    p_admin_id IN NUMBER,
    p_page_id  IN NUMBER,
    p_result   OUT CLOB
) IS
BEGIN
    check_admin_access(p_admin_id);

    -- 1. Удаляем скриншоты
    DELETE FROM Screenshots WHERE GamePageID = p_page_id;

    -- 2. Удаляем отзывы и подписки
    DELETE FROM Folowers WHERE GamePageId = p_page_id;

    -- 3. Удаляем жалобы на страницу
    DELETE FROM Reports WHERE ReportTo_GamePageID = p_page_id;

    -- 4. Обработка Офферов (связи и транзакции)
    -- Сначала удаляем связи офферов этой страницы с играми (Многие-ко-многим)
    DELETE FROM OfferGameLinks WHERE OfferId IN (SELECT OfferId FROM Offers WHERE PageID = p_page_id);
    
    -- Обнуляем ссылки в транзакциях (чтобы сохранить историю платежей, но удалить оффер)
    -- Либо удаляем транзакции, если история не нужна (ниже вариант с сохранением истории: SET NULL)
    UPDATE Transactions SET OfferID = NULL WHERE OfferID IN (SELECT OfferId FROM Offers WHERE PageID = p_page_id);
    
    -- Теперь удаляем сами офферы
    DELETE FROM Offers WHERE PageID = p_page_id;

    -- 5. Наконец, удаляем саму страницу
    DELETE FROM GamePages WHERE PageID = p_page_id;

    IF SQL%ROWCOUNT = 0 THEN
        p_result := '{"error":"Game page not found"}';
    ELSE
        p_result := '{"status":"success","message":"Page and all related data deleted","pageId":' || p_page_id || '}';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_result := '{"error":"' || REPLACE(SQLERRM, '"', '\"') || '"}';
END admin_delete_game_page;

PROCEDURE admin_delete_offer(
    p_admin_id IN NUMBER,
    p_offer_id IN NUMBER,
    p_result   OUT CLOB
) IS
BEGIN
    check_admin_access(p_admin_id);

    -- 1. Удаляем связи этого оффера с играми в таблице Many-to-Many
    DELETE FROM OfferGameLinks WHERE OfferId = p_offer_id;

    -- 2. Отвязываем транзакции (устанавливаем NULL), чтобы не ломать финансовую отчетность
    UPDATE Transactions SET OfferID = NULL WHERE OfferID = p_offer_id;

    -- 3. Удаляем сам оффер
    DELETE FROM Offers WHERE OfferId = p_offer_id;

    IF SQL%ROWCOUNT = 0 THEN
        p_result := '{"error":"Offer not found"}';
    ELSE
        p_result := '{"status":"success","message":"Offer deleted successfully"}';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_result := '{"error":"' || REPLACE(SQLERRM, '"', '\"') || '"}';
END admin_delete_offer;
    
    PROCEDURE admin_update_game(
        p_admin_id       IN NUMBER,
        p_game_id        IN NUMBER,
        p_download_link  IN VARCHAR2,
        p_version        IN NVARCHAR2,
        p_type           IN NVARCHAR2,
        p_result         OUT CLOB
    ) IS
        v_cnt NUMBER;
    BEGIN
        p_result := NULL;
        
        check_admin_access(p_admin_id);
        
        SELECT COUNT(*)
        INTO v_cnt
        FROM Games
        WHERE GameID = p_game_id;
        
        IF v_cnt = 0 THEN
            p_result := '{"error":"Game not found"}';
            RETURN;
        END IF;
        
        
        UPDATE Games
        SET
            DownloadLink = NVL(p_download_link, DownloadLink),
            Version      = NVL(p_version, Version),
            Type         = NVL(p_type, Type)
        WHERE GameID = p_game_id;
        
        
        p_result :=
        '{' ||
        '"status":"success",' ||
        '"message":"Game updated by administrator",' ||
        '"gameId":' || p_game_id ||
        '}';
        
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_result := '{"error":"' || REPLACE(SQLERRM, '"', '\"') || '"}';
        DBMS_OUTPUT.PUT_LINE(
            'Error in admin_update_game: ' || SQLERRM
        );
    END admin_update_game;

    PROCEDURE admin_delete_screenshot(
        p_admin_id      IN NUMBER,
        p_screenshot_id IN NUMBER
    ) IS
        v_cnt NUMBER;
    BEGIN
        check_admin_access(p_admin_id);
        
        SELECT COUNT(*)
        INTO v_cnt
        FROM Screenshots
        WHERE id = p_screenshot_id;
        
         IF v_cnt = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Screenshot not found');
            RETURN;
        END IF;
        
        DELETE FROM Screenshots
        WHERE id = p_screenshot_id;
        
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'Error in admin_delete_screenshot: ' || SQLERRM
        );
    END admin_delete_screenshot;
    
    PROCEDURE admin_delete_all_screenshots(
    p_admin_id IN NUMBER,
    p_page_id  IN NUMBER
    ) IS
        v_cnt NUMBER;
    BEGIN
        check_admin_access(p_admin_id);
        
        SELECT COUNT(*)
        INTO v_cnt
        FROM GamePages
        WHERE PageID = p_page_id;
    
        IF v_cnt = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Game page not found');
            RETURN;
        END IF;
        
        DELETE FROM Screenshots
        WHERE GamePageID = p_page_id;
    
        DBMS_OUTPUT.PUT_LINE(
            'All screenshots deleted for page ID = ' || p_page_id
        );
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'Error in admin_delete_all_screenshots: ' || SQLERRM
        );
    END admin_delete_all_screenshots;

    PROCEDURE get_all_transactions(
        p_admin_id IN NUMBER,
        p_result   OUT CLOB
    ) IS
        v_first BOOLEAN := TRUE;
    BEGIN
        p_result := NULL;
    
        -- Проверка прав администратора
        check_admin_access(p_admin_id);
    
        p_result := '[';
    
        FOR t IN (
            SELECT
                ID,
                OfferID,
                UserID,
                TYPE,
                Status,
                Amount,
                Currency,
                CreatedAt,
                CompletedAt,
                PaymentMethod,
                ExternalTransactionId
            FROM Transactions
            ORDER BY CreatedAt DESC
        ) LOOP
    
            IF v_first THEN
                v_first := FALSE;
            ELSE
                p_result := p_result || ',';
            END IF;
    
            p_result := p_result ||
                '{' ||
                '"transactionId":' || t.ID || ',' ||
                '"offerId":' || t.OfferID || ',' ||
                '"userId":' ||
                    CASE
                        WHEN t.UserID IS NULL THEN 'null'
                        ELSE TO_CHAR(t.UserID)
                    END || ',' ||
                '"typeId":' || t.TYPE || ',' ||
                '"statusId":' || t.Status || ',' ||
                '"amount":' || TO_CHAR(t.Amount, 'FM9999990.00') || ',' ||
                '"currency":"' || NVL(t.Currency, '') || '",' ||
                '"createdAt":"' ||
                    TO_CHAR(
                        t.CreatedAt,
                        'YYYY-MM-DD"T"HH24:MI:SS TZH:TZM'
                    ) ||
                '",' ||
                '"completedAt":' ||
                    CASE
                        WHEN t.CompletedAt IS NULL THEN 'null'
                        ELSE
                            '"' || TO_CHAR(
                                t.CompletedAt,
                                'YYYY-MM-DD"T"HH24:MI:SS TZH:TZM'
                            ) || '"'
                    END || ',' ||
                '"paymentMethod":"' ||
                    NVL(REPLACE(t.PaymentMethod, '"', '\"'), '') ||
                '",' ||
                '"externalTransactionId":"' ||
                    NVL(REPLACE(t.ExternalTransactionId, '"', '\"'), '') ||
                '"' ||
                '}';
    
        END LOOP;
    
        p_result := p_result || ']';
    
    EXCEPTION
        WHEN OTHERS THEN
            p_result := '{"error":"' || REPLACE(SQLERRM, '"', '\"') || '"}';
            DBMS_OUTPUT.PUT_LINE(
                'Error in get_all_transactions: ' || SQLERRM
            );
    END get_all_transactions;

    PROCEDURE get_transactions_filtered(
        p_admin_id        IN NUMBER,
        p_user_id         IN NUMBER DEFAULT NULL,
        p_offer_id        IN NUMBER DEFAULT NULL,
        p_type_id         IN NUMBER DEFAULT NULL,
        p_status_id       IN NUMBER DEFAULT NULL,
        p_date_from       IN TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_date_to         IN TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_result          OUT CLOB
    ) IS
        v_is_admin NUMBER;
        v_first    NUMBER := 1;
    BEGIN
        p_result := NULL;
    
        check_admin_access(p_admin_id);
    

        p_result := '{ "status": "success", "transactions": [';
    
        FOR rec IN (
            SELECT
                t.ID,
                t.OfferID,
                t.UserID,
                t.Type,
                t.Status,
                t.Amount,
                t.Currency,
                t.CreatedAt,
                t.CompletedAt,
                t.PaymentMethod,
                t.ExternalTransactionId
            FROM Transactions t
            WHERE (p_user_id   IS NULL OR t.UserID  = p_user_id)
              AND (p_offer_id  IS NULL OR t.OfferID = p_offer_id)
              AND (p_type_id   IS NULL OR t.Type    = p_type_id)
              AND (p_status_id IS NULL OR t.Status  = p_status_id)
              AND (p_date_from IS NULL OR t.CreatedAt >= p_date_from)
              AND (p_date_to   IS NULL OR t.CreatedAt <= p_date_to)
            ORDER BY t.CreatedAt DESC
        ) LOOP
    
            IF v_first = 0 THEN
                p_result := p_result || ',';
            END IF;
            v_first := 0;
    
            p_result := p_result || 
                '{' ||
                '"id":' || rec.ID || ',' ||
                '"offer_id":' || rec.OfferID || ',' ||
                '"user_id":' || NVL(TO_CHAR(rec.UserID), 'null') || ',' ||
                '"type_id":' || rec.Type || ',' ||
                '"status_id":' || rec.Status || ',' ||
                '"amount":' || TO_CHAR(rec.Amount) || ',' ||
                '"currency":"' || NVL(rec.Currency, '') || '",' ||
                '"created_at":"' || TO_CHAR(rec.CreatedAt, 'YYYY-MM-DD"T"HH24:MI:SS TZH:TZM') || '",' ||
                '"completed_at":"' || 
                    CASE 
                        WHEN rec.CompletedAt IS NOT NULL 
                        THEN '"' || TO_CHAR(rec.CompletedAt, 'YYYY-MM-DD"T"HH24:MI:SS TZH:TZM') || '"'
                        ELSE 'null' 
                    END || '",' ||
                '"payment_method":"' || NVL(rec.PaymentMethod, '') || '",' ||
                '"external_transaction_id":"' || NVL(rec.ExternalTransactionId, '') || '"' ||
                '}';
    
        END LOOP;
    
        p_result := p_result || '] }';
    
    EXCEPTION
        WHEN OTHERS THEN
            p_result := '{ "status": "error", "message": "Internal error" }';
    END;

    PROCEDURE get_transaction_by_id(
        p_admin_id       IN NUMBER,
        p_transaction_id IN NUMBER,
        p_result         OUT CLOB
    ) IS
        v_cnt NUMBER;
    BEGIN
        p_result := NULL;
        check_admin_access(p_admin_id);
        -- Получение транзакции
        FOR t IN (
            SELECT
                ID,
                OfferID,
                UserID,
                TYPE,
                Status,
                Amount,
                Currency,
                CreatedAt,
                CompletedAt,
                PaymentMethod,
                ExternalTransactionId
            FROM Transactions
            WHERE ID = p_transaction_id
        ) LOOP
    
            p_result :=
                '{' ||
                '"status":"success",' ||
                '"transaction":{' ||
                '"id":' || t.ID || ',' ||
                '"offer_id":' || t.OfferID || ',' ||
                '"user_id":' || NVL(TO_CHAR(t.UserID), 'null') || ',' ||
                '"type_id":' || t.TYPE || ',' ||
                '"status_id":' || t.Status || ',' ||
                '"amount":' || TO_CHAR(t.Amount) || ',' ||
                '"currency":"' || NVL(t.Currency, '') || '",' ||
                '"created_at":"' || TO_CHAR(t.CreatedAt, 'YYYY-MM-DD"T"HH24:MI:SS TZH:TZM') || '",' ||
                '"completed_at":' ||
                    CASE
                        WHEN t.CompletedAt IS NOT NULL THEN
                            '"' || TO_CHAR(t.CompletedAt, 'YYYY-MM-DD"T"HH24:MI:SS TZH:TZM') || '"'
                        ELSE 'null'
                    END || ',' ||
                '"payment_method":"' || NVL(REPLACE(t.PaymentMethod, '"', '\"'), '') || '",' ||
                '"external_transaction_id":"' || NVL(REPLACE(t.ExternalTransactionId, '"', '\"'), '') || '"' ||
                '}' ||
                '}';
            RETURN;
        END LOOP;
    
        -- Если транзакция не найдена
        IF p_result IS NULL THEN
            p_result := '{ "status": "error", "message": "Transaction not found" }';
        END IF;
    
    EXCEPTION
        WHEN OTHERS THEN
            p_result := '{ "status": "error", "message": "Internal error" }';
            DBMS_OUTPUT.PUT_LINE('Error in get_transaction_by_id: ' || SQLERRM);
    END get_transaction_by_id;


END admin_pkg;
/

GRANT EXECUTE ON app_user.admin_pkg TO ADMIN;