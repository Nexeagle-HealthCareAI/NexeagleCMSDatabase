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
        LeadNumber          NVARCHAR(50)        NULL UNIQUE,
        FacilityType        NVARCHAR(50)        NOT NULL DEFAULT 'HOSPITAL',
        BedCount            INT                 NOT NULL DEFAULT 0,
        UtmSource           NVARCHAR(100)       NULL,
        UtmMedium           NVARCHAR(100)       NULL,
        UtmCampaign         NVARCHAR(150)       NULL,
        UtmAdId             NVARCHAR(100)       NULL,
        AiIntentScore       INT                 NOT NULL DEFAULT 50,
        AiPersonaSummary    NVARCHAR(MAX)       NULL,
        DealValue           DECIMAL(12,2)       NOT NULL DEFAULT 0.00,
        LostReason          NVARCHAR(MAX)       NULL,
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
        Direction       NVARCHAR(10)        NOT NULL DEFAULT 'OUTBOUND',
        TemplateName    NVARCHAR(100)       NULL,
        MediaUrl        NVARCHAR(500)       NULL,
        WhatsappMessageId NVARCHAR(100)     NULL,
        Status          NVARCHAR(30)        NOT NULL DEFAULT 'DELIVERED',
        CreatedAt       DATETIME2(0)        NOT NULL DEFAULT SYSUTCDATETIME()
    );

    CREATE INDEX IX_CmsSalesLeadFollowUps_LeadId    ON CmsSalesLeadFollowUps(LeadId);
    CREATE INDEX IX_CmsSalesLeadFollowUps_CreatedAt ON CmsSalesLeadFollowUps(CreatedAt DESC);

    PRINT 'Created table CmsSalesLeadFollowUps';
END
ELSE
    PRINT 'Table CmsSalesLeadFollowUps already exists — skipped.';
GO

-- ── 4. CmsCampaigns ───────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CmsCampaigns')
BEGIN
    CREATE TABLE CmsCampaigns (
        CampaignId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        CampaignName NVARCHAR(200) NOT NULL,
        Platform NVARCHAR(50) NOT NULL,
        ExternalCampaignId NVARCHAR(100),
        StartDate DATE NOT NULL,
        EndDate DATE,
        BudgetAllocated DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        ActualSpend DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        TargetSpecialty NVARCHAR(100),
        TargetGeography NVARCHAR(100) DEFAULT 'Bihar',
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Created table CmsCampaigns';
END
GO

-- ── 5. CmsSocialPosts ─────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CmsSocialPosts')
BEGIN
    CREATE TABLE CmsSocialPosts (
        Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        CampaignId UNIQUEIDENTIFIER NULL REFERENCES CmsCampaigns(Id) ON DELETE SET NULL,
        PlatformsTargeted NVARCHAR(MAX) NOT NULL,
        PostTitle NVARCHAR(250) NOT NULL,
        PostCaption NVARCHAR(MAX) NOT NULL,
        MediaAssetUrls NVARCHAR(MAX) NOT NULL DEFAULT '[]',
        ScheduledPublishTime DATETIME2(0) NOT NULL,
        PublishedStatus NVARCHAR(30) NOT NULL DEFAULT 'SCHEDULED',
        PublishedPostIds NVARCHAR(MAX) DEFAULT '{}',
        GroqPromptUsed NVARCHAR(MAX),
        CreatedBy UNIQUEIDENTIFIER NULL REFERENCES CmsUsers(UserId) ON DELETE SET NULL,
        CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Created table CmsSocialPosts';
END
GO

-- ── 6. CmsWhatsappTemplates ───────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CmsWhatsappTemplates')
BEGIN
    CREATE TABLE CmsWhatsappTemplates (
        Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        TemplateName NVARCHAR(100) NOT NULL UNIQUE,
        Category NVARCHAR(50) NOT NULL,
        Language NVARCHAR(10) NOT NULL DEFAULT 'en',
        HeaderType NVARCHAR(20) DEFAULT 'VIDEO',
        HeaderMediaUrl NVARCHAR(500),
        BodyText NVARCHAR(MAX) NOT NULL,
        FooterText NVARCHAR(150),
        ButtonsConfig NVARCHAR(MAX) DEFAULT '[]',
        MetaApprovalStatus NVARCHAR(30) NOT NULL DEFAULT 'APPROVED',
        IsActive BIT NOT NULL DEFAULT 1
    );
    PRINT 'Created table CmsWhatsappTemplates';
END
GO
