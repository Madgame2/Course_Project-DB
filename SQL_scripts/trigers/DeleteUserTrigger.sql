

CREATE OR REPLACE TRIGGER trg_users_archive_on_delete
BEFORE DELETE ON Users
FOR EACH ROW
DECLARE
    v_ghost_id NUMBER;
    v_role_id  NUMBER;
BEGIN

    BEGIN
        SELECT UserID INTO v_ghost_id 
        FROM Users 
        WHERE Email = N'deleted@system.local'
        FETCH FIRST 1 ROW ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN

            BEGIN
                SELECT RoleId INTO v_role_id FROM Roles WHERE Role = N'System';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    INSERT INTO Roles (Role) VALUES (N'System') RETURNING RoleId INTO v_role_id;
            END;

            INSERT INTO Users (Email, NickName, PasswordHash, RoleID, IsActive, Balance)
            VALUES (N'deleted@system.local', N'Deleted User', 'N/A', v_role_id, 0, 0)
            RETURNING UserID INTO v_ghost_id;
    END;


    IF :OLD.UserID = v_ghost_id THEN
        RAISE_APPLICATION_ERROR(-20001, 'Удаление системного архивного пользователя запрещено.');
    END IF;


    UPDATE Games SET DeveloperID = v_ghost_id WHERE DeveloperID = :OLD.UserID;
    

    UPDATE GamePages SET developerId = v_ghost_id WHERE developerId = :OLD.UserID;
    

    UPDATE Transactions SET UserID = v_ghost_id WHERE UserID = :OLD.UserID;


    UPDATE Reports SET ReportFrom_UserId = v_ghost_id WHERE ReportFrom_UserId = :OLD.UserID;
    UPDATE Reports SET ReportTo_UserID = v_ghost_id WHERE ReportTo_UserID = :OLD.UserID;

    DELETE FROM Folowers WHERE UserId = :OLD.UserID;
    DELETE FROM Libraries WHERE userId = :OLD.UserID;
    DELETE FROM UserActivity WHERE UserID = :OLD.UserID;

END;
/