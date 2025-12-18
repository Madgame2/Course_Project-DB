

INSERT INTO Roles (Role)
VALUES ('User');
INSERT INTO Roles (Role)
VALUES ('Developer');
INSERT INTO Roles (Role)
VALUES ('Admin');

Select * from ActionTypes;

INSERT INTO Transction_statuses (status) VALUES ('Pending');
INSERT INTO Transction_statuses (status) VALUES ('Completed');
INSERT INTO Transction_statuses (status) VALUES ('Failed');
INSERT INTO Transction_statuses (status) VALUES ('Cancelled');

INSERT INTO TransctionType (Type) VALUES ('Deposit');
INSERT INTO TransctionType (Type) VALUES ('Withdrawal');
INSERT INTO TransctionType (Type) VALUES ('Transfer');
INSERT INTO TransctionType (Type) VALUES ('Payment');

-- Действия
INSERT INTO ActionTypes(Type) VALUES('ViewPage');    -- 1
INSERT INTO ActionTypes(Type) VALUES('Like');        -- 2
INSERT INTO ActionTypes(Type) VALUES('Download');    -- 3
INSERT INTO ActionTypes(Type) VALUES('Purchase');    -- 4
INSERT INTO ActionTypes(Type) VALUES('CreateNew');    -- 5
INSERT INTO ActionTypes(Type) VALUES('Added');
INSERT INTO ActionTypes(Type) VALUES('Updated');  -- 6

INSERT INTO EntityTypes(EntityName) VALUES('Game');       -- 1
INSERT INTO EntityTypes(EntityName) VALUES('Offer');      -- 2
INSERT INTO EntityTypes(EntityName) VALUES('GamePage');   -- 3
INSERT INTO EntityTypes(EntityName) VALUES('User');       -- 4

INSERT INTO GamePagesStatuses (Status) VALUES ('Active');
INSERT INTO GamePagesStatuses (Status) VALUES ('Hidden');

commit;

CREATE OR REPLACE PACKAGE enums_pkg IS
    
    FUNCTION get_gamepage_status_id(p_status IN NVARCHAR2) RETURN NUMBER;
    
    -- Получить RoleID по имени роли
    FUNCTION get_role_id(p_role IN NVARCHAR2) RETURN NUMBER;

    -- Получить ID статуса транзакции
    FUNCTION get_transaction_status_id(p_status IN NVARCHAR2) RETURN NUMBER;

    -- Получить ID типа транзакции
    FUNCTION get_transaction_type_id(p_type IN NVARCHAR2) RETURN NUMBER;

    -- Получить ID типа действия
    FUNCTION get_action_type_id(p_type IN NVARCHAR2) RETURN NUMBER;

    -- Получить ID типа сущности
    FUNCTION get_entity_type_id(p_entity_name IN NVARCHAR2) RETURN NUMBER;

END enums_pkg;
/

GRANT EXECUTE ON app_user.enums_pkg TO DEveloper;
GRANT EXECUTE ON app_user.enums_pkg TO GUEST;
GRANT EXECUTE ON app_user.enums_pkg TO ADMIN;
GRANT EXECUTE ON app_user.enums_pkg TO GUEST;

CREATE OR REPLACE PACKAGE BODY enums_pkg IS


    FUNCTION get_gamepage_status_id(p_status IN NVARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT StatusID INTO v_id
        FROM GamePagesStatuses
        WHERE Status = p_status;

        RETURN v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL; 
    END get_gamepage_status_id;
    
    
    FUNCTION get_role_id(p_role IN NVARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT RoleId INTO v_id FROM Roles WHERE Role = p_role;
        RETURN v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_role_id;

    FUNCTION get_transaction_status_id(p_status IN NVARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT id INTO v_id FROM Transction_statuses WHERE status = p_status;
        RETURN v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_transaction_status_id;

    FUNCTION get_transaction_type_id(p_type IN NVARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT ID INTO v_id FROM TransctionType WHERE Type = p_type;
        RETURN v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_transaction_type_id;

    FUNCTION get_action_type_id(p_type IN NVARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT ActionType INTO v_id FROM ActionTypes WHERE Type = p_type;
        RETURN v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_action_type_id;

    FUNCTION get_entity_type_id(p_entity_name IN NVARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT TypeID INTO v_id FROM EntityTypes WHERE EntityName = p_entity_name;
        RETURN v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_entity_type_id;

END enums_pkg;