-- =============================================================================
-- CMSDatabase -- Keywords: what people search for, collected daily, and the content plan
-- =============================================================================
-- Run after scripts 01 to 37 (uses the Google sign-in from script 37).
--
-- CMS → Marketing → Keywords collects every morning (05:30 IST) the searches that matter to
-- Doctor Dekho and nexeagle.com: Search Console (searches that showed our pages), Google Ads
-- search terms, Google Keyword Planner ideas and volumes for India, and Doctor Dekho's own site
-- searches (only phrases typed by at least 5 different visitors; who searched is never kept).
-- Each phrase is one keyword; each day's numbers from each source are one observation.
-- Plan: claude/keyword-content-engine-plan.md
--
--   KeywordSettings     one row: seed lists, competitor sites, scoring weights, privacy threshold
--   KeywordTopics       groups of keywords one page should answer
--   Keywords            one per site and phrase: language, intent, city, topic, Keyword Planner numbers
--   KeywordObservations one per keyword, day and source: showings, clicks, position, visitors, cost
--   KeywordContent      the content plan: page updates, Health Wiki articles, guides, posts
--   KeywordSourceRuns   last run of each source, for Setup and the Overview
--
-- Permissions (area "Keywords"): keywords.view, keywords.edit, keywords.connect.
-- Administrator gets all; Manager and Marketing team get view and edit.
-- Safe to run more than once. People see new permissions when they next sign in.
-- =============================================================================

USE CMSDatabase;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ── Settings ─────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.KeywordSettings', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.KeywordSettings (
        SettingsId          INT              NOT NULL CONSTRAINT PK_KeywordSettings PRIMARY KEY CONSTRAINT CK_KeywordSettings_One CHECK (SettingsId = 1),
        SeedsJson           NVARCHAR(MAX)    NULL,      -- {"doctordekho":["dengue",...],"nexeagle":["opd billing",...]}
        CompetitorSitesJson NVARCHAR(MAX)    NULL,      -- {"doctordekho":["example.com"],"nexeagle":[...]}
        CitiesJson          NVARCHAR(MAX)    NULL,      -- extra city and area names to recognise
        WeightsJson         NVARCHAR(MAX)    NULL,      -- {"demand":7,"fit":8,"close":6,"value":9}
        MinVisitors         INT              NOT NULL CONSTRAINT DF_KeywordSettings_MinVisitors DEFAULT (5) CONSTRAINT CK_KeywordSettings_MinVisitors CHECK (MinVisitors >= 5),
        PlannerCursor       INT              NOT NULL CONSTRAINT DF_KeywordSettings_PlannerCursor DEFAULT (0),
        UpdatedByUserId     UNIQUEIDENTIFIER NULL,
        UpdatedAt           DATETIME2(0)     NOT NULL CONSTRAINT DF_KeywordSettings_UpdatedAt DEFAULT (SYSUTCDATETIME())
    );
    INSERT dbo.KeywordSettings (SettingsId) VALUES (1);
    PRINT 'Created table: KeywordSettings';
END
GO

-- ── Topics ───────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.KeywordTopics', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.KeywordTopics (
        TopicId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_KeywordTopics PRIMARY KEY,
        Site            NVARCHAR(20)     NOT NULL CONSTRAINT CK_KeywordTopics_Site CHECK (Site IN ('doctordekho', 'nexeagle')),
        Name            NVARCHAR(200)    NOT NULL,
        TargetPage      NVARCHAR(500)    NULL,          -- the page that should answer it (path or full URL)
        Notes           NVARCHAR(2000)   NULL,
        IsSuggested     BIT              NOT NULL CONSTRAINT DF_KeywordTopics_IsSuggested DEFAULT (0),  -- made by the CMS from a page; a person can rename or merge it
        CreatedByUserId UNIQUEIDENTIFIER NULL,
        CreatedAt       DATETIME2(0)     NOT NULL,
        UpdatedAt       DATETIME2(0)     NOT NULL
    );
    CREATE INDEX IX_KeywordTopics_Site ON dbo.KeywordTopics (Site, Name);
    CREATE UNIQUE INDEX UX_KeywordTopics_Page ON dbo.KeywordTopics (Site, TargetPage) WHERE TargetPage IS NOT NULL AND IsSuggested = 1;
    PRINT 'Created table: KeywordTopics';
END
GO

