

CREATE PLUGGABLE DATABASE kpdb_gameStore
    ADMIN USER gs_admin IDENTIFIED by &&kp_PDB_PASSWORD
    ROLES = (dba)
    FILE_NAME_CONVERT = (
      '/opt/oracle/oradata/ORCLCDB/pdbseed/',
      '/opt/oracle/oradata/ORCLCDB/gsdb/'
    );
    
ALTER PLUGGABLE DATABASE kpdb_gameStore OPEN;
ALTER PLUGGABLE DATABASE kpdb_gameStore SAVE STATE;

ALTER SESSION set CONTAINER  =  kpdb_gameStore;


create tablespace gs_data
    datafile '/opt/oracle/oradata/ORCLCDB/gsdb/gs_data01.dbf'
    size 500m
    autoextend on  next 50m
    maxsize  UNLIMITED
    EXTENT MANAGEMENT LOCAL;
    
create tablespace gs_index
    datafile '/opt/oracle/oradata/ORCLCDB/gsdb/gs_index01.dbf'
    size 250m
    autoextend on next 100m
    maxsize UNLIMITED
    EXTENT MANAGEMENT LOCAL; 
    
Create TEMPORARY tablespace gs_temp
    tempfile '/opt/oracle/oradata/ORCLCDB/gsdb/gs_temp01.dbf'
    size 200M
    AUTOEXTEND ON NEXT 50M
    MAXSIZE 1G
    EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M;
    
create UNDO tablespace gs_undo
    datafile '/opt/oracle/oradata/ORCLCDB/gsdb/gs_undo01.dbf'
    SIZE 250M
    AUTOEXTEND ON NEXT 50M
    maxsize 1G;