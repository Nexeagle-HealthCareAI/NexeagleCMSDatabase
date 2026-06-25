-- =============================================================================
-- AppDatabase (HMS) Setup Script
-- Run this against the main HMS application database (DefaultConnection).
-- Idempotent: all CREATE statements are guarded with IF OBJECT_ID checks.
-- Tables are created in foreign-key dependency order.
-- =============================================================================

-- Replace with your actual HMS database name, or run after: USE [YourHMSDatabase];
-- USE EasyHMSDB;
-- GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- =============================================================================
-- 1. LOOKUP / REFERENCE TABLES  (no dependencies)
-- =============================================================================

-- ── StatusMaster ──────────────────────────────────────────────────────────────
-- Appointment workflow status codes. Referenced by Appointments.CurrentStatusCode.
IF OBJECT_ID('dbo.StatusMaster', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.StatusMaster (
        StatusCode  NVARCHAR(40)  NOT NULL,
        StatusName  NVARCHAR(200) NULL,
        CONSTRAINT PK_StatusMaster PRIMARY KEY (StatusCode)
    );
    PRINT 'Created table: StatusMaster';
END
ELSE PRINT 'Table already exists: StatusMaster';
GO

-- ── UserStatus ────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.UserStatus', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserStatus (
        UserStatusId INT          NOT NULL IDENTITY(1,1),
        StatusName   NVARCHAR(50) NOT NULL,
        CONSTRAINT PK_UserStatus PRIMARY KEY (UserStatusId)
    );
    PRINT 'Created table: UserStatus';
END
ELSE PRINT 'Table already exists: UserStatus';
GO

-- =============================================================================
-- 2. CORE USER TABLES
-- =============================================================================

-- ── Users ─────────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.Users', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users (
        UserID       UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Users_UserID DEFAULT (NEWID()),
        MobileNumber NVARCHAR(15)     NOT NULL,
        Email        NVARCHAR(150)    NULL,
        UserStatusId INT              NOT NULL,
        CreatedAt    DATETIME2(3)     NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_Users PRIMARY KEY (UserID),
        CONSTRAINT FK_Users_UserStatus FOREIGN KEY (UserStatusId) REFERENCES dbo.UserStatus (UserStatusId)
    );
    PRINT 'Created table: Users';
END
ELSE PRINT 'Table already exists: Users';
GO

-- ── UserProfiles ──────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.UserProfiles', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserProfiles (
        UserProfileID            UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_UserProfiles_UserProfileID DEFAULT (NEWID()),
        UserID                   UNIQUEIDENTIFIER NOT NULL,
        FullName                 NVARCHAR(100)    NOT NULL,
        Gender                   NVARCHAR(20)     NULL,
        Language                 NVARCHAR(20)     NULL,
        ProfilePictureURL        NVARCHAR(255)    NULL,
        EmployeeID               NVARCHAR(50)     NULL,
        DateOfBirth              DATE             NULL,
        BloodGroup               NVARCHAR(10)     NULL,
        AddressLine1             NVARCHAR(255)    NULL,
        AddressLine2             NVARCHAR(255)    NULL,
        City                     NVARCHAR(100)    NULL,
        State                    NVARCHAR(100)    NULL,
        Country                  NVARCHAR(100)    NULL,
        Pincode                  NVARCHAR(10)     NULL,
        EmergencyContactName     NVARCHAR(100)    NULL,
        EmergencyContactNumber   NVARCHAR(20)     NULL,
        ProfileCompletionPercent INT              NOT NULL CONSTRAINT DF_UserProfiles_Completion DEFAULT (0),
        UserStatusId             INT              NOT NULL,
        CreatedAt                DATETIME2(3)     NOT NULL CONSTRAINT DF_UserProfiles_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt                DATETIME2(3)     NOT NULL CONSTRAINT DF_UserProfiles_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_UserProfiles        PRIMARY KEY (UserProfileID),
        CONSTRAINT FK_UserProfiles_User   FOREIGN KEY (UserID)       REFERENCES dbo.Users      (UserID),
        CONSTRAINT FK_UserProfiles_Status FOREIGN KEY (UserStatusId) REFERENCES dbo.UserStatus (UserStatusId)
    );
    PRINT 'Created table: UserProfiles';
END
ELSE PRINT 'Table already exists: UserProfiles';
GO

