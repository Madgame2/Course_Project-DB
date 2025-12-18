
CREATE or REPLACE SYNONYM admin_pkg FOR app_user.admin_pkg;
CREATE or REPLACE SYNONYM stat_pkg FOR app_user.stat_pkg;






DECLARE
    v_user NUmber:=4;
BEGIN
    admin_pkg.change_user_role(1,v_user, app_user.enums_pkg.get_role_id('Developer'));
END;



DEClARE
    v_res CLOB;
BEGIN

    stat_pkg.get_user_statistics(1,4,v_res);
    app_user.print_clob(v_res);
    
EXCEPTION
    when OTHERS  then
    
    dbms_output.put_line(SQLERRM);
END;

DEClARE
    v_res CLOB;
BEGIN

    stat_pkg.get_games_statistics(1,20,v_res);
    app_user.print_clob(v_res);
    
EXCEPTION
    when OTHERS  then
    
    dbms_output.put_line(SQLERRM);
END;

DEClARE
    v_res CLOB;
BEGIN

    stat_pkg.get_top_genres_by_countries(1,v_res);
    app_user.print_clob(v_res);
    
EXCEPTION
    when OTHERS  then
    
    dbms_output.put_line(SQLERRM);
END;

DEClARE
    v_res CLOB;
BEGIN

    stat_pkg.get_top_games_by_followers(
            p_user_id => 1, 
            p_result  => v_res
        );
    app_user.print_clob(v_res);
    
EXCEPTION
    when OTHERS  then
    
    dbms_output.put_line(SQLERRM);
END;