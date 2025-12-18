
--21

CREATE or REPLACE SYNONYM user_pkg FOR app_user.user_pkg;

DECLARE
    v_response CLOB;
    v_user_id NUMBER :=21;
BEGIN



    user_pkg.get_profile(v_user_id, v_response);
    DBMS_OUTPUT.PUT_LINE('Get profile: ' || v_response);


    user_pkg.update_email(v_user_id, 'newemail@example.com', v_response);
    DBMS_OUTPUT.PUT_LINE('Update email: ' || v_response);
    

    user_pkg.update_nickname(v_user_id, 'NewNick', v_response);
    DBMS_OUTPUT.PUT_LINE('Update nickname: ' || v_response);


    user_pkg.update_password(v_user_id, 'anton2005', 'newpass456', v_response);
    DBMS_OUTPUT.PUT_LINE('Update password: ' || v_response);

    user_pkg.get_profile(v_user_id, v_response);
    DBMS_OUTPUT.PUT_LINE('Get profile: ' || v_response);


    user_pkg.update_profile(v_user_id, 'http://example.com/avatar.png', 'Netherlands', v_response);
    --DBMS_OUTPUT.PUT_LINE('Update profile: ' || v_response);


    user_pkg.add_balance_transaction(
        p_user_id => v_user_id,
        p_amount => 100,
        p_payment_method => 'CreditCard',
        p_response => v_response
    );
    DBMS_OUTPUT.PUT_LINE(v_response);
    
    user_pkg.get_profile(v_user_id, v_response);
    DBMS_OUTPUT.PUT_LINE('Get profile after deactivation: ' || v_response);
END;


DECLARE
    v_response CLOB;
    v_user_id NUMBER :=21;
BEGIN

        user_pkg.add_balance_transaction(
        p_user_id => v_user_id,
        p_amount => 100,
        p_payment_method => 'CreditCard',
        p_response => v_response
    );
    DBMS_OUTPUT.PUT_LINE(v_response);

END;


DECLARE
    v_response CLOB;
    v_user_id NUMBER :=21;
BEGIN
    user_pkg.get_profile(v_user_id, v_response);
    DBMS_OUTPUT.PUT_LINE('Get profile after deactivation: ' || v_response);
END;





DECLARE 
    V_res CLOB;
BEGIN

    user_pkg.get_game_pages_filtered(
    p_response => V_res);

    app_user.print_clob(V_res);
END;


DECLARE 
    V_res CLOB;
BEGIN

    user_pkg.get_game_pages_filtered(
    p_developer_id => 7,
    p_order_dir => 'ASC',
    p_title_search => 'Game_16',
    p_response => V_res);

    app_user.print_clob(V_res);
END;

DECLARE 
    v_res clob;
    v_num NUMBER :=21;
BEGIN

    user_pkg.get_game_page(16,21,'127.0.0.1','Opera',v_res);

    dbms_output.put_line(v_res);
END;


DECLARE 
    v_res clob;
    v_num NUMBER :=21;
BEGIN

    user_pkg.download_free_offer(21,3,v_res);

    dbms_output.put_line(v_res);
END;


DECLARE 
    v_res clob;
    v_user NUMBER :=21;
    v_game_page NUMBER :=3;
BEGIN
    user_pkg.set_game_review(v_user, v_game_page, 4, 'some comment34', v_res);

    dbms_output.put_line(v_res);
END;


DECLARE 
    v_res clob;
    v_user NUMBER :=21;

BEGIN
    user_pkg.get_user_library(v_user, v_res);

    dbms_output.put_line(v_res);
END;

commit;

DECLARE 
    v_res clob;
    v_user NUMBER :=5;

BEGIN
    user_pkg.purchase_game_pending(v_user,81,1,NULL, v_res);

    dbms_output.put_line(v_res);
END;
/
commit;
DECLARE 
    v_res clob;
BEGIN
    user_pkg.complete_purchase(41, v_res);

    dbms_output.put_line(v_res);
END;


DECLARE 
    v_res clob;
BEGIN
    user_pkg.get_user_library(21, v_res);

    dbms_output.put_line(v_res);
END;



DECLARE 
    v_res clob;
BEGIN
    user_pkg.download_library_game(21,41, v_res);

    dbms_output.put_line(v_res);
END;

