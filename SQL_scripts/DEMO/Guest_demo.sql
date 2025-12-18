

DECLARE 
    V_res CLOB;
BEGIN

    guest_pkg.get_game_pages_filtered(
    p_response => V_res);

    app_user.print_clob(V_res);
END;


DECLARE 
    V_res CLOB;
BEGIN

    guest_pkg.get_game_pages_filtered(
    p_developer_id => 7,
    p_order_dir => 'ASC',
    p_title_search => 'Game_16',
    p_response => V_res);

    app_user.print_clob(V_res);
END;


DECLARE 
    V_res CLOB;
BEGIN

    guest_pkg.trydownload(3,V_res);

    app_user.print_clob(V_res);
END;


DECLARE 
    V_res CLOB;
BEGIN

    guest_pkg.register_guest('xfrorezent','anton2005','antonmMail@gmail.com',V_res);

    app_user.print_clob(V_res);
END;

commit;

DECLARE 
    V_res CLOB;
BEGIN

    guest_pkg.login_guest('antonmMail@gmail.com','anton2005',V_res);

    app_user.print_clob(V_res);
END;

commit;