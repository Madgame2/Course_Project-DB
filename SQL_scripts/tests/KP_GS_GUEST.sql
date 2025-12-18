
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
        p_offer_id   => 1,
        p_order_dir => 'DESC',
        p_response => v_response
    );

    dbms_output.put_line(v_response);
END;