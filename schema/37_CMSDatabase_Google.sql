-- =============================================================================
-- CMSDatabase -- Google: Analytics, Google Ads, lead forms, results sent to Google
-- =============================================================================
-- Run after scripts 01 to 36.
--
-- CMS → Google works on one or more "accounts" (a website with its Google Analytics
-- property, Google Ads account and Search Console site), e.g. NexEagle (nexeagle.com)
-- and Doctor Dekho. An administrator signs in with Google in Google → Setup; the OAuth
-- client secret, refresh token and lead-form key are encrypted by the API.
-- Analytics, Ads and Search Console numbers are read from Google when a screen asks
-- (cached for a few minutes), so they are not stored here.
-- Plan: claude/google-analytics-ads-plan.md
--
--   GoogleAccounts           one per website: Google sign-in, chosen accounts, tag IDs, keys
--   GoogleLeads              leads from Google lead forms and website forms, with the Google click ID
--   GoogleConversionUploads  CRM results (e.g. Demo Done, Closed Won) sent to Google Ads, once each
--
-- Permissions (area "Google"): google.view, google.ads, google.connect.
-- Administrator gets all, Manager view and ads; "Marketing team" gets view.
-- Safe to run more than once. People see new permissions when they next sign in.
-- =============================================================================

USE CMSDatabase;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ── Accounts ─────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.GoogleAccounts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GoogleAccounts (
        AccountId           UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_GoogleAccounts PRIMARY KEY,
        Name                NVARCHAR(100)    NOT NULL,
        Site                NVARCHAR(40)     NULL,       -- the website's key for its tag: 'nexeagle', 'doctordekho'
        ClientId            NVARCHAR(200)    NULL,       -- Google Cloud OAuth client
        ClientSecretEnc     NVARCHAR(1000)   NULL,
        RefreshTokenEnc     NVARCHAR(2000)   NULL,
        SignedInEmail       NVARCHAR(200)    NULL,
        SignedInAt          DATETIME2(0)     NULL,
        Ga4PropertyId       NVARCHAR(40)     NULL,       -- numeric property id
        Ga4PropertyName     NVARCHAR(200)    NULL,
        AdsCustomerId       NVARCHAR(20)     NULL,       -- digits only
        AdsLoginCustomerId  NVARCHAR(20)     NULL,       -- the manager account it is reached through, if any
        AdsAccountName      NVARCHAR(200)    NULL,
        Currency            NVARCHAR(3)      NULL,
        TimeZone            NVARCHAR(60)     NULL,
        SearchConsoleSite   NVARCHAR(300)    NULL,       -- 'sc-domain:nexeagle.com' or 'https://nexeagle.com/'
        MeasurementId       NVARCHAR(30)     NULL,       -- G-XXXXXXX, read by the website
        AdsConversionId     NVARCHAR(30)     NULL,       -- AW-XXXXXXX, read by the website
        EventLabelsJson     NVARCHAR(MAX)    NULL,       -- {"generate_lead":"AbCdEf"}: site actions sent as Ads conversions
        LeadKeyEnc          NVARCHAR(500)    NULL,       -- the key Google lead forms send with each lead
        LastLeadAt          DATETIME2(0)     NULL,
        OutcomesJson        NVARCHAR(MAX)    NULL,       -- [{"stage":"Demo Done","conversionActionId":"123","value":0}]
        LastOutcomeAt       DATETIME2(0)     NULL,
        LastOutcomeError    NVARCHAR(1000)   NULL,
        LastReadError       NVARCHAR(1000)   NULL,
        IsActive            BIT              NOT NULL CONSTRAINT DF_GoogleAccounts_Active DEFAULT (1),
        SortOrder           INT              NOT NULL CONSTRAINT DF_GoogleAccounts_Sort DEFAULT (0),
        UpdatedByUserId     UNIQUEIDENTIFIER NULL,
        CreatedAt           DATETIME2(0)     NOT NULL,
        UpdatedAt           DATETIME2(0)     NOT NULL
    );
    CREATE UNIQUE INDEX UX_GoogleAccounts_Site ON dbo.GoogleAccounts (Site) WHERE Site IS NOT NULL;
    PRINT 'Created table: GoogleAccounts';
END
GO