-- ── UserAuth ──────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.UserAuth', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserAuth (
        UserAuthID          UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_UserAuth_UserAuthID DEFAULT (NEWID()),
        UserID              UNIQUEIDENTIFIER NOT NULL,
        HashedPassword      NVARCHAR(256)    NULL,
        LoginMethod         NVARCHAR(50)     NULL,
        Otp                 NVARCHAR(50)     NULL,
        OtpSentDateTime     DATETIME2(3)     NULL,
        IsOtpUsed           BIT              NOT NULL CONSTRAINT DF_UserAuth_IsOtpUsed           DEFAULT (0),
        FailedLoginAttempts INT              NOT NULL CONSTRAINT DF_UserAuth_FailedLoginAttempts DEFAULT (0),
        IsLocked            BIT              NOT NULL CONSTRAINT DF_UserAuth_IsLocked            DEFAULT (0),
        LastLoginIP         NVARCHAR(100)    NULL,
        LastLoginTime       DATETIME2(3)     NULL,
        OtpExpireAt         DATETIME2(3)     NULL,
        PasswordSetAt       DATETIME2(3)     NULL,
        UserStatusId        INT              NOT NULL,
        CreatedAt           DATETIME2(3)     NOT NULL CONSTRAINT DF_UserAuth_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_UserAuth        PRIMARY KEY (UserAuthID),
        CONSTRAINT FK_UserAuth_User   FOREIGN KEY (UserID)       REFERENCES dbo.Users      (UserID),
        CONSTRAINT FK_UserAuth_Status FOREIGN KEY (UserStatusId) REFERENCES dbo.UserStatus (UserStatusId)
    );
    PRINT 'Created table: UserAuth';
END
ELSE PRINT 'Table already exists: UserAuth';
GO

-- ── UserHistory ───────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.UserHistory', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserHistory (
        UserId       UNIQUEIDENTIFIER NOT NULL,
        UserStatusId INT              NOT NULL,
        UpdatedBy    UNIQUEIDENTIFIER NOT NULL,
        UpdatedDate  DATETIME2(3)     NOT NULL CONSTRAINT DF_UserHistory_UpdatedDate DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_UserHistory        PRIMARY KEY (UserId, UpdatedDate),
        CONSTRAINT FK_UserHistory_User   FOREIGN KEY (UserId)       REFERENCES dbo.Users      (UserID),
        CONSTRAINT FK_UserHistory_Status FOREIGN KEY (UserStatusId) REFERENCES dbo.UserStatus (UserStatusId)
    );
    PRINT 'Created table: UserHistory';
END
ELSE PRINT 'Table already exists: UserHistory';
GO

-- =============================================================================
-- 3. ROLES
-- =============================================================================

-- ── Roles ─────────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.Roles', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Roles (
        RoleID          UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Roles_RoleID DEFAULT (NEWID()),
        HospitalID      UNIQUEIDENTIFIER NULL,
        RoleName        NVARCHAR(100)    NOT NULL,
        Description     NVARCHAR(255)    NULL,
        IsSystemDefined BIT              NOT NULL CONSTRAINT DF_Roles_IsSystemDefined DEFAULT (0),
        IsActive        BIT              NOT NULL CONSTRAINT DF_Roles_IsActive        DEFAULT (1),
        CreatedByUserID UNIQUEIDENTIFIER NULL,
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_Roles_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_Roles PRIMARY KEY (RoleID)
    );
    PRINT 'Created table: Roles';
END
ELSE PRINT 'Table already exists: Roles';
GO

-- ── UserRoles ─────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.UserRoles', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserRoles (
        UserID     UNIQUEIDENTIFIER NOT NULL,
        RoleID     UNIQUEIDENTIFIER NOT NULL,
        HospitalID UNIQUEIDENTIFIER NULL,
        CONSTRAINT PK_UserRoles        PRIMARY KEY (UserID, RoleID),
        CONSTRAINT FK_UserRoles_User   FOREIGN KEY (UserID) REFERENCES dbo.Users (UserID),
        CONSTRAINT FK_UserRoles_Role   FOREIGN KEY (RoleID) REFERENCES dbo.Roles (RoleID)
    );
    PRINT 'Created table: UserRoles';
END
ELSE PRINT 'Table already exists: UserRoles';
GO

-- =============================================================================
-- 4. HOSPITALS
-- =============================================================================