-- ── Keywords ─────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.Keywords', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Keywords (
        KeywordId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Keywords PRIMARY KEY,
        Site               NVARCHAR(20)     NOT NULL CONSTRAINT CK_Keywords_Site CHECK (Site IN ('doctordekho', 'nexeagle')),
        Text               NVARCHAR(300)    NOT NULL,   -- as first seen (lower case)
        Normalized         NVARCHAR(300)    NOT NULL,   -- for matching: lower case, single spaces, no punctuation
        Language           NVARCHAR(10)     NOT NULL CONSTRAINT CK_Keywords_Language CHECK (Language IN ('en', 'hi', 'hg', 'bn', 'other')),
        LanguageByPerson   BIT              NOT NULL CONSTRAINT DF_Keywords_LanguageByPerson DEFAULT (0),
        Intent             NVARCHAR(20)     NOT NULL,   -- doctor, nearme, info, cost, hospital, lab, software, howto, brand, other
        IntentByPerson     BIT              NOT NULL CONSTRAINT DF_Keywords_IntentByPerson DEFAULT (0),
        City               NVARCHAR(80)     NULL,
        TopicId            UNIQUEIDENTIFIER NULL CONSTRAINT FK_Keywords_Topic REFERENCES dbo.KeywordTopics(TopicId) ON DELETE SET NULL,
        TopicByPerson      BIT              NOT NULL CONSTRAINT DF_Keywords_TopicByPerson DEFAULT (0),
        Status             NVARCHAR(10)     NOT NULL CONSTRAINT DF_Keywords_Status DEFAULT ('active') CONSTRAINT CK_Keywords_Status CHECK (Status IN ('active', 'ignored')),
        Sources            NVARCHAR(100)    NOT NULL CONSTRAINT DF_Keywords_Sources DEFAULT (''),  -- "gsc,planner,site"
        AvgMonthlySearches BIGINT           NULL,       -- Keyword Planner, India
        Competition        NVARCHAR(10)     NULL,       -- LOW, MEDIUM, HIGH
        CompetitionIndex   INT              NULL,
        LowBid             DECIMAL(12, 2)   NULL,       -- top-of-page bid range, account currency
        HighBid            DECIMAL(12, 2)   NULL,
        MonthlyJson        NVARCHAR(2000)   NULL,       -- [{"y":2026,"m":10,"v":1200},...]
        VolumeAt           DATETIME2(0)     NULL,
        FirstSeenAt        DATETIME2(0)     NOT NULL,
        LastSeenAt         DATETIME2(0)     NOT NULL
    );
    CREATE UNIQUE INDEX UX_Keywords_SiteText ON dbo.Keywords (Site, Normalized);
    CREATE INDEX IX_Keywords_Topic ON dbo.Keywords (TopicId);
    CREATE INDEX IX_Keywords_Volume ON dbo.Keywords (VolumeAt);
    PRINT 'Created table: Keywords';
END
GO

-- ── Daily numbers ────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.KeywordObservations', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.KeywordObservations (
        ObservationId BIGINT IDENTITY(1, 1) NOT NULL CONSTRAINT PK_KeywordObservations PRIMARY KEY,
        KeywordId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_KeywordObservations_Keyword REFERENCES dbo.Keywords(KeywordId) ON DELETE CASCADE,
        Day           DATE             NOT NULL,
        Source        NVARCHAR(10)     NOT NULL CONSTRAINT CK_KeywordObservations_Source CHECK (Source IN ('gsc', 'ads', 'site')),
        Impressions   INT              NOT NULL CONSTRAINT DF_KeywordObservations_Impressions DEFAULT (0),  -- gsc and ads: times shown
        Clicks        INT              NOT NULL CONSTRAINT DF_KeywordObservations_Clicks DEFAULT (0),
        Position      DECIMAL(6, 2)    NULL,       -- gsc: average position that day
        Visitors      INT              NOT NULL CONSTRAINT DF_KeywordObservations_Visitors DEFAULT (0),     -- site: different visitors who typed it
        Cost          DECIMAL(12, 2)   NULL,       -- ads
        Conversions   DECIMAL(10, 2)   NULL,       -- ads
        Page          NVARCHAR(500)    NULL        -- gsc: the page shown most for it that day
    );
    CREATE UNIQUE INDEX UX_KeywordObservations ON dbo.KeywordObservations (KeywordId, Day, Source);
    CREATE INDEX IX_KeywordObservations_Day ON dbo.KeywordObservations (Day, Source) INCLUDE (KeywordId, Impressions, Clicks, Position, Visitors);
    PRINT 'Created table: KeywordObservations';
END
GO

