-- =============================================================================
-- CMSDatabase Setup Script
-- Run this against the CMSDatabase (separate from the HMS AppDatabase).
-- Idempotent: all CREATE statements are guarded with IF OBJECT_ID checks.
-- Run order: tables first, then indexes, then seed data.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- =============================================================================
-- 1. TABLES
-- =============================================================================

-- ── CmsUsers ─────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.CmsUsers', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CmsUsers (
        UserId                UNIQUEIDENTIFIER NOT NULL,
        Email                 NVARCHAR(256)    NOT NULL,
        FullName              NVARCHAR(150)    NOT NULL,
        PasswordHash          NVARCHAR(255)    NOT NULL,
        PhoneNumber           NVARCHAR(20)     NULL,         -- E.164 format, e.g. +919876543210
        IsActive              BIT              NOT NULL CONSTRAINT DF_CmsUsers_IsActive              DEFAULT (1),
        MustChangePassword    BIT              NOT NULL CONSTRAINT DF_CmsUsers_MustChangePassword    DEFAULT (1),
        FailedLoginAttempts   INT              NOT NULL CONSTRAINT DF_CmsUsers_FailedLoginAttempts   DEFAULT (0),
        LockoutEnd            DATETIME2        NULL,
        LastLoginAt           DATETIME2        NULL,
        LastLoginIp           NVARCHAR(64)     NULL,
        CreatedByUserId       UNIQUEIDENTIFIER NULL,
        CreatedAt             DATETIME2        NOT NULL,
        UpdatedAt             DATETIME2        NULL,
        CONSTRAINT PK_CmsUsers PRIMARY KEY (UserId)
    );
    PRINT 'Created table: CmsUsers';
END
ELSE PRINT 'Table already exists: CmsUsers';
GO

-- ── CmsRoles ──────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.CmsRoles', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CmsRoles (
        RoleId          UNIQUEIDENTIFIER NOT NULL,
        Name            NVARCHAR(100)    NOT NULL,
        Description     NVARCHAR(255)    NULL,
        IsSystemDefined BIT              NOT NULL CONSTRAINT DF_CmsRoles_IsSystemDefined DEFAULT (0),
        IsActive        BIT              NOT NULL CONSTRAINT DF_CmsRoles_IsActive        DEFAULT (1),
        CreatedAt       DATETIME2        NOT NULL,
        CONSTRAINT PK_CmsRoles PRIMARY KEY (RoleId)
    );
    PRINT 'Created table: CmsRoles';
END
ELSE PRINT 'Table already exists: CmsRoles';
GO

-- ── CmsPermissions ────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.CmsPermissions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CmsPermissions (
        PermissionId  UNIQUEIDENTIFIER NOT NULL,
        [Key]         NVARCHAR(150)    NOT NULL,   -- e.g. 'dashboard.view'
        PageKey       NVARCHAR(100)    NOT NULL,   -- e.g. 'dashboard'
        Action        NVARCHAR(50)     NOT NULL,   -- e.g. 'view', 'manage', 'approve'
        DisplayName   NVARCHAR(150)    NOT NULL,
        Category      NVARCHAR(100)    NULL,
        SortOrder     INT              NOT NULL CONSTRAINT DF_CmsPermissions_SortOrder DEFAULT (0),
        CONSTRAINT PK_CmsPermissions PRIMARY KEY (PermissionId)
    );
    PRINT 'Created table: CmsPermissions';
END
ELSE PRINT 'Table already exists: CmsPermissions';
GO

-- ── CmsUserRoles ──────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.CmsUserRoles', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CmsUserRoles (
        UserId UNIQUEIDENTIFIER NOT NULL,
        RoleId UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_CmsUserRoles    PRIMARY KEY (UserId, RoleId),
        CONSTRAINT FK_CmsUserRoles_User FOREIGN KEY (UserId) REFERENCES dbo.CmsUsers  (UserId) ON DELETE CASCADE,
        CONSTRAINT FK_CmsUserRoles_Role FOREIGN KEY (RoleId) REFERENCES dbo.CmsRoles  (RoleId) ON DELETE CASCADE
    );
    PRINT 'Created table: CmsUserRoles';
