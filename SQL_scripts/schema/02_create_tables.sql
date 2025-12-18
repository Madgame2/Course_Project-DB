ALTER SESSION set container  = KPDB_GAMESTORE;


--SELECT * from user_tablespaces;

--DROP TABLE TRANSCTION_STATUSES;
--DROP TABLE TransctionType;
--DROP TABLE GamePagesStatuses;
--DROP TABLE Geners;
--DROP TABLE ActionTypes;
--DROP TABLE EntityTypes;
--DROP TABLE Roles;
--DROP TABLE Users;
--DROP TABLE UserActivity;
--DROP TABLE Games;
--DROP TABLE Screenshots;
--DROP TABLE GamePages;
--DROP TABLE Reports;
--DROP TABLE Offers;
--DROP TABLE Transactions;
--DROP TABLE Libraries;
--DROP TABLE OfferGameLinks;
--DROP TABLE Folowers;

--ENUMS
create TABLE Transction_statuses 
(
    id NUMBER GENERATED ALWAYS AS IDENTITY,
    status VARCHAR(125), 
    
    CONSTRAINT PK_tr_staruses PRIMARY KEY (id)
        USING INDEX TABLESPACE GS_INDEX
)
TABLESPACE GS_DATA;

CREATE TABLE TransctionType 
(
    ID NUMBER GENERATED ALWAYS AS IDENTITY,
    Type VARCHAR(125), 
    
    CONSTRAINT PK_tr_Type PRIMARY KEY (ID)
        USING INDEX TABLESPACE GS_INDEX
)
TABLESPACE GS_DATA;

CREATE TABLE GamePagesStatuses  (
    StatusID  NUMBER GENERATED ALWAYS AS IDENTITY,
    Status  VARCHAR(125),
    
    CONSTRAINT PK_gp_statuses PRIMARY KEY(StatusID)
        USING INDEX TABLESPACE GS_INDEX
)
TABLESPACE GS_DATA;

CREATE TABLE Geners 
(
    genreId  NUMBER GENERATED ALWAYS AS IDENTITY,
    genre NVARCHAR2(255),
    
    CONSTRAINT PK_Geners PRIMARY KEY(genreId)
        USING INDEX TABLESPACE GS_INDEX
)
TABLESPACE GS_DATA; 

CREATE TABLE ActionTypes (
    ActionType NUMBER GENERATED ALWAYS AS IDENTITY,
    Type VARCHAR2(125),
    
    CONSTRAINT PK_AT PRIMARY KEY(ActionType)
        USING INDEX TABLESPACE GS_INDEX 
)
TABLESPACE GS_DATA ;

CREATE TABLE EntityTypes (
    TypeID NUMBER GENERATED ALWAYS AS IDENTITY,
    EntityName VARCHAR(125),
    
    CONSTRAINT PK_ET PRIMARY KEY(TypeID)
        USING INDEX TABLESPACE GS_INDEX
)
TABLESPACE GS_DATA;

CREATE TABLE Roles (
    RoleId NUMBER GENERATED ALWAYS AS IDENTITY,
    Role NVARCHAR2(255), 
    
    CONSTRAINT PK_Roles PRIMARY KEY (RoleId)
        USING INDEX TABLESPACE GS_INDEX
)
TABLESPACE GS_DATA; 








CREATE TABLE Users (
    UserID           NUMBER GENERATED ALWAYS AS IDENTITY,
    Email            NVARCHAR2(255) NOT NULL UNIQUE,
    NickName         NVARCHAR2(255)  NOT NULL UNIQUE,
    PasswordHash     NVARCHAR2(255) NOT NULL,
    RoleID           NUMBER        NOT NULL,
    CreatedAt        TIMESTAMP WITH TIME ZONE   DEFAULT CURRENT_DATE NOT NULL,
    LastLogIn        TIMESTAMP WITH TIME ZONE,
    IsActive         NUMBER(1) DEFAULT 1,
    Avatar_uri       NVARCHAR2(255),
    Country          NVARCHAR2(255),
    Balance NUMBER(10,2) DEFAULT 0,
    
    
    CONSTRAINT PK_User PRIMARY KEY(UserID)
        USING INDEX TABLESPACE GS_INDEX,
        
    CONSTRAINT FK_RoleID FOREIGN KEY (RoleID)
        REFERENCES Roles(RoleId)
)
TABLESPACE GS_DATA ;



