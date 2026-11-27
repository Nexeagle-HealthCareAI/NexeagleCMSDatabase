-- =============================================================================
-- CMSDatabase -- Social: Facebook Page and Instagram posts, publishing, comments,
-- Messenger and Instagram messages, lead ads, ad numbers
-- =============================================================================
-- Run after scripts 01 to 35.
--
-- CMS → Social works on one or more "accounts" (a Facebook Page, its Instagram
-- account and an ad account), e.g. NexEagle and Doctor Dekho. The Meta keys are
-- entered in Social → Setup; token and app secret are encrypted by the API.
-- Design: claude/social-facebook-instagram-design.md
--
--   SocialAccounts         one per brand: Page, Instagram account, ad account, encrypted keys
--   SocialAccountDaily     followers per day (for "new followers")
--   SocialPosts            every post on the Page and the Instagram account, with its latest numbers
--   SocialPostStats        a post's numbers per day for its first 30 days
--   SocialDrafts           posts written in the CMS: approval, schedule, publishing state
--   SocialQueueSlots       weekly times "Add to the queue" fills
--   SocialComments         comments on our posts, and our replies
--   SocialContacts         people in Messenger and Instagram direct messages, with the chat state
--   SocialMessages         every direct message in and out
--   SocialNotes            private notes on a conversation
--   SocialLeads            leads from lead forms, messages and comments, linked to the CRM lead
--   SocialLeadForms        lead forms and the missed-lead check
--   SocialAdStats          spend, impressions, clicks and leads per day per campaign / ad set / ad
--
-- Permissions (area "Social"): social.view, .reply, .compose, .publish, .ads, .connect.
-- Administrator gets all, Manager all but .connect; "Marketing team" gets view, reply, compose.
-- Safe to run more than once. People see new permissions when they next sign in.
-- =============================================================================

USE CMSDatabase;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ── Accounts ─────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.SocialAccounts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialAccounts (
        AccountId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_SocialAccounts PRIMARY KEY,
        Name               NVARCHAR(100)    NOT NULL,
        AppId              NVARCHAR(40)     NULL,
        AppSecretEnc       NVARCHAR(400)    NULL,
        -- System-user token (encrypted, "v1:..."); the Page token is read from it when needed.
        TokenEnc           NVARCHAR(MAX)    NULL,
        TokenHint          NVARCHAR(8)      NULL,
        VerifyTokenEnc     NVARCHAR(400)    NULL,
        PageId             NVARCHAR(40)     NULL,
        PageName           NVARCHAR(200)    NULL,
        IgUserId           NVARCHAR(40)     NULL,
        IgUsername         NVARCHAR(100)    NULL,
        AdAccountId        NVARCHAR(40)     NULL,
        AdAccountName      NVARCHAR(200)    NULL,
        Currency           NVARCHAR(3)      NULL,
        WebhookUrl         NVARCHAR(400)    NULL,
        WebhooksConnectedAt DATETIME2(3)    NULL,
        LastWebhookAt      DATETIME2(3)     NULL,
        PostsSyncedAt      DATETIME2(3)     NULL,
        AdsSyncedAt        DATETIME2(3)     NULL,
        LeadsCheckedAt     DATETIME2(3)     NULL,
        SyncError          NVARCHAR(400)    NULL,
        IsActive           BIT              NOT NULL CONSTRAINT DF_SocialAccounts_IsActive DEFAULT (1),
        SortOrder          INT              NOT NULL CONSTRAINT DF_SocialAccounts_Sort DEFAULT (0),
        UpdatedByUserId    UNIQUEIDENTIFIER NULL CONSTRAINT FK_SocialAccounts_UpdatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt          DATETIME2(3)     NOT NULL CONSTRAINT DF_SocialAccounts_Created DEFAULT (SYSUTCDATETIME()),
        UpdatedAt          DATETIME2(3)     NOT NULL CONSTRAINT DF_SocialAccounts_Updated DEFAULT (SYSUTCDATETIME())
    );
    CREATE UNIQUE INDEX UX_SocialAccounts_Name ON dbo.SocialAccounts (Name);
    CREATE UNIQUE INDEX UX_SocialAccounts_Page ON dbo.SocialAccounts (PageId) WHERE PageId IS NOT NULL;
    CREATE UNIQUE INDEX UX_SocialAccounts_Ig ON dbo.SocialAccounts (IgUserId) WHERE IgUserId IS NOT NULL;
    PRINT 'Created table: SocialAccounts';
