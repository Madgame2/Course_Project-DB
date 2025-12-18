ALTER SESSION set CONTAINER = CDB$ROOT;
ALTER SESSION set CONTAINER = KPDB_GAMESTORE;

SELECT * from Users;

SELECT
    a.sid,
    a.serial#,
    a.username,
    b.object_name,
    b.object_type,
    c.locked_mode
FROM
    v$session a
JOIN
    v$locked_object c ON a.sid = c.session_id
JOIN
    all_objects b ON c.object_id = b.object_id;


SELECT owner, object_name, object_type, status
FROM all_objects
WHERE object_name = 'GUEST_PKG';

DROP PACKAGE APP_user.GUEST_PKG;
DROP PACKAGE BODY GUEST_PKG;


ALTER PLUGGABLE DATABASE KPDB_GAMESTORE CLOSE IMMEDIATE;

DROP PLUGGABLE DATABASE KPDB_GAMESTORE INCLUDING DATAFILES;