-- ── Hospitals ─────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.Hospitals', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Hospitals (
        HospitalID          UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Hospitals_HospitalID DEFAULT (NEWID()),
        Name                NVARCHAR(150)    NOT NULL,
        [Type]              NVARCHAR(50)     NOT NULL,
        Email               NVARCHAR(150)    NULL,
        Contact             NVARCHAR(20)     NOT NULL,
        AlternateContact    NVARCHAR(20)     NULL,
        Website             NVARCHAR(150)    NULL,
        Location            NVARCHAR(255)    NOT NULL,
        City                NVARCHAR(100)    NOT NULL,
        State               NVARCHAR(100)    NOT NULL,
        Country             NVARCHAR(100)    NOT NULL,
        Pincode             NVARCHAR(10)     NOT NULL,
        TimeZone            NVARCHAR(100)    NULL,
        RegistrationNumber  NVARCHAR(100)    NOT NULL,
        IsActive            BIT              NOT NULL CONSTRAINT DF_Hospitals_IsActive DEFAULT (1),
        CreatedByUserID     UNIQUEIDENTIFIER NOT NULL,
        CreatedAt           DATETIME2(3)     NOT NULL CONSTRAINT DF_Hospitals_CreatedAt     DEFAULT (SYSUTCDATETIME()),
        LastUpdatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_Hospitals_LastUpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_Hospitals PRIMARY KEY (HospitalID)
        -- CreatedByUserID is a soft reference to Users; FK not enforced to allow system-bootstrapped hospitals
    );
    PRINT 'Created table: Hospitals';
END
ELSE PRINT 'Table already exists: Hospitals';
GO

-- ── HospitalProfileStatus ─────────────────────────────────────────────────────
IF OBJECT_ID('dbo.HospitalProfileStatus', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.HospitalProfileStatus (
        HospitalID               UNIQUEIDENTIFIER NOT NULL,
        IsBasicInfoComplete      BIT              NOT NULL CONSTRAINT DF_HPS_BasicInfo    DEFAULT (0),
        IsContactInfoComplete    BIT              NOT NULL CONSTRAINT DF_HPS_ContactInfo  DEFAULT (0),
        IsLocationInfoComplete   BIT              NOT NULL CONSTRAINT DF_HPS_LocationInfo DEFAULT (0),
        ProfileCompletionPercent INT              NOT NULL CONSTRAINT DF_HPS_Completion   DEFAULT (0),
        LastUpdatedAt            DATETIME2(3)     NOT NULL CONSTRAINT DF_HPS_UpdatedAt    DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_HospitalProfileStatus       PRIMARY KEY (HospitalID),
        CONSTRAINT FK_HospitalProfileStatus_Hosp  FOREIGN KEY (HospitalID) REFERENCES dbo.Hospitals (HospitalID) ON DELETE CASCADE
    );
    PRINT 'Created table: HospitalProfileStatus';
END
ELSE PRINT 'Table already exists: HospitalProfileStatus';
GO

-- ── HospitalUsers ─────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.HospitalUsers', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.HospitalUsers (
        HospitalUserID UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_HospitalUsers_ID DEFAULT (NEWID()),
        HospitalID     UNIQUEIDENTIFIER NOT NULL,
        UserID         UNIQUEIDENTIFIER NOT NULL,
        IsPrimary      BIT              NOT NULL CONSTRAINT DF_HospitalUsers_IsPrimary DEFAULT (0),
        EmployeeID     NVARCHAR(50)     NULL,
        CreatedAt      DATETIME2(3)     NOT NULL CONSTRAINT DF_HospitalUsers_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_HospitalUsers           PRIMARY KEY (HospitalUserID),
        CONSTRAINT FK_HospitalUsers_Hospital  FOREIGN KEY (HospitalID) REFERENCES dbo.Hospitals (HospitalID) ON DELETE CASCADE,
        CONSTRAINT FK_HospitalUsers_User      FOREIGN KEY (UserID)     REFERENCES dbo.Users      (UserID)
    );
    PRINT 'Created table: HospitalUsers';
END
ELSE PRINT 'Table already exists: HospitalUsers';
GO

-- =============================================================================
-- 5. DEPARTMENTS & SPECIALIZATIONS
-- =============================================================================

-- ── Departments ───────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.Departments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Departments (
        DepartmentID    UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Departments_DepartmentID DEFAULT (NEWID()),
        HospitalID      UNIQUEIDENTIFIER NULL,
        Name            NVARCHAR(100)    NOT NULL,
        Description     NVARCHAR(255)    NULL,
        IsActive        BIT              NOT NULL CONSTRAINT DF_Departments_IsActive DEFAULT (1),
        CreatedByUserID UNIQUEIDENTIFIER NULL,
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_Departments_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_Departments              PRIMARY KEY (DepartmentID),
        CONSTRAINT FK_Departments_Hospital     FOREIGN KEY (HospitalID) REFERENCES dbo.Hospitals (HospitalID)
    );
    PRINT 'Created table: Departments';
END
ELSE PRINT 'Table already exists: Departments';
GO

-- ── HospitalDepartmentMappings ────────────────────────────────────────────────
IF OBJECT_ID('dbo.HospitalDepartmentMappings', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.HospitalDepartmentMappings (
        MappingID    UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_HDM_MappingID DEFAULT (NEWID()),
        HospitalID   UNIQUEIDENTIFIER NOT NULL,
        DepartmentID UNIQUEIDENTIFIER NOT NULL,
        IsActive     BIT              NOT NULL CONSTRAINT DF_HDM_IsActive DEFAULT (1),
        MappedAt     DATETIME2(3)     NOT NULL CONSTRAINT DF_HDM_MappedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_HospitalDepartmentMappings     PRIMARY KEY (MappingID),
        CONSTRAINT FK_HDM_Hospital                   FOREIGN KEY (HospitalID)   REFERENCES dbo.Hospitals   (HospitalID)   ON DELETE CASCADE,
        CONSTRAINT FK_HDM_Department                 FOREIGN KEY (DepartmentID) REFERENCES dbo.Departments (DepartmentID)
    );
    PRINT 'Created table: HospitalDepartmentMappings';
END
ELSE PRINT 'Table already exists: HospitalDepartmentMappings';
GO

-- ── Specializations ───────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.Specializations', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Specializations (
        SpecializationID UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Specializations_SpecializationID DEFAULT (NEWID()),
        DepartmentID     UNIQUEIDENTIFIER NOT NULL,
        HospitalID       UNIQUEIDENTIFIER NULL,
        Name             NVARCHAR(100)    NOT NULL,
        Description      NVARCHAR(255)    NULL,
        IsActive         BIT              NOT NULL CONSTRAINT DF_Specializations_IsActive DEFAULT (1),
        CreatedByUserID  UNIQUEIDENTIFIER NULL,
        CreatedAt        DATETIME2(3)     NOT NULL CONSTRAINT DF_Specializations_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_Specializations           PRIMARY KEY (SpecializationID),
        CONSTRAINT FK_Specializations_Dept      FOREIGN KEY (DepartmentID) REFERENCES dbo.Departments (DepartmentID),
        CONSTRAINT FK_Specializations_Hospital  FOREIGN KEY (HospitalID)   REFERENCES dbo.Hospitals   (HospitalID)
    );
    PRINT 'Created table: Specializations';
END
ELSE PRINT 'Table already exists: Specializations';
GO

-- =============================================================================
-- 6. DOCTORS
-- =============================================================================

-- ── Doctors ───────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.Doctors', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Doctors (
        DoctorID                 UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Doctors_DoctorID DEFAULT (NEWID()),
        HospitalID               UNIQUEIDENTIFIER NOT NULL,
        UserID                   UNIQUEIDENTIFIER NOT NULL,
        LicenseNumber            NVARCHAR(100)    NOT NULL,
        Qualification            NVARCHAR(255)    NULL,
        ExperienceYears          INT              NULL,
        MedicalCouncil           NVARCHAR(150)    NULL,
        RegistrationYear         INT              NULL,
        Bio                      NVARCHAR(MAX)    NULL,
        ProfileCompletionPercent INT              NOT NULL CONSTRAINT DF_Doctors_Completion DEFAULT (0),
        ObjectURL                NVARCHAR(500)    NULL,
        PrimaryDepartmentID      UNIQUEIDENTIFIER NULL,
        CreatedAt                DATETIME2(3)     NOT NULL CONSTRAINT DF_Doctors_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_Doctors             PRIMARY KEY (DoctorID),
        CONSTRAINT FK_Doctors_Hospital    FOREIGN KEY (HospitalID)          REFERENCES dbo.Hospitals   (HospitalID),
        CONSTRAINT FK_Doctors_User        FOREIGN KEY (UserID)              REFERENCES dbo.Users       (UserID),
        CONSTRAINT FK_Doctors_PrimaryDept FOREIGN KEY (PrimaryDepartmentID) REFERENCES dbo.Departments (DepartmentID)
    );
    PRINT 'Created table: Doctors';
END
ELSE PRINT 'Table already exists: Doctors';
GO

-- ── DoctorDepartments ─────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.DoctorDepartments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DoctorDepartments (
        DoctorDepartmentID UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_DoctorDepts_ID DEFAULT (NEWID()),
        HospitalID         UNIQUEIDENTIFIER NOT NULL,
        DoctorID           UNIQUEIDENTIFIER NOT NULL,
        DepartmentID       UNIQUEIDENTIFIER NOT NULL,
        AssignedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_DoctorDepts_AssignedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DoctorDepartments          PRIMARY KEY (DoctorDepartmentID),
        CONSTRAINT FK_DoctorDepts_Hospital        FOREIGN KEY (HospitalID)   REFERENCES dbo.Hospitals   (HospitalID),
        CONSTRAINT FK_DoctorDepts_Doctor          FOREIGN KEY (DoctorID)     REFERENCES dbo.Doctors     (DoctorID)     ON DELETE CASCADE,
        CONSTRAINT FK_DoctorDepts_Department      FOREIGN KEY (DepartmentID) REFERENCES dbo.Departments (DepartmentID)
    );
    PRINT 'Created table: DoctorDepartments';
END
ELSE PRINT 'Table already exists: DoctorDepartments';
GO

-- ── DoctorSpecializations ─────────────────────────────────────────────────────
IF OBJECT_ID('dbo.DoctorSpecializations', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DoctorSpecializations (
        DoctorSpecializationID UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_DoctorSpecs_ID DEFAULT (NEWID()),
        DoctorID               UNIQUEIDENTIFIER NOT NULL,
        SpecializationID       UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_DoctorSpecializations            PRIMARY KEY (DoctorSpecializationID),
        CONSTRAINT FK_DoctorSpecs_Doctor               FOREIGN KEY (DoctorID)         REFERENCES dbo.Doctors         (DoctorID)         ON DELETE CASCADE,
        CONSTRAINT FK_DoctorSpecs_Specialization       FOREIGN KEY (SpecializationID) REFERENCES dbo.Specializations (SpecializationID)
    );
    PRINT 'Created table: DoctorSpecializations';
END
ELSE PRINT 'Table already exists: DoctorSpecializations';
GO

-- =============================================================================
-- 7. PATIENTS & APPOINTMENTS
-- =============================================================================

-- ── PatientRegistrations ──────────────────────────────────────────────────────
IF OBJECT_ID('dbo.PatientRegistrations', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PatientRegistrations (
        RegistrationId UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_PatientReg_ID DEFAULT (NEWID()),
        HospitalID     UNIQUEIDENTIFIER NOT NULL,
        PatientID      NVARCHAR(20)     NOT NULL,
        RegisteredAt   DATETIME2(3)     NOT NULL CONSTRAINT DF_PatientReg_RegisteredAt DEFAULT (SYSUTCDATETIME()),
        RegisteredBy   UNIQUEIDENTIFIER NULL,
        FullName       NVARCHAR(150)    NOT NULL,
        Mobile         NVARCHAR(20)     NULL,
        AgeYears       SMALLINT         NULL,
        Sex            NVARCHAR(20)     NULL,
        AddressLine    NVARCHAR(255)    NULL,
        City           NVARCHAR(100)    NULL,
        State          NVARCHAR(100)    NULL,
        Country        NVARCHAR(100)    NULL,
        Pincode        NVARCHAR(10)     NULL,
        InsuranceId    NVARCHAR(50)     NULL,
        CONSTRAINT PK_PatientRegistrations         PRIMARY KEY (RegistrationId),
        CONSTRAINT FK_PatientReg_Hospital          FOREIGN KEY (HospitalID) REFERENCES dbo.Hospitals (HospitalID)
    );
    PRINT 'Created table: PatientRegistrations';
END
ELSE PRINT 'Table already exists: PatientRegistrations';
GO

-- ── Appointments ──────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.Appointments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Appointments (
        ApptId              UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Appt_ApptId DEFAULT (NEWID()),
        HospitalID          UNIQUEIDENTIFIER NOT NULL,
        DoctorID            UNIQUEIDENTIFIER NOT NULL,
        PatientID           NVARCHAR(20)     NOT NULL,
        ApptDate            DATE             NOT NULL,
        StartAt             DATETIME2(3)     NULL,
        EndAt               DATETIME2(3)     NULL,
        Reason              NVARCHAR(200)    NULL,
        InsuranceId         NVARCHAR(50)     NULL,
        PaymentMode         NVARCHAR(30)     NULL,
        AppointmentType     NVARCHAR(30)     NULL,
        CurrentStatusCode   NVARCHAR(40)     NOT NULL CONSTRAINT DF_Appt_Status DEFAULT ('VITALS_REQUIRED'),
        StatusHistoryJson   NVARCHAR(MAX)    NOT NULL CONSTRAINT DF_Appt_History DEFAULT ('[]'),
        LastStatusCodeAt    DATETIME2(3)     NOT NULL CONSTRAINT DF_Appt_LastStatusAt DEFAULT (SYSUTCDATETIME()),
        CreatedAt           DATETIME2(3)     NOT NULL CONSTRAINT DF_Appt_CreatedAt    DEFAULT (SYSUTCDATETIME()),
        CreatedBy           UNIQUEIDENTIFIER NULL,
        PdfUrl              NVARCHAR(500)    NULL,
        ValidUptoDate       DATE             NULL,
        CONSTRAINT PK_Appointments               PRIMARY KEY (ApptId),
        CONSTRAINT FK_Appointments_Hospital      FOREIGN KEY (HospitalID)        REFERENCES dbo.Hospitals   (HospitalID),
        CONSTRAINT FK_Appointments_Doctor        FOREIGN KEY (DoctorID)          REFERENCES dbo.Doctors     (DoctorID),
        CONSTRAINT FK_Appointments_Status        FOREIGN KEY (CurrentStatusCode)  REFERENCES dbo.StatusMaster (StatusCode)
    );
    PRINT 'Created table: Appointments';
END
ELSE PRINT 'Table already exists: Appointments';
GO

-- =============================================================================
-- 8. LIVE SUPPORT
-- =============================================================================

-- ── SupportSessions ───────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.SupportSessions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SupportSessions (
        SessionId  UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_SupportSessions_SessionId DEFAULT (NEWID()),
        GuestId    NVARCHAR(100)    NOT NULL,
        GuestName  NVARCHAR(100)    NULL,
        GuestEmail NVARCHAR(150)    NULL,
        Status     NVARCHAR(20)     NOT NULL CONSTRAINT DF_SupportSessions_Status DEFAULT ('Active'),
        StartedAt  DATETIME2(3)     NOT NULL CONSTRAINT DF_SupportSessions_StartedAt DEFAULT (SYSUTCDATETIME()),
        ClosedAt   DATETIME2(3)     NULL,
        CONSTRAINT PK_SupportSessions PRIMARY KEY (SessionId)
    );
    PRINT 'Created table: SupportSessions';
END
ELSE PRINT 'Table already exists: SupportSessions';
GO

-- ── SupportMessages ───────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.SupportMessages', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SupportMessages (
        MessageId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_SupportMessages_MessageId DEFAULT (NEWID()),
        SessionId   UNIQUEIDENTIFIER NOT NULL,
        SenderType  NVARCHAR(20)     NOT NULL,   -- 'Guest' | 'Agent'
        SenderId    NVARCHAR(100)    NULL,
        MessageText NVARCHAR(MAX)    NOT NULL,
        SentAt      DATETIME2(3)     NOT NULL CONSTRAINT DF_SupportMessages_SentAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_SupportMessages           PRIMARY KEY (MessageId),
        CONSTRAINT FK_SupportMessages_Session   FOREIGN KEY (SessionId) REFERENCES dbo.SupportSessions (SessionId) ON DELETE CASCADE
    );
    PRINT 'Created table: SupportMessages';
END
ELSE PRINT 'Table already exists: SupportMessages';
GO

-- =============================================================================
-- 9. INDEXES
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_UserStatus_StatusName' AND object_id = OBJECT_ID('dbo.UserStatus'))
    CREATE UNIQUE INDEX UQ_UserStatus_StatusName ON dbo.UserStatus (StatusName);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_Users_Mobile' AND object_id = OBJECT_ID('dbo.Users'))
    CREATE UNIQUE INDEX UQ_Users_Mobile ON dbo.Users (MobileNumber);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_UserProfiles_User' AND object_id = OBJECT_ID('dbo.UserProfiles'))
    CREATE UNIQUE INDEX UQ_UserProfiles_User ON dbo.UserProfiles (UserID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_Roles' AND object_id = OBJECT_ID('dbo.Roles'))
    CREATE UNIQUE INDEX UQ_Roles ON dbo.Roles (HospitalID, RoleName);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_Departments_Hosp_Name' AND object_id = OBJECT_ID('dbo.Departments'))
    CREATE UNIQUE INDEX UQ_Departments_Hosp_Name ON dbo.Departments (HospitalID, Name);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_HDM' AND object_id = OBJECT_ID('dbo.HospitalDepartmentMappings'))
    CREATE UNIQUE INDEX UQ_HDM ON dbo.HospitalDepartmentMappings (HospitalID, DepartmentID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_Spec' AND object_id = OBJECT_ID('dbo.Specializations'))
    CREATE UNIQUE INDEX UQ_Spec ON dbo.Specializations (HospitalID, DepartmentID, Name);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_DoctorDepartments' AND object_id = OBJECT_ID('dbo.DoctorDepartments'))
    CREATE UNIQUE INDEX UQ_DoctorDepartments ON dbo.DoctorDepartments (DoctorID, DepartmentID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_Hospital' AND object_id = OBJECT_ID('dbo.Appointments'))
    CREATE INDEX IX_Appointments_Hospital ON dbo.Appointments (HospitalID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_Doctor' AND object_id = OBJECT_ID('dbo.Appointments'))
    CREATE INDEX IX_Appointments_Doctor ON dbo.Appointments (DoctorID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_Date' AND object_id = OBJECT_ID('dbo.Appointments'))
    CREATE INDEX IX_Appointments_Date ON dbo.Appointments (ApptDate);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SupportSessions_Status' AND object_id = OBJECT_ID('dbo.SupportSessions'))
    CREATE INDEX IX_SupportSessions_Status ON dbo.SupportSessions (Status);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SupportMessages_Session' AND object_id = OBJECT_ID('dbo.SupportMessages'))
    CREATE INDEX IX_SupportMessages_Session ON dbo.SupportMessages (SessionId);

PRINT 'Indexes created/verified.';
GO

-- =============================================================================
-- 10. SEED DATA — StatusMaster
-- =============================================================================

MERGE dbo.StatusMaster AS target
USING (VALUES
    ('VITALS_REQUIRED',   'Vitals Required'),
    ('IN_CONSULTATION',   'In Consultation'),
    ('AWAITING_RESULTS',  'Awaiting Results'),
    ('COMPLETED',         'Completed'),
    ('CANCELLED',         'Cancelled'),
    ('NO_SHOW',           'No Show'),
    ('RESCHEDULED',       'Rescheduled')
) AS source (StatusCode, StatusName)
ON target.StatusCode = source.StatusCode
WHEN NOT MATCHED THEN
    INSERT (StatusCode, StatusName) VALUES (source.StatusCode, source.StatusName)
WHEN MATCHED AND target.StatusName <> source.StatusName THEN
    UPDATE SET StatusName = source.StatusName;

PRINT 'StatusMaster seeded.';
GO

-- =============================================================================
-- 11. SEED DATA — UserStatus
-- =============================================================================

-- Use SET IDENTITY_INSERT to control IDs for idempotency
SET IDENTITY_INSERT dbo.UserStatus ON;

MERGE dbo.UserStatus AS target
USING (VALUES
    (1, 'Active'),
    (2, 'Inactive'),
    (3, 'Suspended'),
    (4, 'Pending Verification')
) AS source (UserStatusId, StatusName)
ON target.UserStatusId = source.UserStatusId
WHEN NOT MATCHED THEN
    INSERT (UserStatusId, StatusName) VALUES (source.UserStatusId, source.StatusName)
WHEN MATCHED AND target.StatusName <> source.StatusName THEN
    UPDATE SET StatusName = source.StatusName;

SET IDENTITY_INSERT dbo.UserStatus OFF;

PRINT 'UserStatus seeded.';
GO

-- =============================================================================
-- Done.
-- =============================================================================
PRINT '=== AppDatabase (HMS) setup complete ===';
GO
