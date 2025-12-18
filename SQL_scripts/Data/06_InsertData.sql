SELECT * from Users;

DECLARE
    v_response CLOB;
    v_role_id NUMBER;
BEGIN

    v_role_id := enums_pkg.get_role_id('Admin');

    guest_pkg.register_guest(
        p_username => 'Admin',
        p_password => 'admin123',   
        p_email    => 'admin@test.com',
        p_response => v_response
    );

    UPDATE Users
    SET RoleID = v_role_id
    WHERE Email = 'admin@test.com';

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Администратор успешно создан: ' || v_response);

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка при создании администратора: ' || SQLERRM);
END;
/



DECLARE
    v_output CLOB;
    v_countries SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'Belarus','Netherlands', 'Germany', 'France', 'Italy', 'Spain', 
        'USA', 'Canada', 'Japan', 'Australia', 'Brazil'
    );
    v_country NVARCHAR2(255);
    v_index NUMBER;
BEGIN
    FOR user_rec IN (SELECT UserID FROM Users) LOOP

        v_index := DBMS_RANDOM.VALUE(1, v_countries.COUNT + 1); -- DBMS_RANDOM.VALUE возвращает NUMBER с дробной частью
        v_country := v_countries(FLOOR(v_index));

        user_pkg.update_profile(
            p_user_id   => user_rec.UserID,
            p_avatar_uri => NULL,  -- можно задать урл аватара или оставить NULL
            p_country    => v_country,
            p_response   => v_output
        );

        DBMS_OUTPUT.PUT_LINE('Пользователь ID=' || user_rec.UserID || ' обновлен, страна: ' || v_country);
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Профили всех пользователей обновлены.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка при обновлении профилей: ' || SQLERRM);
        ROLLBACK;
END;

DECLARE
    v_output CLOB;
    v_status_id NUMBER := enums_pkg.get_gamepage_status_id('Active'); 
    v_total_games NUMBER := 25; -- Общее количество игр для всех разработчиков
    v_dev_count NUMBER := 0;
    v_devs SYS.ODCINUMBERLIST; -- Список ID разработчиков
BEGIN

    SELECT UserID BULK COLLECT INTO v_devs
    FROM Users u
    JOIN Roles r ON u.RoleID = r.RoleId
    WHERE r.Role = 'Developer';

    v_dev_count := v_devs.COUNT;

    IF v_dev_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Нет разработчиков для создания игр.');
        RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Всего разработчиков: ' || v_dev_count);
    

    FOR i IN 1..v_total_games LOOP

        DECLARE
            v_developer_id NUMBER;
            v_game_index NUMBER := i;
        BEGIN
            v_developer_id := v_devs(MOD(i-1, v_dev_count) + 1);


            developer_pkg.add_game(
                p_developer_id  => v_developer_id,
                p_game_name     => 'Game_' || i || '_Dev_' || v_developer_id,
                p_download_link => 'http://example.com/game_' || i || '_dev_' || v_developer_id || '.zip',
                p_game_size     => 100 + i*10,  -- МБ
                p_version       => '1.0.' || i,
                p_type          => 'Indie',
                p_output        => v_output
            );
            DBMS_OUTPUT.PUT_LINE('Игра создана: ' || v_output);


            developer_pkg.create_game_page(
                p_developer_id => v_developer_id,
                p_page_title   => 'Page for Game_' || i || '_Dev_' || v_developer_id,
                p_status_id    => v_status_id,
                p_view_link    => 'http://example.com/view/game_' || i || '_dev_' || v_developer_id,
                p_output       => v_output
            );
            DBMS_OUTPUT.PUT_LINE('Страница игры создана: ' || v_output);
        END;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Все игры равномерно распределены по разработчикам.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка при создании игр: ' || SQLERRM);
END;

commit;

DECLARE
    v_output CLOB;
    v_offer_count NUMBER;
    v_game_count NUMBER;
    v_game_ids SYS.ODCINUMBERLIST;
    v_developer_id NUMBER;
    v_games SYS.ODCINUMBERLIST;
