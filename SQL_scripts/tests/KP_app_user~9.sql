
SELECT * from Roles;

DEClARE
    v_res CLOB;
BEGIN

    stat_pkg.get_user_statistics(1,4,v_res);
    print_clob(v_res);
    
EXCEPTION
    when OTHERS  then
    
    dbms_output.put_line(SQLERRM);
END;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR);