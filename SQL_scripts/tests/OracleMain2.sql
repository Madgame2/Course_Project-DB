SELECT parameter, value
FROM v$option
WHERE parameter = 'In-Memory Column Store';


SHOW PARAMETER INMEMORY_SIZE;

SELECT name, value FROM v$parameter
WHERE name IN ('sga_target','sga_max_size','inmemory_size');

ALTER SYSTEM SET SGA_MAX_SIZE = 6G SCOPE=SPFILE;
ALTER SYSTEM SET SGA_TARGET = 3G SCOPE=SPFILE;

ALTER SYSTEM SET INMEMORY_SIZE = 2560M SCOPE=SPFILE;

SHOW PARAMETER SGA;


SELECT table_name, inmemory, inmemory_priority
FROM user_tables
WHERE inmemory = 'ENABLED';