BEGIN

    FOR dev_rec IN (
        SELECT u.UserID
        FROM Users u
        JOIN Roles r ON u.RoleID = r.RoleId
        WHERE r.Role = 'Developer'
    ) LOOP
        v_developer_id := dev_rec.UserID;


        v_games := SYS.ODCINUMBERLIST();
        FOR g IN (SELECT GameID FROM Games WHERE DeveloperID = v_developer_id) LOOP
            v_games.EXTEND;
            v_games(v_games.COUNT) := g.GameID;
        END LOOP;

        -- Проходим по всем страницам разработчика
        FOR page_rec IN (SELECT PageID FROM GamePages WHERE DeveloperID = v_developer_id) LOOP
            -- Генерируем случайное количество офферов (0-3)
            v_offer_count := TRUNC(DBMS_RANDOM.VALUE(0,4));

            FOR i IN 1..v_offer_count LOOP
                -- Выбираем случайное количество игр для оффера (1-2)
                v_game_count := LEAST(v_games.COUNT, TRUNC(DBMS_RANDOM.VALUE(1,3)));
                v_game_ids := SYS.ODCINUMBERLIST();

                -- Добавляем случайные игры в оффер
                FOR j IN 1..v_game_count LOOP
                    v_game_ids.EXTEND;
                    v_game_ids(j) := v_games(TRUNC(DBMS_RANDOM.VALUE(1, v_games.COUNT + 1)));
                END LOOP;

                -- Создаём оффер
                developer_pkg.add_offer(
                    p_developer_id => v_developer_id,
                    p_page_id      => page_rec.PageID,
                    p_title        => 'Offer_' || i || '_Page_' || page_rec.PageID,
                    p_description  => 'Description for offer ' || i,
                    p_price        => 0,
                    p_currency     => 'BYN',
                    p_game_ids     => v_game_ids,
                    p_output       => v_output
                );

                DBMS_OUTPUT.PUT_LINE('Создан оффер: ' || v_output);
            END LOOP;
        END LOOP;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Все офферы для разработчиков созданы.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка при создании офферов: ' || SQLERRM);
        ROLLBACK;
END;

DECLARE
    v_output CLOB;
BEGIN
    -- Проходим по всем обычным пользователям
    FOR user_rec IN (
        SELECT u.UserID
        FROM Users u
        JOIN Roles r ON u.RoleID = r.RoleId
        WHERE r.Role = 'User'  -- обычные пользователи
    ) LOOP
        -- Для каждого пользователя проходим по всем офферам
        FOR offer_rec IN (SELECT OfferID FROM Offers) LOOP
            user_pkg.download_free_offer(
                p_user_id => user_rec.UserID,
                p_offer_id => offer_rec.OfferID,
                p_response => v_output
            );

            DBMS_OUTPUT.PUT_LINE('Пользователь ID=' || user_rec.UserID ||
                                 ' скачал оффер ID=' || offer_rec.OfferID ||
                                 ', ответ: ' || v_output);
        END LOOP;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Все обычные пользователи скачали офферы.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ошибка при скачивании офферов: ' || SQLERRM);
        ROLLBACK;
END;

commit;







DECLARE
    v_output CLOB;

    -- Коллекции пользователей и офферов
    TYPE t_users  IS TABLE OF Users.UserID%TYPE;
    TYPE t_offers IS TABLE OF Offers.OfferID%TYPE;

    v_users  t_users;
    v_offers t_offers;

    v_user_id  Users.UserID%TYPE;
    v_offer_id Offers.OfferID%TYPE;
BEGIN
    /* Загружаем всех обычных пользователей */
    SELECT u.UserID
    BULK COLLECT INTO v_users
    FROM Users u
    JOIN Roles r ON u.RoleID = r.RoleID
    WHERE r.Role = 'User';

    /* Загружаем все бесплатные офферы */
    SELECT o.OfferID
    BULK COLLECT INTO v_offers
    FROM Offers o
    WHERE o.Price = 0;   -- если у тебя признак бесплатности другой — поменяй

    IF v_users.COUNT = 0 OR v_offers.COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Нет пользователей или бесплатных офферов');
    END IF;

    /* 100 000 скачиваний */
    FOR i IN 1 .. 100000 LOOP
        v_user_id :=
            v_users(TRUNC(DBMS_RANDOM.VALUE(1, v_users.COUNT + 1)));

        v_offer_id :=
            v_offers(TRUNC(DBMS_RANDOM.VALUE(1, v_offers.COUNT + 1)));

        user_pkg.download_free_offer(
            p_user_id  => v_user_id,
            p_offer_id => v_offer_id,
            p_response => v_output
        );

        -- выводить каждую итерацию НЕ рекомендуется (очень медленно)
        IF MOD(i, 1000) = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Выполнено скачиваний: ' || i);
        END IF;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Готово: выполнено 100000 скачиваний.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Ошибка: ' || SQLERRM);
END;
/





SELECT * from UserActivity;

SELECT * from Gamepages;

SELECT * from Offers;

SELECT * from GAMES;