CREATE TABLE UserActivity 
(
    ID NUMBER GENERATED ALWAYS AS IDENTITY,
    UserID NUMBER NOT NULL,
    ActionType NUMBER NOT NULL,
    EntityType NUMBER NOT NULL,
    EntityID  NUMBER NOT NULL,
    Details NVARCHAR2(255),
    CreatedAt TIMESTAMP WITH TIME ZONE,
    IpAddress VARCHAR2(45),
    UserAgent VARCHAR(512), 
    
    
    CONSTRAINT PK_UA PRIMARY KEY (ID)
        USING INDEX TABLESPACE GS_INDEX,
    
    CONSTRAINT FK_UserID FOREIGN KEY (UserID)
        REFERENCES Users(UserID),
    
    CONSTRAINT FK_ActionType FOREIGN KEY (ActionType)
        REFERENCES ActionTypes(ActionType),
        
     CONSTRAINT FK_EntityType FOREIGN KEY (EntityType)
        REFERENCES EntityTypes(TypeID)
)
TABLESPACE GS_DATA;


CREATE TABLE Games 
(
    GameID NUMBER GENERATED ALWAYS AS IDENTITY,
    DeveloperID NUMBER NOT NULL,
    GameName NVARCHAR2(512),
    DownloadLink VARCHAR(512),
    GameSize NUMBER(20),
    Version VARCHAR2(20),
    type NVARCHAR2(50),
    
    CONSTRAINT PK_Games PRIMARY KEY(GameID)
        USING INDEX TABLESPACE GS_INDEX,
        
    CONSTRAINT FK_DeveloperID FOREIGN KEY (DeveloperID)
        REFERENCES Users(UserID)
)
TABLESPACE GS_DATA;


CREATE TABLE Screenshots(
    id NUMBER GENERATED ALWAYS AS IDENTITY,
    GamePageID number not null,
    screenshotLink VARCHAR(512),
    
    CONSTRAINT PK_SShots PRIMARY KEY(id)
        USING INDEX TABLESPACE GS_INDEX,

    CONSTRAINT FK_gameID FOREIGN KEY (GamePageID)
        REFERENCES GamePages(PageID)
)
TABLESPACE GS_DATA;

CREATE TABLE GamePages (
    PageID NUMBER GENERATED ALWAYS AS IDENTITY,
    developerId NUMBER not NULL,
    Status NUMBER not null,
    PageTittle NVARCHAR2(512),
    ViewLink  VARCHAR(512),
    
    CONSTRAINT PK_GamePages_GP PRIMARY KEY(PageID)
        USING INDEX TABLESPACE GS_INDEX,
        
    CONSTRAINT FK_GamePages_developerId FOREIGN KEY(developerId)
        REFERENCES Users(UserID),
    
    CONSTRAINT FK_GamePages_Status FOREIGN KEY (Status)
        REFERENCES GamePagesStatuses(StatusID)
)
TABLESPACE GS_DATA;


CREATE TABLE Reports 
(
    ReportID            NUMBER GENERATED ALWAYS AS IDENTITY,
    ReportFrom_UserId   NUMBER NOT NULL,
    ReportTo_UserID     NUMBER,
    ReportTo_GamePageID NUMBER,
    Tittle              NVARCHAR2(255),
    Message             NVARCHAR2(2000),
    CreatedAt           TIMESTAMP WITH TIME ZONE,
    
    -- PRIMARY KEY
    CONSTRAINT PK_Reports PRIMARY KEY (ReportID)
        USING INDEX TABLESPACE GS_INDEX,
    
    -- CHECK: хотя бы один получатель указан
    CONSTRAINT CHK_Report_Recipient CHECK (
        (ReportTo_UserID IS NOT NULL AND ReportTo_UserID > 0) OR
        (ReportTo_GamePageID IS NOT NULL AND ReportTo_GamePageID > 0)
    ),
    
    -- FOREIGN KEY
    CONSTRAINT FK_ReportFrom_User FOREIGN KEY (ReportFrom_UserId)
        REFERENCES Users(UserID),
    
    CONSTRAINT FK_ReportTo_User FOREIGN KEY (ReportTo_UserID)
        REFERENCES Users(UserID),
    
    CONSTRAINT FK_ReportTo_GamePage FOREIGN KEY (ReportTo_GamePageID)
        REFERENCES GamePages(PageID)
)
TABLESPACE GS_DATA;

