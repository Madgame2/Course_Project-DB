
CREATE or REPLACE SYNONYM user_pkg FOR app_user.user_pkg;
CREATE or REPLACE SYNONYM developer_pkg FOR app_user.developer_pkg;

--7 dev1

DECLARE
    v_user NUMBER:=7;
    v_res clob;
BEGIN
    developer_pkg.get_all_games(v_user,v_res);
    dbms_output.put_line(v_res);
END;


DECLARE
    v_user NUMBER:=7;
    v_res clob;
BEGIN
    developer_pkg.add_game(v_user,'Machina','http://example.com/emach.zip',34353000,'1.0','Indie',v_res);
    dbms_output.put_line(v_res);
    
    commit;
END;


DECLARE
    v_user NUMBER:=7;
    v_res clob;
BEGIN
    developer_pkg.update_game(v_user,41,'Expedition 33','http://example.com/exp_33.zip',34350000,'1.2','Indie',v_res);
    dbms_output.put_line(v_res);
    
    commit;
END;

DECLARE
    v_user NUMBER :=7;
    v_res clob;
BEGIN

    developer_pkg.add_game_genre(v_user,41,'JRPG',v_res);
    dbms_output.put_line(v_res);
END;


DECLARE
    v_user NUMBER :=7;
    v_res clob;
BEGIN

    developer_pkg.remove_game_genre_by_name(v_user,41,'JRPG',v_res);
    dbms_output.put_line(v_res);
END;

DECLARE
    v_response CLOB;
BEGIN

    developer_pkg.create_game_page(
        p_developer_id => 7,
        p_page_title   => 'machine',
        p_status_id    => APP_USER.enums_pkg.get_gamepage_status_id('Active'),
        p_view_link    => 'https://gamestore.com/Expedi',
        p_output       => v_response
    );

    DBMS_OUTPUT.PUT_LINE('Create Result: ' || v_response);
END;


DECLARE
    v_response CLOB;
BEGIN

    developer_pkg.update_game_page(
        p_developer_id => 7,
        p_page_id      => 41,
        p_page_title   => 'Clair Obscure Expedition 33',
        p_status_id    => APP_USER.enums_pkg.get_gamepage_status_id('Active'),
        p_view_link    => 'https://gamestore.com/Expedition213',
        p_output       => v_response
    );

    DBMS_OUTPUT.PUT_LINE('Update Result: ' || v_response);
END;



DECLARE
    v_response CLOB;
BEGIN

    developer_pkg.add_screenshot(7,61,'https://sotorage/index.jpg',v_response);

    DBMS_OUTPUT.PUT_LINE('Update Result: ' || v_response);
END;

DECLARE
    v_response CLOB;
BEGIN

    developer_pkg.add_screenshot(7,61,'https://sotorage/index.jpg',v_response);

    DBMS_OUTPUT.PUT_LINE('Update Result: ' || v_response);
END;


DECLARE
    v_response CLOB;
    v_screenshot_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'https://cdn.example.com/games/screen_1.jpg',
        'https://cdn.example.com/games/screen_2.jpg',
        'https://cdn.example.com/games/screen_3.jpg'
    );
BEGIN

    developer_pkg.add_screenshots_list(
        p_developer_id => 7,                 
        p_page_id      => 41,                  
        p_screenshots  => v_screenshot_list,  
        p_output       => v_response          
    );


    DBMS_OUTPUT.PUT_LINE(v_response);
END;



DECLARE
    v_response CLOB;
BEGIN

    developer_pkg.delete_screenshot(7,2,v_response);

    DBMS_OUTPUT.PUT_LINE('Update Result: ' || v_response);
END;


DECLARE
    v_response CLOB;
BEGIN

    developer_pkg.get_game_page_details(7,41,v_response);

    DBMS_OUTPUT.PUT_LINE('Update Result: ' || v_response);
END;



DECLARE
    v_response CLOB;

    v_games_in_bundle SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(41); 
BEGIN
    developer_pkg.add_offer(
        p_developer_id => 7,              
        p_page_id      => 81,               
        p_title        => 'Basic Bandle', 
        p_description  => 'Includes Main Game',
        p_price        => 10,
        p_currency     => 'BYN',
        p_game_ids     => v_games_in_bundle,
        p_output       => v_response
    );

    DBMS_OUTPUT.PUT_LINE('Add Offer Result: ' || v_response);
END;
commit;

DECLARE
    v_response CLOB;

    v_updated_games SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST(41); 
BEGIN
    developer_pkg.update_offer(
        p_developer_id => 7,
        p_offer_id     => 21,              
        p_title        => 'Ultimate Collection',
        p_description  => 'Now includes DLC and Soundtrack',
        p_price        => 300,          
        p_currency     => 'BYN',
        p_game_ids     => v_updated_games, 
        p_output       => v_response
    );

    DBMS_OUTPUT.PUT_LINE('Update Offer Result: ' || v_response);
END;
commit;

DECLARE
    v_response CLOB;
BEGIN
    developer_pkg.delete_offer(7,81,v_response);

    DBMS_OUTPUT.PUT_LINE('Update Offer Result: ' || v_response);
END;


DECLARE
    v_response CLOB;
BEGIN
    developer_pkg.get_offers_by_page(7,81,v_response);

    DBMS_OUTPUT.PUT_LINE('Update Offer Result: ' || v_response);
END;


DECLARE
    v_response CLOB;
BEGIN
    developer_pkg.delete_game_page(7,61,v_response);

    DBMS_OUTPUT.PUT_LINE('Update Offer Result: ' || v_response);
END;

DECLARE
    v_response CLOB;
BEGIN

    developer_pkg.get_game_page_reviews(
        p_developer_id => 9,
        p_page_id      => 3,
        p_output       => v_response
    );
    
    DBMS_OUTPUT.PUT_LINE(v_response);
END;

commit;