END
GO

IF OBJECT_ID('dbo.SocialAccountDaily', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialAccountDaily (
        AccountId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialAccountDaily_Account REFERENCES dbo.SocialAccounts(AccountId) ON DELETE CASCADE,
        Day           DATE             NOT NULL,
        FbFollowers   INT              NULL,
        IgFollowers   INT              NULL,
        CONSTRAINT PK_SocialAccountDaily PRIMARY KEY (AccountId, Day)
    );
    PRINT 'Created table: SocialAccountDaily';
END
GO

-- ── Posts ────────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.SocialPosts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialPosts (
        PostId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_SocialPosts PRIMARY KEY,
        AccountId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialPosts_Account REFERENCES dbo.SocialAccounts(AccountId) ON DELETE CASCADE,
        Channel       NVARCHAR(12)     NOT NULL CONSTRAINT CK_SocialPosts_Channel CHECK (Channel IN ('facebook', 'instagram')),
        MetaId        NVARCHAR(80)     NOT NULL,
        Type          NVARCHAR(20)     NOT NULL,   -- Photo, Video, Reel, Carousel, Story, Link, Text
        Caption       NVARCHAR(MAX)    NULL,
        ThumbnailUrl  NVARCHAR(1000)   NULL,
        Permalink     NVARCHAR(500)    NULL,
        PublishedAt   DATETIME2(3)     NOT NULL,
        DraftId       UNIQUEIDENTIFIER NULL,       -- set when the CMS published it
        Views         INT              NULL,
        Reach         INT              NULL,
        Likes         INT              NULL,
        Comments      INT              NULL,
        Shares        INT              NULL,
        Saves         INT              NULL,
        Clicks        INT              NULL,
        -- Everything Meta returned, by metric name.
        StatsJson     NVARCHAR(MAX)    NULL,
        StatsAt       DATETIME2(3)     NULL,
        CreatedAt     DATETIME2(3)     NOT NULL CONSTRAINT DF_SocialPosts_Created DEFAULT (SYSUTCDATETIME())
    );
    CREATE UNIQUE INDEX UX_SocialPosts_Meta ON dbo.SocialPosts (Channel, MetaId);
    CREATE INDEX IX_SocialPosts_Account ON dbo.SocialPosts (AccountId, PublishedAt DESC);
    PRINT 'Created table: SocialPosts';
END
GO

IF OBJECT_ID('dbo.SocialPostStats', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialPostStats (
        PostId    UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialPostStats_Post REFERENCES dbo.SocialPosts(PostId) ON DELETE CASCADE,
        Day       DATE             NOT NULL,
        Views     INT              NULL,
        Reach     INT              NULL,
        Likes     INT              NULL,
        Comments  INT              NULL,
        Shares    INT              NULL,
        Saves     INT              NULL,
        CONSTRAINT PK_SocialPostStats PRIMARY KEY (PostId, Day)
    );
    PRINT 'Created table: SocialPostStats';
END
GO

-- ── Writing and publishing ───────────────────────────────────────────────────

IF OBJECT_ID('dbo.SocialDrafts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialDrafts (
        DraftId            UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_SocialDrafts PRIMARY KEY,
        AccountId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialDrafts_Account REFERENCES dbo.SocialAccounts(AccountId) ON DELETE CASCADE,
        Title              NVARCHAR(150)    NOT NULL,
        ToFacebook         BIT              NOT NULL,
        ToInstagram        BIT              NOT NULL,
        Kind               NVARCHAR(20)     NOT NULL CONSTRAINT CK_SocialDrafts_Kind CHECK (Kind IN ('Photo', 'Carousel', 'Video', 'Reel', 'Story', 'Text', 'Link')),
        Caption            NVARCHAR(MAX)    NULL,
        FacebookCaption    NVARCHAR(MAX)    NULL,     -- null: same as Caption
        InstagramCaption   NVARCHAR(MAX)    NULL,
        Link               NVARCHAR(1000)   NULL,
        -- [{ "key": "social/drafts/<id>/<n>.jpg", "mime": "image/jpeg", "name": "…", "size": 123 }]
        MediaJson          NVARCHAR(MAX)    NULL,
        WhenMode           NVARCHAR(12)     NOT NULL CONSTRAINT CK_SocialDrafts_When CHECK (WhenMode IN ('approved', 'schedule', 'queue')),
        ScheduledAt        DATETIME2(3)     NULL,
        Status             NVARCHAR(20)     NOT NULL CONSTRAINT CK_SocialDrafts_Status CHECK (Status IN ('Draft', 'AwaitingApproval', 'SentBack', 'Scheduled', 'Publishing', 'Published', 'Failed', 'Cancelled')),
        ChecklistJson      NVARCHAR(1000)   NULL,
        ApproverUserId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_SocialDrafts_Approver REFERENCES dbo.CmsUsers(UserId),
        ApprovedByUserId   UNIQUEIDENTIFIER NULL CONSTRAINT FK_SocialDrafts_ApprovedBy REFERENCES dbo.CmsUsers(UserId),
        ApprovedAt         DATETIME2(3)     NULL,
        -- SHA-256 of what was approved (captions, link, media keys): a change after approval needs approval again.
        ApprovedHash       NVARCHAR(64)     NULL,
        SentBackNote       NVARCHAR(1000)   NULL,
        FacebookPostId     NVARCHAR(80)     NULL,
        InstagramMediaId   NVARCHAR(80)     NULL,
        -- Instagram containers being prepared (JSON), and the step reached.
        PublishStateJson   NVARCHAR(MAX)    NULL,
        Attempts           INT              NOT NULL CONSTRAINT DF_SocialDrafts_Attempts DEFAULT (0),
        Error              NVARCHAR(1000)   NULL,
        PublishedAt        DATETIME2(3)     NULL,
        CreatedByUserId    UNIQUEIDENTIFIER NULL CONSTRAINT FK_SocialDrafts_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt          DATETIME2(3)     NOT NULL CONSTRAINT DF_SocialDrafts_Created DEFAULT (SYSUTCDATETIME()),
        UpdatedAt          DATETIME2(3)     NOT NULL CONSTRAINT DF_SocialDrafts_Updated DEFAULT (SYSUTCDATETIME())
    );
    CREATE INDEX IX_SocialDrafts_Due ON dbo.SocialDrafts (Status, ScheduledAt);
    CREATE INDEX IX_SocialDrafts_Account ON dbo.SocialDrafts (AccountId, ScheduledAt);
    PRINT 'Created table: SocialDrafts';
END
GO

IF OBJECT_ID('dbo.SocialQueueSlots', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialQueueSlots (
        SlotId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_SocialQueueSlots PRIMARY KEY,
        AccountId    UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialQueueSlots_Account REFERENCES dbo.SocialAccounts(AccountId) ON DELETE CASCADE,
        DayOfWeek    TINYINT          NOT NULL CONSTRAINT CK_SocialQueueSlots_Day CHECK (DayOfWeek BETWEEN 0 AND 6),  -- 0 = Sunday
        TimeOfDay    TIME(0)          NOT NULL,   -- India time
        ToFacebook   BIT              NOT NULL,
        ToInstagram  BIT              NOT NULL
    );
    PRINT 'Created table: SocialQueueSlots';
END
GO

-- ── Comments ─────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.SocialComments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialComments (
        CommentId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_SocialComments PRIMARY KEY,
        AccountId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialComments_Account REFERENCES dbo.SocialAccounts(AccountId) ON DELETE CASCADE,
        Channel            NVARCHAR(12)     NOT NULL CONSTRAINT CK_SocialComments_Channel CHECK (Channel IN ('facebook', 'instagram')),
        MetaId             NVARCHAR(80)     NOT NULL,
        PostMetaId         NVARCHAR(80)     NOT NULL,
        ParentMetaId       NVARCHAR(80)     NULL,
        AuthorId           NVARCHAR(80)     NULL,
        AuthorName         NVARCHAR(200)    NULL,
        Text               NVARCHAR(MAX)    NULL,
        FromUs             BIT              NOT NULL CONSTRAINT DF_SocialComments_FromUs DEFAULT (0),
        Hidden             BIT              NOT NULL CONSTRAINT DF_SocialComments_Hidden DEFAULT (0),
        Deleted            BIT              NOT NULL CONSTRAINT DF_SocialComments_Deleted DEFAULT (0),
        -- Open: waiting for us; Done: answered or nothing to do.
        Status             NVARCHAR(10)     NOT NULL CONSTRAINT DF_SocialComments_Status DEFAULT ('Open') CONSTRAINT CK_SocialComments_Status CHECK (Status IN ('Open', 'Done')),
        RepliedByUserId    UNIQUEIDENTIFIER NULL CONSTRAINT FK_SocialComments_RepliedBy REFERENCES dbo.CmsUsers(UserId),
        PrivateReplyAt     DATETIME2(3)     NULL,
        AssignedUserId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_SocialComments_Assigned REFERENCES dbo.CmsUsers(UserId),
        CreatedAt          DATETIME2(3)     NOT NULL
    );
    CREATE UNIQUE INDEX UX_SocialComments_Meta ON dbo.SocialComments (Channel, MetaId);
    CREATE INDEX IX_SocialComments_Open ON dbo.SocialComments (AccountId, Status, CreatedAt DESC);
    CREATE INDEX IX_SocialComments_Post ON dbo.SocialComments (PostMetaId);
    PRINT 'Created table: SocialComments';
END
GO

-- ── Direct messages (Messenger, Instagram) ───────────────────────────────────

IF OBJECT_ID('dbo.SocialContacts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialContacts (
        ContactId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_SocialContacts PRIMARY KEY,
        AccountId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialContacts_Account REFERENCES dbo.SocialAccounts(AccountId) ON DELETE CASCADE,
        Channel            NVARCHAR(12)     NOT NULL CONSTRAINT CK_SocialContacts_Channel CHECK (Channel IN ('messenger', 'instagram')),
        -- Page-scoped id (Messenger) or Instagram-scoped id: what Meta calls this person for this Page.
        ExternalId         NVARCHAR(80)     NOT NULL,
        Name               NVARCHAR(200)    NULL,
        Username           NVARCHAR(100)    NULL,
        LastInboundAt      DATETIME2(3)     NULL,
        LastMessageAt      DATETIME2(3)     NULL,
        LastMessagePreview NVARCHAR(200)    NULL,
        UnreadCount        INT              NOT NULL CONSTRAINT DF_SocialContacts_Unread DEFAULT (0),
        ChatStatus         NVARCHAR(10)     NOT NULL CONSTRAINT DF_SocialContacts_Status DEFAULT ('Open') CONSTRAINT CK_SocialContacts_Status CHECK (ChatStatus IN ('Open', 'Closed')),
        AssignedUserId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_SocialContacts_Assigned REFERENCES dbo.CmsUsers(UserId),
        LeadId             UNIQUEIDENTIFIER NULL,
        CreatedAt          DATETIME2(3)     NOT NULL CONSTRAINT DF_SocialContacts_Created DEFAULT (SYSUTCDATETIME())
    );
    CREATE UNIQUE INDEX UX_SocialContacts_External ON dbo.SocialContacts (AccountId, Channel, ExternalId);
    CREATE INDEX IX_SocialContacts_Recent ON dbo.SocialContacts (AccountId, ChatStatus, LastMessageAt DESC);
    PRINT 'Created table: SocialContacts';
END
GO

IF OBJECT_ID('dbo.SocialMessages', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialMessages (
        MessageId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_SocialMessages PRIMARY KEY,
        ContactId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialMessages_Contact REFERENCES dbo.SocialContacts(ContactId) ON DELETE CASCADE,
        Direction        NVARCHAR(3)      NOT NULL CONSTRAINT CK_SocialMessages_Direction CHECK (Direction IN ('In', 'Out')),
        MetaId           NVARCHAR(200)    NULL,
        Text             NVARCHAR(MAX)    NULL,
        -- [{ "type": "image", "url": "…" }] as Meta sent them, or what we sent.
        AttachmentsJson  NVARCHAR(MAX)    NULL,
        Status           NVARCHAR(12)     NOT NULL,  -- received, sent, delivered, read, failed
        Error            NVARCHAR(500)    NULL,
        HumanAgent       BIT              NOT NULL CONSTRAINT DF_SocialMessages_HumanAgent DEFAULT (0),
        SentByUserId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_SocialMessages_SentBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt        DATETIME2(3)     NOT NULL
    );
    CREATE UNIQUE INDEX UX_SocialMessages_Meta ON dbo.SocialMessages (MetaId) WHERE MetaId IS NOT NULL;
    CREATE INDEX IX_SocialMessages_Contact ON dbo.SocialMessages (ContactId, CreatedAt);
    PRINT 'Created table: SocialMessages';
END
GO

IF OBJECT_ID('dbo.SocialNotes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialNotes (
        NoteId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_SocialNotes PRIMARY KEY,
        ContactId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialNotes_Contact REFERENCES dbo.SocialContacts(ContactId) ON DELETE CASCADE,
        UserId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialNotes_User REFERENCES dbo.CmsUsers(UserId),
        Text        NVARCHAR(2000)   NOT NULL,
        CreatedAt   DATETIME2(3)     NOT NULL
    );
    CREATE INDEX IX_SocialNotes_Contact ON dbo.SocialNotes (ContactId, CreatedAt);
    PRINT 'Created table: SocialNotes';
END
GO

-- ── Leads ────────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.SocialLeads', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialLeads (
        SocialLeadId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_SocialLeads PRIMARY KEY,
        AccountId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialLeads_Account REFERENCES dbo.SocialAccounts(AccountId) ON DELETE CASCADE,
        -- The CRM lead (CmsSalesLeads). No foreign key: a lead deleted in the CRM keeps this record.
        LeadId         UNIQUEIDENTIFIER NOT NULL,
        Source         NVARCHAR(20)     NOT NULL CONSTRAINT CK_SocialLeads_Source CHECK (Source IN ('form', 'messenger', 'instagram', 'comment')),
        MetaLeadId     NVARCHAR(80)     NULL,
        FormId         NVARCHAR(80)     NULL,
        FormName       NVARCHAR(200)    NULL,
        AdId           NVARCHAR(80)     NULL,
        AdName         NVARCHAR(300)    NULL,
        CampaignId     NVARCHAR(80)     NULL,
        CampaignName   NVARCHAR(300)    NULL,
        Platform       NVARCHAR(20)     NULL,     -- fb / ig, as Meta reports it
        IsOrganic      BIT              NULL,
        -- The person's answers: [{ "name": "…", "value": "…" }].
        AnswersJson    NVARCHAR(MAX)    NULL,
        ContactId      UNIQUEIDENTIFIER NULL,     -- SocialContacts, for leads from messages
        CommentId      UNIQUEIDENTIFIER NULL,     -- SocialComments, for leads from comments
        ReceivedAt     DATETIME2(3)     NOT NULL,
        CreatedByUserId UNIQUEIDENTIFIER NULL
    );
    CREATE UNIQUE INDEX UX_SocialLeads_Meta ON dbo.SocialLeads (MetaLeadId) WHERE MetaLeadId IS NOT NULL;
    CREATE INDEX IX_SocialLeads_Account ON dbo.SocialLeads (AccountId, ReceivedAt DESC);
    PRINT 'Created table: SocialLeads';
END
GO

IF OBJECT_ID('dbo.SocialLeadForms', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialLeadForms (
        FormId         NVARCHAR(80)     NOT NULL CONSTRAINT PK_SocialLeadForms PRIMARY KEY,
        AccountId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialLeadForms_Account REFERENCES dbo.SocialAccounts(AccountId) ON DELETE CASCADE,
        Name           NVARCHAR(200)    NOT NULL,
        Status         NVARCHAR(20)     NULL,
        -- Last check: leads at Meta in the last 30 days, and the ids missing from the CRM (JSON array).
        MetaCount      INT              NULL,
        CrmCount       INT              NULL,
        MissingJson    NVARCHAR(MAX)    NULL,
        CheckedAt      DATETIME2(3)     NULL
    );
    PRINT 'Created table: SocialLeadForms';
END
GO

-- ── Ads ──────────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.SocialAdStats', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SocialAdStats (
        AccountId    UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_SocialAdStats_Account REFERENCES dbo.SocialAccounts(AccountId) ON DELETE CASCADE,
        Day          DATE             NOT NULL,
        Level        NVARCHAR(10)     NOT NULL CONSTRAINT CK_SocialAdStats_Level CHECK (Level IN ('campaign', 'adset', 'ad')),
        ObjectId     NVARCHAR(80)     NOT NULL,
        Name         NVARCHAR(300)    NOT NULL,
        ParentName   NVARCHAR(300)    NULL,       -- campaign of an ad set; campaign · ad set of an ad
        Status       NVARCHAR(30)     NULL,
        Spend        DECIMAL(14, 2)   NOT NULL,
        Impressions  INT              NOT NULL,
        Clicks       INT              NOT NULL,
        Leads        INT              NOT NULL,
        Conversations INT             NOT NULL CONSTRAINT DF_SocialAdStats_Conv DEFAULT (0),
        CONSTRAINT PK_SocialAdStats PRIMARY KEY (AccountId, Day, Level, ObjectId)
    );
    PRINT 'Created table: SocialAdStats';
END
GO

-- ── Permissions ──────────────────────────────────────────────────────────────

MERGE dbo.CmsPermissions AS target
USING (VALUES
    ('social.view',    'social', 'view',    'See Facebook and Instagram posts, leads and the social inbox', 130),
    ('social.reply',   'social', 'reply',   'Reply to comments and messages, make leads from them',         131),
    ('social.compose', 'social', 'compose', 'Write posts and send them for approval',                       132),
    ('social.publish', 'social', 'publish', 'Approve and publish posts',                                    133),
    ('social.ads',     'social', 'ads',     'See ad spend and results',                                     134),
    ('social.connect', 'social', 'connect', 'Connect the Facebook Page, Instagram and ad accounts',         135)
) AS source ([Key], PageKey, Action, DisplayName, SortOrder)
ON target.[Key] = source.[Key]
WHEN NOT MATCHED THEN
    INSERT (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (NEWID(), source.[Key], source.PageKey, source.Action, source.DisplayName, 'Social', source.SortOrder)
WHEN MATCHED THEN
    UPDATE SET DisplayName = source.DisplayName, Category = 'Social', SortOrder = source.SortOrder;
PRINT CONCAT('Social permissions added or updated: ', @@ROWCOUNT);
GO

UPDATE dbo.CmsRoles
SET Description = 'Marketing: the WhatsApp inbox, contacts, templates and broadcasts; social posts, comments and messages (not budget, approval or settings).'
WHERE RoleId = 'B0000001-0000-0000-0000-000000000007';
GO

DECLARE @Grants TABLE (RoleId UNIQUEIDENTIFIER, [Key] NVARCHAR(100));
INSERT @Grants SELECT 'B0000001-0000-0000-0000-000000000001', [Key] FROM dbo.CmsPermissions WHERE [Key] LIKE 'social.%';  -- Administrator
INSERT @Grants SELECT 'B0000001-0000-0000-0000-000000000004', [Key] FROM dbo.CmsPermissions WHERE [Key] LIKE 'social.%' AND [Key] <> 'social.connect';  -- Manager
INSERT @Grants VALUES
    ('B0000001-0000-0000-0000-000000000007', 'social.view'),
    ('B0000001-0000-0000-0000-000000000007', 'social.reply'),
    ('B0000001-0000-0000-0000-000000000007', 'social.compose');

INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
SELECT DISTINCT g.RoleId, p.PermissionId
FROM @Grants g
JOIN dbo.CmsPermissions p ON p.[Key] = g.[Key]
JOIN dbo.CmsRoles r ON r.RoleId = g.RoleId
WHERE NOT EXISTS (SELECT 1 FROM dbo.CmsRolePermissions rp WHERE rp.RoleId = g.RoleId AND rp.PermissionId = p.PermissionId);
PRINT CONCAT('Social grants added: ', @@ROWCOUNT);
GO