END
ELSE PRINT 'Table already exists: CmsUserRoles';
GO

-- ── CmsRolePermissions ────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.CmsRolePermissions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CmsRolePermissions (
        RoleId       UNIQUEIDENTIFIER NOT NULL,
        PermissionId UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_CmsRolePermissions       PRIMARY KEY (RoleId, PermissionId),
        CONSTRAINT FK_CmsRolePerms_Role        FOREIGN KEY (RoleId)       REFERENCES dbo.CmsRoles       (RoleId)       ON DELETE CASCADE,
        CONSTRAINT FK_CmsRolePerms_Permission  FOREIGN KEY (PermissionId) REFERENCES dbo.CmsPermissions (PermissionId) ON DELETE CASCADE
    );
    PRINT 'Created table: CmsRolePermissions';
END
ELSE PRINT 'Table already exists: CmsRolePermissions';
GO

-- ── CmsUserPermissions ────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.CmsUserPermissions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CmsUserPermissions (
        UserId       UNIQUEIDENTIFIER NOT NULL,
        PermissionId UNIQUEIDENTIFIER NOT NULL,
        Effect       NVARCHAR(10)     NOT NULL CONSTRAINT DF_CmsUserPermissions_Effect DEFAULT ('Allow'), -- 'Allow' | 'Deny'
        CONSTRAINT PK_CmsUserPermissions       PRIMARY KEY (UserId, PermissionId),
        CONSTRAINT FK_CmsUserPerms_User        FOREIGN KEY (UserId)       REFERENCES dbo.CmsUsers       (UserId)       ON DELETE CASCADE,
        CONSTRAINT FK_CmsUserPerms_Permission  FOREIGN KEY (PermissionId) REFERENCES dbo.CmsPermissions (PermissionId) ON DELETE CASCADE
    );
    PRINT 'Created table: CmsUserPermissions';
END
ELSE PRINT 'Table already exists: CmsUserPermissions';
GO

-- ── CmsRefreshTokens ──────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.CmsRefreshTokens', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CmsRefreshTokens (
        TokenId            UNIQUEIDENTIFIER NOT NULL,
        UserId             UNIQUEIDENTIFIER NOT NULL,
        TokenHash          NVARCHAR(128)    NOT NULL,
        ExpiresAt          DATETIME2        NOT NULL,
        CreatedAt          DATETIME2        NOT NULL,
        CreatedByIp        NVARCHAR(64)     NULL,
        RevokedAt          DATETIME2        NULL,
        ReplacedByTokenId  UNIQUEIDENTIFIER NULL,
        CONSTRAINT PK_CmsRefreshTokens      PRIMARY KEY (TokenId),
        CONSTRAINT FK_CmsRefreshTokens_User FOREIGN KEY (UserId) REFERENCES dbo.CmsUsers (UserId) ON DELETE CASCADE
    );
    PRINT 'Created table: CmsRefreshTokens';
END
ELSE PRINT 'Table already exists: CmsRefreshTokens';
GO

-- ── CmsOtps ───────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.CmsOtps', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CmsOtps (
        OtpId          UNIQUEIDENTIFIER NOT NULL,
        UserId         UNIQUEIDENTIFIER NOT NULL,
        CodeHash       NVARCHAR(64)     NOT NULL,   -- SHA-256 hex of the 6-digit code
        DeliveryTarget NVARCHAR(256)    NOT NULL,   -- email address or phone number
        DeliveryMethod NVARCHAR(10)     NOT NULL,   -- 'email' | 'sms'
        Purpose        NVARCHAR(20)     NOT NULL CONSTRAINT DF_CmsOtps_Purpose DEFAULT ('login'), -- 'login' | 'password_reset'
        ExpiresAt      DATETIME2        NOT NULL,
        CreatedAt      DATETIME2        NOT NULL,
        UsedAt         DATETIME2        NULL,
        CreatedByIp    NVARCHAR(64)     NULL,
        CONSTRAINT PK_CmsOtps PRIMARY KEY (OtpId)
    );
    PRINT 'Created table: CmsOtps';