-- ── Leads ────────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.GoogleLeads', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GoogleLeads (
        GoogleLeadId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_GoogleLeads PRIMARY KEY,
        AccountId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_GoogleLeads_Account REFERENCES dbo.GoogleAccounts(AccountId) ON DELETE CASCADE,
        LeadId           UNIQUEIDENTIFIER NOT NULL,      -- CmsSalesLeads.LeadId
        Source           NVARCHAR(10)     NOT NULL CONSTRAINT CK_GoogleLeads_Source CHECK (Source IN ('form', 'web')),
        ExternalLeadId   NVARCHAR(100)    NULL,          -- Google's lead_id (lead forms)
        FormId           NVARCHAR(40)     NULL,
        FormName         NVARCHAR(200)    NULL,          -- website: the page the form was on
        CampaignId       NVARCHAR(40)     NULL,
        CampaignName     NVARCHAR(300)    NULL,
        AdGroupId        NVARCHAR(40)     NULL,
        Keyword          NVARCHAR(300)    NULL,          -- utm_term, or the keyword Google reports
        Gclid            NVARCHAR(300)    NULL,
        Gbraid           NVARCHAR(300)    NULL,
        Wbraid           NVARCHAR(300)    NULL,
        UtmSource        NVARCHAR(100)    NULL,
        UtmMedium        NVARCHAR(100)    NULL,
        UtmCampaign      NVARCHAR(200)    NULL,
        LandingPage      NVARCHAR(500)    NULL,
        AnswersJson      NVARCHAR(MAX)    NULL,          -- [{"name":"City","value":"Purnia"}]
        ReceivedAt       DATETIME2(0)     NOT NULL
    );
    CREATE UNIQUE INDEX UX_GoogleLeads_External ON dbo.GoogleLeads (ExternalLeadId) WHERE ExternalLeadId IS NOT NULL;
    CREATE INDEX IX_GoogleLeads_Account ON dbo.GoogleLeads (AccountId, ReceivedAt DESC);
    CREATE INDEX IX_GoogleLeads_Lead ON dbo.GoogleLeads (LeadId);
    PRINT 'Created table: GoogleLeads';
END
GO

-- ── Results sent to Google ───────────────────────────────────────────────────

IF OBJECT_ID('dbo.GoogleConversionUploads', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GoogleConversionUploads (
        UploadId            UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_GoogleConversionUploads PRIMARY KEY,
        AccountId           UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_GoogleConversionUploads_Account REFERENCES dbo.GoogleAccounts(AccountId) ON DELETE CASCADE,
        GoogleLeadId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_GoogleConversionUploads_Lead REFERENCES dbo.GoogleLeads(GoogleLeadId),
        Stage               NVARCHAR(50)     NOT NULL,
        ConversionActionId  NVARCHAR(40)     NOT NULL,
        Status              NVARCHAR(10)     NOT NULL CONSTRAINT CK_GoogleConversionUploads_Status CHECK (Status IN ('sent', 'failed')),
        RequestId           NVARCHAR(100)    NULL,
        Error               NVARCHAR(1000)   NULL,
        Attempts            INT              NOT NULL CONSTRAINT DF_GoogleConversionUploads_Attempts DEFAULT (1),
        SentAt              DATETIME2(0)     NOT NULL
    );
    CREATE UNIQUE INDEX UX_GoogleConversionUploads_LeadStage ON dbo.GoogleConversionUploads (GoogleLeadId, Stage);
    PRINT 'Created table: GoogleConversionUploads';
END
GO

-- ── Permissions ──────────────────────────────────────────────────────────────

MERGE dbo.CmsPermissions AS target
USING (VALUES
    ('google.view',    'google', 'view',    'See Google Analytics, website pages and leads from Google', 140),
    ('google.ads',     'google', 'ads',     'See Google Ads spend and results',                         141),
    ('google.connect', 'google', 'connect', 'Connect Google accounts and set the website tag',          142)
) AS source ([Key], PageKey, Action, DisplayName, SortOrder)
ON target.[Key] = source.[Key]
WHEN NOT MATCHED THEN
    INSERT (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (NEWID(), source.[Key], source.PageKey, source.Action, source.DisplayName, 'Google', source.SortOrder)
WHEN MATCHED THEN
    UPDATE SET DisplayName = source.DisplayName, Category = 'Google', SortOrder = source.SortOrder;
PRINT CONCAT('Google permissions added or updated: ', @@ROWCOUNT);
GO

DECLARE @Grants TABLE (RoleId UNIQUEIDENTIFIER, [Key] NVARCHAR(100));
INSERT @Grants SELECT 'B0000001-0000-0000-0000-000000000001', [Key] FROM dbo.CmsPermissions WHERE [Key] LIKE 'google.%';  -- Administrator
INSERT @Grants VALUES
    ('B0000001-0000-0000-0000-000000000004', 'google.view'),   -- Manager
    ('B0000001-0000-0000-0000-000000000004', 'google.ads'),
    ('B0000001-0000-0000-0000-000000000007', 'google.view');   -- Marketing team

INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
SELECT DISTINCT g.RoleId, p.PermissionId
FROM @Grants g
JOIN dbo.CmsPermissions p ON p.[Key] = g.[Key]
JOIN dbo.CmsRoles r ON r.RoleId = g.RoleId
WHERE NOT EXISTS (SELECT 1 FROM dbo.CmsRolePermissions rp WHERE rp.RoleId = g.RoleId AND rp.PermissionId = p.PermissionId);
PRINT CONCAT('Google grants added: ', @@ROWCOUNT);
GO
