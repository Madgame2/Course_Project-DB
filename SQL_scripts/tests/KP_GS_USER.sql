
CREATE or REPLACE SYNONYM user_pkg FOR app_user.user_pkg;


DECLARE
    v_response CLOB;
    v_user_id NUMBER :=41;
BEGIN



    --user_pkg.get_profile(v_user_id, v_response);
    DBMS_OUTPUT.PUT_LINE('Get profile: ' || v_response);


    --user_pkg.update_email(v_user_id, 'newemail@example.com', v_response);
    DBMS_OUTPUT.PUT_LINE('Update email: ' || v_response);
    

    --user_pkg.update_nickname(v_user_id, 'NewNick', v_response);
    DBMS_OUTPUT.PUT_LINE('Update nickname: ' || v_response);


    --user_pkg.update_password(v_user_id, 'anton2005', 'newpass456', v_response);
    DBMS_OUTPUT.PUT_LINE('Update password: ' || v_response);

    --user_pkg.get_profile(v_user_id, v_response);
    DBMS_OUTPUT.PUT_LINE('Get profile: ' || v_response);


    --user_pkg.update_profile(v_user_id, 'http://example.com/avatar.png', 'Netherlands', v_response);
    --DBMS_OUTPUT.PUT_LINE('Update profile: ' || v_response);


    user_pkg.add_balance_transaction(
        p_user_id => v_user_id,
        p_amount => 50,
        p_payment_method => 'CreditCard',
        p_response => v_response
    );
    DBMS_OUTPUT.PUT_LINE(v_response);
    
    user_pkg.get_profile(v_user_id, v_response);
    DBMS_OUTPUT.PUT_LINE('Get profile after deactivation: ' || v_response);



END;
/
commit;

rollback;