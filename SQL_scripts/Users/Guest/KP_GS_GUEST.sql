
CREATE or REPLACE SYNONYM guest_pkg FOR app_user.guest_pkg;


DECLARE
    v_response CLOB;
BEGIN
    guest_pkg.register_guest(
        p_username => 'xFrorezent',
        p_email    => 'xfrorexemt@mail.com',
        p_password => 'anton2005',
        p_response => v_response
    );

    dbms_output.put_line(v_response);
END;
commit;

DECLARE
    v_response CLOB;
BEGIN
    guest_pkg.TryDownload(
        p_offer_id    => 1,
        p_response => v_response
    );

    dbms_output.put_line(v_response);
END;

rollback;




DECLARE
    v_response CLOB;
BEGIN
    guest_pkg.get_game_pages_filtered(
        p_developer_id => NULL,
        p_title_search => 'test',
        p_genre_id     => NULL,
        p_order_by     => 'TITLE',
        p_order_dir    => 'ASC',
        p_response     => v_response
    );

    DBMS_OUTPUT.put_line(v_response);
END;

DECLARE
    v_response CLOB;
BEGIN
    guest_pkg.get_game_pages_filtered(
        p_developer_id => NULL,
        p_title_search => NULL,
        p_genre_id     => NULL,
        p_order_by     => 'TITLE',
        p_order_dir    => 'DESC',
        p_response     => v_response
    );

    DBMS_OUTPUT.put_line(v_response);
END;