END
ELSE PRINT 'Table already exists: CmsOtps';
GO

-- =============================================================================
-- 2. INDEXES
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_CmsUsers_Email' AND object_id = OBJECT_ID('dbo.CmsUsers'))
    CREATE UNIQUE INDEX UQ_CmsUsers_Email       ON dbo.CmsUsers       ([Email]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CmsUsers_PhoneNumber' AND object_id = OBJECT_ID('dbo.CmsUsers'))
    CREATE INDEX IX_CmsUsers_PhoneNumber        ON dbo.CmsUsers       (PhoneNumber) WHERE PhoneNumber IS NOT NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_CmsRoles_Name' AND object_id = OBJECT_ID('dbo.CmsRoles'))
    CREATE UNIQUE INDEX UQ_CmsRoles_Name        ON dbo.CmsRoles       ([Name]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_CmsPermissions_Key' AND object_id = OBJECT_ID('dbo.CmsPermissions'))
    CREATE UNIQUE INDEX UQ_CmsPermissions_Key   ON dbo.CmsPermissions ([Key]);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_CmsRefreshTokens_Hash' AND object_id = OBJECT_ID('dbo.CmsRefreshTokens'))
    CREATE UNIQUE INDEX UQ_CmsRefreshTokens_Hash ON dbo.CmsRefreshTokens (TokenHash);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CmsRefreshTokens_UserId' AND object_id = OBJECT_ID('dbo.CmsRefreshTokens'))
    CREATE INDEX IX_CmsRefreshTokens_UserId     ON dbo.CmsRefreshTokens (UserId);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CmsOtps_UserId' AND object_id = OBJECT_ID('dbo.CmsOtps'))
    CREATE INDEX IX_CmsOtps_UserId              ON dbo.CmsOtps         (UserId);

PRINT 'Indexes created/verified.';
GO

-- =============================================================================
-- 3. SEED DATA — Permissions
-- Fixed GUIDs ensure this script is safely re-runnable (MERGE = upsert).
-- =============================================================================

MERGE dbo.CmsPermissions AS target
USING (VALUES
    -- PermissionId                              Key                         PageKey                Action    DisplayName                          Category           SortOrder
    ('A0000001-0000-0000-0000-000000000001', 'dashboard.view',           'dashboard',           'view',   'View Dashboard',                    'Dashboard',        10),
    ('A0000001-0000-0000-0000-000000000002', 'onboarded-hospitals.view', 'onboarded-hospitals', 'view',   'View Onboarded Hospitals',          'Hospitals',        20),
    ('A0000001-0000-0000-0000-000000000003', 'hospital-details.view',    'hospital-details',    'view',   'View Hospital Details',             'Hospitals',        21),
    ('A0000001-0000-0000-0000-000000000004', 'subscriptions.view',       'subscriptions',       'view',   'View Subscriptions',                'Subscriptions',    30),
    ('A0000001-0000-0000-0000-000000000005', 'subscriptions.approve',    'subscriptions',       'approve','Approve Subscription Payments',     'Subscriptions',    31),
    ('A0000001-0000-0000-0000-000000000006', 'application-health.view',  'application-health',  'view',   'View Application Health',           'System',           40),
    ('A0000001-0000-0000-0000-000000000007', 'radai-cost.view',          'radai-cost',          'view',   'View RadAI Cost Analytics',         'AI',               50),
    ('A0000001-0000-0000-0000-000000000008', 'live-support.view',        'live-support',        'view',   'View Live Support',                 'Support',          60),
    ('A0000001-0000-0000-0000-000000000009', 'user-management.view',     'user-management',     'view',   'View Users & Roles',                'Administration',   70),
    ('A0000001-0000-0000-0000-00000000000A', 'user-management.manage',   'user-management',     'manage', 'Manage Users & Roles',              'Administration',   71),
    ('A0000001-0000-0000-0000-00000000000B', 'settings.view',            'settings',            'view',   'View Settings',                     'System',           80),
    ('A0000001-0000-0000-0000-00000000000D', 'insights.view',            'insights',            'view',   'View Insights (Visits/Logins/Appts)','Doctor Dekho',     90)
) AS source (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
ON target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.PermissionId), source.[Key], source.PageKey, source.Action, source.DisplayName, source.Category, source.SortOrder)
WHEN MATCHED AND (
    target.[Key]         <> source.[Key]         OR
    target.DisplayName   <> source.DisplayName   OR
    target.SortOrder     <> source.SortOrder
) THEN
    UPDATE SET
        [Key]       = source.[Key],
        PageKey     = source.PageKey,
        Action      = source.Action,
        DisplayName = source.DisplayName,
        Category    = source.Category,
        SortOrder   = source.SortOrder;

PRINT 'Permissions seeded.';
GO

-- =============================================================================
-- 4. SEED DATA — Roles
-- =============================================================================

MERGE dbo.CmsRoles AS target
USING (VALUES
    -- RoleId                                    Name              Description                           IsSystemDefined IsActive
    ('B0000001-0000-0000-0000-000000000001', 'Administrator',  'Full access to all CMS features.',   1,              1),
    ('B0000001-0000-0000-0000-000000000002', 'Support Agent',  'Access to live support only.',       1,              1),
    ('B0000001-0000-0000-0000-000000000003', 'Hospital Manager','Can view and manage hospitals.',    1,              1)
) AS source (RoleId, Name, Description, IsSystemDefined, IsActive)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, Name, Description, IsSystemDefined, IsActive, CreatedAt)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), source.Name, source.Description, source.IsSystemDefined, source.IsActive, SYSUTCDATETIME())
WHEN MATCHED AND target.Name <> source.Name THEN
    UPDATE SET Name = source.Name, Description = source.Description;

