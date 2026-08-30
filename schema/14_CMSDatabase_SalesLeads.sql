-- ============================================================
-- 14_CMSDatabase_SalesLeads.sql
-- CMS Marketing — B2B Sales CRM Pipeline
--
-- Adds CmsSalesLeads and CmsSalesLeadFollowUps tables.
-- These store prospective hospital clients (B2B pipeline),
-- completely separate from HospitalLeads (patient leads inside
-- already-onboarded hospitals).
--
-- Stages:  New | Contacted | Demo Scheduled | Demo Done |
--          Negotiation | Closed Won | Closed Lost
-- Priority: High | Medium | Low
-- Sources:  Cold Call | WhatsApp | Website | Referral | Event | Partner | Other
-- Activity: Call | WhatsApp | Email | Meeting | Note
-- ============================================================

-- ── 1. Permissions ───────────────────────────────────────────

-- Add marketing.manage permission (marketing.view already exists from script 09)
IF NOT EXISTS (SELECT 1 FROM CmsPermissions WHERE [Key] = 'marketing.manage')
BEGIN
    INSERT INTO CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (
        NEWID(),
        'marketing.manage',
        'marketing',
        'manage',
        'Marketing — Manage Leads',
        'Marketing',
        52
    );
END
GO

-- Grant marketing.manage to SuperAdmin role (adjust role name if different)
DECLARE @ManagePermId UNIQUEIDENTIFIER = (SELECT PermissionId FROM CmsPermissions WHERE [Key] = 'marketing.manage');
DECLARE @SuperAdminRoleId UNIQUEIDENTIFIER = (SELECT RoleId FROM CmsRoles WHERE Name = 'SuperAdmin');

IF @ManagePermId IS NOT NULL AND @SuperAdminRoleId IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM CmsRolePermissions WHERE RoleId = @SuperAdminRoleId AND PermissionId = @ManagePermId)
BEGIN
    INSERT INTO CmsRolePermissions (RoleId, PermissionId)
    VALUES (@SuperAdminRoleId, @ManagePermId);
END
GO

-- ── 2. CmsSalesLeads ─────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CmsSalesLeads')
BEGIN
    CREATE TABLE CmsSalesLeads (
        LeadId              UNIQUEIDENTIFIER    NOT NULL DEFAULT NEWID()     PRIMARY KEY,
        HospitalName        NVARCHAR(200)       NOT NULL,
        ContactName         NVARCHAR(150)       NULL,
        Mobile              NVARCHAR(20)        NULL,
        Email               NVARCHAR(256)       NULL,
        City                NVARCHAR(100)       NULL,
        State               NVARCHAR(100)       NULL,
        Source              NVARCHAR(50)        NOT NULL DEFAULT 'Manual',
        Stage               NVARCHAR(50)        NOT NULL DEFAULT 'New',
        Priority            NVARCHAR(20)        NOT NULL DEFAULT 'Medium',
        Notes               NVARCHAR(MAX)       NULL,
        AssignedToUserId    UNIQUEIDENTIFIER    NULL
            REFERENCES CmsUsers(UserId) ON DELETE SET NULL,
        CreatedByUserId     UNIQUEIDENTIFIER    NULL
            REFERENCES CmsUsers(UserId) ON DELETE NO ACTION,
        CreatedAt           DATETIME2(0)        NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt           DATETIME2(0)        NOT NULL DEFAULT SYSUTCDATETIME()
    );

    CREATE INDEX IX_CmsSalesLeads_Stage          ON CmsSalesLeads(Stage);
    CREATE INDEX IX_CmsSalesLeads_AssignedTo     ON CmsSalesLeads(AssignedToUserId);
    CREATE INDEX IX_CmsSalesLeads_CreatedAt      ON CmsSalesLeads(CreatedAt DESC);
    CREATE INDEX IX_CmsSalesLeads_Priority       ON CmsSalesLeads(Priority);

    PRINT 'Created table CmsSalesLeads';
END
ELSE
    PRINT 'Table CmsSalesLeads already exists — skipped.';
GO

-- ── 3. CmsSalesLeadFollowUps ──────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CmsSalesLeadFollowUps')
BEGIN
    CREATE TABLE CmsSalesLeadFollowUps (
        FollowUpId      UNIQUEIDENTIFIER    NOT NULL DEFAULT NEWID()     PRIMARY KEY,
        LeadId          UNIQUEIDENTIFIER    NOT NULL
            REFERENCES CmsSalesLeads(LeadId) ON DELETE CASCADE,
        AuthorUserId    UNIQUEIDENTIFIER    NULL
            REFERENCES CmsUsers(UserId) ON DELETE SET NULL,
        AuthorName      NVARCHAR(150)       NULL,   -- snapshot at write time
        ActivityType    NVARCHAR(50)        NOT NULL,
        Notes           NVARCHAR(MAX)       NOT NULL,
        CreatedAt       DATETIME2(0)        NOT NULL DEFAULT SYSUTCDATETIME()
    );

    CREATE INDEX IX_CmsSalesLeadFollowUps_LeadId    ON CmsSalesLeadFollowUps(LeadId);
    CREATE INDEX IX_CmsSalesLeadFollowUps_CreatedAt ON CmsSalesLeadFollowUps(CreatedAt DESC);

    PRINT 'Created table CmsSalesLeadFollowUps';
END
ELSE
    PRINT 'Table CmsSalesLeadFollowUps already exists — skipped.';
GO