-- ── Content plan ─────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.KeywordContent', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.KeywordContent (
        ContentId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_KeywordContent PRIMARY KEY,
        Site            NVARCHAR(20)     NOT NULL CONSTRAINT CK_KeywordContent_Site CHECK (Site IN ('doctordekho', 'nexeagle')),
        TopicId         UNIQUEIDENTIFIER NULL CONSTRAINT FK_KeywordContent_Topic REFERENCES dbo.KeywordTopics(TopicId) ON DELETE SET NULL,
        Kind            NVARCHAR(20)     NOT NULL CONSTRAINT CK_KeywordContent_Kind CHECK (Kind IN ('page', 'article', 'guide', 'social', 'whatsapp', 'ad')),
        Title           NVARCHAR(300)    NOT NULL,
        Stage           NVARCHAR(20)     NOT NULL CONSTRAINT CK_KeywordContent_Stage CHECK (Stage IN ('idea', 'brief', 'writing', 'review', 'ready', 'published')),
        Languages       NVARCHAR(40)     NOT NULL CONSTRAINT DF_KeywordContent_Languages DEFAULT ('en'),  -- "en,hi,bn"
        BriefJson       NVARCHAR(MAX)    NULL,       -- main keywords per language, outline, page, schema, reviewer, checklist
        OwnerUserId     UNIQUEIDENTIFIER NULL,
        DueDate         DATE             NULL,
        Url             NVARCHAR(500)    NULL,       -- where it was published
        PublishedAt     DATETIME2(0)     NULL,
        CreatedByUserId UNIQUEIDENTIFIER NULL,
        UpdatedByUserId UNIQUEIDENTIFIER NULL,
        CreatedAt       DATETIME2(0)     NOT NULL,
        UpdatedAt       DATETIME2(0)     NOT NULL
    );
    CREATE INDEX IX_KeywordContent_Stage ON dbo.KeywordContent (Site, Stage, UpdatedAt DESC);
    CREATE INDEX IX_KeywordContent_Topic ON dbo.KeywordContent (TopicId);
    PRINT 'Created table: KeywordContent';
END
GO

-- ── Source runs ──────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.KeywordSourceRuns', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.KeywordSourceRuns (
        SourceKey   NVARCHAR(30)   NOT NULL CONSTRAINT PK_KeywordSourceRuns PRIMARY KEY,  -- gsc, ads, planner, site
        LastRunAt   DATETIME2(0)   NULL,
        LastOkAt    DATETIME2(0)   NULL,
        LastCount   INT            NOT NULL CONSTRAINT DF_KeywordSourceRuns_LastCount DEFAULT (0),
        LastDetail  NVARCHAR(300)  NULL,
        LastError   NVARCHAR(1000) NULL
    );
    PRINT 'Created table: KeywordSourceRuns';
END
GO

-- ── Permissions ──────────────────────────────────────────────────────────────

MERGE dbo.CmsPermissions AS target
USING (VALUES
    ('keywords.view',    'keywords', 'view',    'See keywords, topics and the content plan',              143),
    ('keywords.edit',    'keywords', 'edit',    'Sort keywords, make topics and plan content',            144),
    ('keywords.connect', 'keywords', 'connect', 'Change keyword sources, seed lists and scoring',         145)
) AS source ([Key], PageKey, Action, DisplayName, SortOrder)
ON target.[Key] = source.[Key]
WHEN NOT MATCHED THEN
    INSERT (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (NEWID(), source.[Key], source.PageKey, source.Action, source.DisplayName, 'Keywords', source.SortOrder)
WHEN MATCHED THEN
    UPDATE SET DisplayName = source.DisplayName, Category = 'Keywords', SortOrder = source.SortOrder;
PRINT CONCAT('Keywords permissions added or updated: ', @@ROWCOUNT);
GO

DECLARE @Grants TABLE (RoleId UNIQUEIDENTIFIER, [Key] NVARCHAR(100));
INSERT @Grants SELECT 'B0000001-0000-0000-0000-000000000001', [Key] FROM dbo.CmsPermissions WHERE [Key] LIKE 'keywords.%';  -- Administrator
INSERT @Grants VALUES
    ('B0000001-0000-0000-0000-000000000004', 'keywords.view'),   -- Manager
    ('B0000001-0000-0000-0000-000000000004', 'keywords.edit'),
    ('B0000001-0000-0000-0000-000000000007', 'keywords.view'),   -- Marketing team
    ('B0000001-0000-0000-0000-000000000007', 'keywords.edit');

INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
SELECT DISTINCT g.RoleId, p.PermissionId
FROM @Grants g
JOIN dbo.CmsPermissions p ON p.[Key] = g.[Key]
JOIN dbo.CmsRoles r ON r.RoleId = g.RoleId
WHERE NOT EXISTS (SELECT 1 FROM dbo.CmsRolePermissions rp WHERE rp.RoleId = g.RoleId AND rp.PermissionId = p.PermissionId);
PRINT CONCAT('Keywords grants added: ', @@ROWCOUNT);
GO