CREATE TABLE Offers
(
    OfferId NUMBER GENERATED ALWAYS AS IDENTITY,
    PageID NUMBER not null,
    Tittle NVARCHAR2(512),
    Description NVARCHAR2(1000),
    Price NUMBER(10,2),
    Currency NVARCHAR2(6),
    
    CONSTRAINT PK_Offers PRIMARY KEY (OfferId)
        USING INDEX TABLESPACE GS_INDEX,
        
    CONSTRAINT FK_PageID FOREIGN KEY (PageID)
        REFERENCES GamePages(PageID)
)
TABLESPACE GS_DATA;




CREATE TABLE Transactions 
(
    ID NUMBER GENERATED ALWAYS AS IDENTITY,
    OfferID NUMBER,
    UserID  NUMBER,
    TYPE  NUMBER NOT NULL,
    Status NUMBER NOT NULL,
    Amount NUMBER(10,2) NOT NULL,
    Currency NVARCHAR2(6),
    CreatedAt TIMESTAMP WITH TIME ZONE,
    CompletedAt TIMESTAMP WITH TIME ZONE,
    PaymentMethod NVARCHAR2(125),
    ExternalTransactionId NVARCHAR2(512),
    
    
    CONSTRAINT PK_Transaction PRIMARY KEY (ID)
        USING INDEX TABLESPACE GS_INDEX,
        
    CONSTRAINT FK_Transactions_OfferID FOREIGN KEY(OfferID)
        REFERENCES Offers(OfferId),
        
    CONSTRAINT FK_Transactions_UserID FOREIGN KEY (UserID)
        REFERENCES Users(UserID),
        
    CONSTRAINT FK_Transactions_TYPE FOREIGN KEY (TYPE)
        REFERENCES TransctionType(ID),
        
    CONSTRAINT FK_Transactions_Status FOREIGN KEY(Status)
        REFERENCES Transction_statuses(id)
)
TABLESPACE GS_DATA;




--MANY_To_MANY
CREATE TABLE Libraries
(
    userId NUMBER NOT NULL,
    gameIid  NUMBER NOT NULL,
    BoughtIn TIMESTAMP WITH TIME ZONE, 
    
    CONSTRAINT PK_LIB PRIMARY KEY(userId, gameIid)
        USING INDEX TABLESPACE GS_INDEX,
    
    CONSTRAINT FK_Libraries_userID FOREIGN KEY(userId)
        REFERENCES Users(UserID),
        
    CONSTRAINT FK_Libraries_gameID FOREIGN KEY(gameIid)
        references Games(GameID)
)
TABLESPACE GS_DATA;

CREATE TABLE OfferGameLinks
(
    OfferId  NUMBER  NOT NULL,
    GameID  NUMBER NOT NULL,
    
    CONSTRAINT PK_OGL PRIMARY KEY (OfferId,GameID)
        USING INDEX TABLESPACE GS_INDEX,
        
    CONSTRAINT FK_OfferGameLinks_OfferId FOREIGN KEY (OfferId)
        REFERENCES Offers(OfferId),
    
    CONSTRAINT FK_OfferGameLinks_GameID FOREIGN KEY(GameID)
        REFERENCES Games(GameID)
)
TABLESPACE GS_DATA;



CREATE  TABLE Folowers (
    GamePageId NUMBER NOT NULL,
    UserId NUMBER NOT NULL,
    Rating NUMBER(1) CHECK (Rating BETWEEN 1 AND 5),
    ReviewComment VARCHAR2(2000),
    
    CONSTRAINT PK_Folowers PRIMARY KEY (GamePageId,UserId)
        USING INDEX TABLESPACE GS_INDEX,
        
    CONSTRAINT FK_Folowers_GamePageId FOREIGN KEY (GamePageId)
        REFERENCES GamePages(PageID),
    
    CONSTRAINT FK_Folowers_UserId FOREIGN KEY (UserId)
        REFERENCES Users(UserID)
)
TABLESPACE GS_DATA;

CREATE TABLE Games_ganers
(
    GameID NUMBER NOT NULL,
    Ganer_ID number NOT NULL,
    
    CONSTRAINT PK_Games_ganers PRIMARY KEY (GameID,Ganer_ID)
    USING INDEX TABLESPACE GS_INDEX,
    
    CONSTRAINT FK_Games_ganers_GameID FOREIGN KEY (GameID)
        REFERENCES Games(GameID),
    
    CONSTRAINT FK_Games_ganers_Ganer_ID FOREIGN KEY (Ganer_ID)
        REFERENCES Geners(genreId)
)
TABLESPACE GS_DATA;