PRINT 'Roles seeded.';
GO

-- =============================================================================
-- 5. SEED DATA — Role → Permission mappings
-- =============================================================================

-- Administrator gets ALL permissions
MERGE dbo.CmsRolePermissions AS target
USING (
    SELECT
        CONVERT(UNIQUEIDENTIFIER, 'B0000001-0000-0000-0000-000000000001') AS RoleId,
        PermissionId
    FROM dbo.CmsPermissions
) AS source (RoleId, PermissionId)
ON target.RoleId = source.RoleId AND target.PermissionId = source.PermissionId
WHEN NOT MATCHED THEN
    INSERT (RoleId, PermissionId) VALUES (source.RoleId, source.PermissionId);

-- Support Agent gets live-support.view only
MERGE dbo.CmsRolePermissions AS target
USING (VALUES
    ('B0000001-0000-0000-0000-000000000002', 'A0000001-0000-0000-0000-000000000008')  -- live-support.view
) AS source (RoleId, PermissionId)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
   AND target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, PermissionId)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), CONVERT(UNIQUEIDENTIFIER, source.PermissionId));

-- Hospital Manager gets hospital + dashboard views
MERGE dbo.CmsRolePermissions AS target
USING (VALUES
    ('B0000001-0000-0000-0000-000000000003', 'A0000001-0000-0000-0000-000000000001'), -- dashboard.view
    ('B0000001-0000-0000-0000-000000000003', 'A0000001-0000-0000-0000-000000000002'), -- onboarded-hospitals.view
    ('B0000001-0000-0000-0000-000000000003', 'A0000001-0000-0000-0000-000000000003')  -- hospital-details.view
) AS source (RoleId, PermissionId)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
   AND target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, PermissionId)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), CONVERT(UNIQUEIDENTIFIER, source.PermissionId));

PRINT 'Role-permission mappings seeded.';
GO

-- =============================================================================
-- Done.
-- Next step: set env vars CMS_SEED_ADMIN_EMAIL + CMS_SEED_ADMIN_PASSWORD
-- and start the API — CmsAdminSeeder will create the first admin user and
-- assign the Administrator role automatically.
-- =============================================================================
PRINT '=== CMSDatabase setup complete ===';
GO
