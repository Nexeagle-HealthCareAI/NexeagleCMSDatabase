-- =============================================================================
-- CMSDatabase -- WhatsApp marketing: inbox, templates, contacts, broadcasts, spend
-- =============================================================================
-- Run after scripts 01 to 34.
--
-- The CMS's WhatsApp section works on a marketing number of its own (not the
-- Doctor Dekho bot's). Its connection (phone number id, account id, token, app
-- secret) is entered in CMS → WhatsApp → Setup and kept in WaConnection, the secrets
-- encrypted by the API. Design: claude/whatsapp-marketing-design.md
--
--   WaContacts              everyone the number may message, with opt-in, and the chat state
--   WaMessages              every message in and out, with delivery status and cost
--   WaNotes                 private notes on a chat
--   WaTemplates             message templates as Meta has them, with approval status
--   WaBroadcasts            a template sent to an audience
--   WaBroadcastRecipients   one row per person per broadcast
--   WaRates                 price per message by country and category (editable)
--   WaSettings              monthly budget, sending speed (one row)
--   WaConnection            the Meta connection: ids, encrypted token and secrets (one row)
--
-- Permissions (area "WhatsApp"): whatsapp.view, .reply, .contacts, .broadcast,
-- .templates, .approve, .settings, .connect. Administrator gets all, Manager all but
-- .connect (the Meta keys); the new role
-- "Marketing team" gets view, reply, contacts, broadcast and templates.
-- Safe to run more than once. People see new permissions when they next sign in.
-- =============================================================================

USE CMSDatabase;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ── Contacts and chats ───────────────────────────────────────────────────────

IF OBJECT_ID('dbo.WaContacts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WaContacts (
        ContactId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WaContacts PRIMARY KEY,
        Phone             NVARCHAR(20)     NOT NULL,   -- digits with country code, no "+": 919876543210 (as Meta sends wa_id)
        Name              NVARCHAR(150)    NULL,
        ProfileName       NVARCHAR(150)    NULL,       -- the name the person set in WhatsApp
        Source            NVARCHAR(20)     NOT NULL,   -- Lead / DoctorDekho / Import / Inbound / Manual
        LeadId            UNIQUEIDENTIFIER NULL,       -- CmsSalesLeads, when it came from a lead
        OptIn             NVARCHAR(10)     NOT NULL CONSTRAINT DF_WaContacts_OptIn DEFAULT ('Unknown'),  -- Unknown / OptedIn / OptedOut
        OptInSource       NVARCHAR(200)    NULL,       -- how they agreed: "Website form", "Asked on a call"...
        OptInByUserId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaContacts_OptInBy REFERENCES dbo.CmsUsers(UserId),
        OptInAt           DATETIME2(3)     NULL,
        OptOutAt          DATETIME2(3)     NULL,
        OptOutReason      NVARCHAR(200)    NULL,
        Tags              NVARCHAR(400)    NULL,       -- comma separated, lower case
        Attributes        NVARCHAR(MAX)    NULL,       -- JSON {"city":"Purnia",...} for template variables
        LastInboundAt     DATETIME2(3)     NULL,       -- the 24-hour reply window runs from here
        LastMessageAt     DATETIME2(3)     NULL,
        LastMessagePreview NVARCHAR(200)   NULL,
        UnreadCount       INT              NOT NULL CONSTRAINT DF_WaContacts_Unread DEFAULT (0),
        ChatStatus        NVARCHAR(10)     NOT NULL CONSTRAINT DF_WaContacts_ChatStatus DEFAULT ('Open'),   -- Open / Closed
        AssignedUserId    UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaContacts_Assigned REFERENCES dbo.CmsUsers(UserId),
        CreatedByUserId   UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaContacts_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WaContacts_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WaContacts_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_WaContacts_Phone UNIQUE (Phone),
        CONSTRAINT CK_WaContacts_OptIn CHECK (OptIn IN ('Unknown', 'OptedIn', 'OptedOut')),
        CONSTRAINT CK_WaContacts_ChatStatus CHECK (ChatStatus IN ('Open', 'Closed'))
    );
    CREATE INDEX IX_WaContacts_LastMessage ON dbo.WaContacts (LastMessageAt DESC);
    PRINT 'Created table: WaContacts';
END
GO

IF OBJECT_ID('dbo.WaTemplates', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WaTemplates (
        TemplateId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WaTemplates PRIMARY KEY,
        MetaTemplateId    NVARCHAR(40)     NULL,       -- Meta's id once submitted
        Name              NVARCHAR(512)    NOT NULL,   -- lower case, digits and _ (Meta's rule)
        Language          NVARCHAR(15)     NOT NULL,   -- en, en_US, hi...
        Category          NVARCHAR(20)     NOT NULL,   -- MARKETING / UTILITY / AUTHENTICATION
        Status            NVARCHAR(20)     NOT NULL,   -- DRAFT / PENDING / APPROVED / REJECTED / PAUSED / DISABLED / IN_APPEAL
        RejectedReason    NVARCHAR(400)    NULL,
        QualityScore      NVARCHAR(20)     NULL,       -- GREEN / YELLOW / RED / UNKNOWN
        ParameterFormat   NVARCHAR(12)     NOT NULL CONSTRAINT DF_WaTemplates_ParamFormat DEFAULT ('POSITIONAL'),
        Components        NVARCHAR(MAX)    NOT NULL,   -- Meta's components JSON
        HeaderMediaKey    NVARCHAR(300)    NULL,       -- the sample picture/video/document kept for sending (file store key)
        CreatedByUserId   UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaTemplates_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WaTemplates_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WaTemplates_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        SyncedAt          DATETIME2(3)     NULL,       -- last read back from Meta
        CONSTRAINT UQ_WaTemplates_Name_Language UNIQUE (Name, Language)
    );
    PRINT 'Created table: WaTemplates';
END
GO

IF OBJECT_ID('dbo.WaBroadcasts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WaBroadcasts (
        BroadcastId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WaBroadcasts PRIMARY KEY,
        Name              NVARCHAR(150)    NOT NULL,
        TemplateId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WaBroadcasts_Template REFERENCES dbo.WaTemplates(TemplateId),
        Variables         NVARCHAR(MAX)    NULL,       -- JSON: how each template variable is filled
        HeaderMediaUrl    NVARCHAR(1000)   NULL,       -- https link for a picture/video/document header, when not the template's sample
        Audience          NVARCHAR(MAX)    NULL,       -- JSON: the filters that chose the recipients
        Status            NVARCHAR(20)     NOT NULL,   -- Draft / AwaitingApproval / Scheduled / Sending / Paused / Done / Cancelled
        PausedReason      NVARCHAR(200)    NULL,
        ScheduledAt       DATETIME2(3)     NULL,
        StartedAt         DATETIME2(3)     NULL,
        FinishedAt        DATETIME2(3)     NULL,
        Recipients        INT              NOT NULL CONSTRAINT DF_WaBroadcasts_Recipients DEFAULT (0),
        Sent              INT              NOT NULL CONSTRAINT DF_WaBroadcasts_Sent DEFAULT (0),
        Delivered         INT              NOT NULL CONSTRAINT DF_WaBroadcasts_Delivered DEFAULT (0),
        [Read]            INT              NOT NULL CONSTRAINT DF_WaBroadcasts_Read DEFAULT (0),
        Failed            INT              NOT NULL CONSTRAINT DF_WaBroadcasts_Failed DEFAULT (0),
        Replied           INT              NOT NULL CONSTRAINT DF_WaBroadcasts_Replied DEFAULT (0),
        EstimatedCost     DECIMAL(12,4)    NOT NULL CONSTRAINT DF_WaBroadcasts_Estimate DEFAULT (0),
        ActualCost        DECIMAL(12,4)    NOT NULL CONSTRAINT DF_WaBroadcasts_Actual DEFAULT (0),
        Currency          NVARCHAR(3)      NOT NULL CONSTRAINT DF_WaBroadcasts_Currency DEFAULT ('INR'),
        CreatedByUserId   UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaBroadcasts_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        ApprovedByUserId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaBroadcasts_ApprovedBy REFERENCES dbo.CmsUsers(UserId),
        ApprovedAt        DATETIME2(3)     NULL,
        CreatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WaBroadcasts_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WaBroadcasts_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_WaBroadcasts_Status CHECK (Status IN ('Draft', 'AwaitingApproval', 'Scheduled', 'Sending', 'Paused', 'Done', 'Cancelled'))
    );
    PRINT 'Created table: WaBroadcasts';
END
GO

IF OBJECT_ID('dbo.WaMessages', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WaMessages (
        MessageId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WaMessages PRIMARY KEY,
        ContactId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WaMessages_Contact REFERENCES dbo.WaContacts(ContactId) ON DELETE CASCADE,
        Direction         NVARCHAR(3)      NOT NULL,   -- In / Out
        WamId             NVARCHAR(200)    NULL,       -- Meta's message id
        Type              NVARCHAR(20)     NOT NULL,   -- text, image, video, audio, document, sticker, location, contacts, interactive, button, reaction, template, unsupported
        Body              NVARCHAR(MAX)    NULL,       -- the text (or the caption, or a template as people saw it)
        MediaId           NVARCHAR(100)    NULL,       -- Meta media id (downloaded through the CMS)
        MediaMime         NVARCHAR(100)    NULL,
        MediaName         NVARCHAR(260)    NULL,
        TemplateName      NVARCHAR(512)    NULL,
        TemplateLanguage  NVARCHAR(15)     NULL,
        BroadcastId       UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaMessages_Broadcast REFERENCES dbo.WaBroadcasts(BroadcastId),
        ReplyToWamId      NVARCHAR(200)    NULL,
        SentByUserId      UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaMessages_SentBy REFERENCES dbo.CmsUsers(UserId),
        Status            NVARCHAR(12)     NOT NULL,   -- received / queued / sent / delivered / read / failed
        StatusAt          DATETIME2(3)     NULL,
        ErrorCode         INT              NULL,
        ErrorText         NVARCHAR(400)    NULL,
        PricingCategory   NVARCHAR(30)     NULL,       -- from Meta: marketing, utility, authentication, service...
        Billable          BIT              NULL,
        Cost              DECIMAL(12,4)    NOT NULL CONSTRAINT DF_WaMessages_Cost DEFAULT (0),
        Currency          NVARCHAR(3)      NOT NULL CONSTRAINT DF_WaMessages_Currency DEFAULT ('INR'),
        CreatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WaMessages_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_WaMessages_Direction CHECK (Direction IN ('In', 'Out'))
    );
    CREATE UNIQUE INDEX UX_WaMessages_WamId ON dbo.WaMessages (WamId) WHERE WamId IS NOT NULL;
    CREATE INDEX IX_WaMessages_Contact ON dbo.WaMessages (ContactId, CreatedAt);
    CREATE INDEX IX_WaMessages_Broadcast ON dbo.WaMessages (BroadcastId) WHERE BroadcastId IS NOT NULL;
    CREATE INDEX IX_WaMessages_Billing ON dbo.WaMessages (StatusAt) INCLUDE (Cost, PricingCategory, Billable) WHERE Direction = 'Out';
    PRINT 'Created table: WaMessages';
END
GO

IF OBJECT_ID('dbo.WaNotes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WaNotes (
        NoteId            UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WaNotes PRIMARY KEY,
        ContactId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WaNotes_Contact REFERENCES dbo.WaContacts(ContactId) ON DELETE CASCADE,
        UserId            UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WaNotes_User REFERENCES dbo.CmsUsers(UserId),
        Text              NVARCHAR(2000)   NOT NULL,
        CreatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WaNotes_CreatedAt DEFAULT (SYSUTCDATETIME())
    );
    CREATE INDEX IX_WaNotes_Contact ON dbo.WaNotes (ContactId, CreatedAt);
    PRINT 'Created table: WaNotes';
END
GO

IF OBJECT_ID('dbo.WaBroadcastRecipients', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WaBroadcastRecipients (
        BroadcastId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WaRecipients_Broadcast REFERENCES dbo.WaBroadcasts(BroadcastId) ON DELETE CASCADE,
        ContactId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WaRecipients_Contact REFERENCES dbo.WaContacts(ContactId),
        Status            NVARCHAR(12)     NOT NULL,   -- Pending / Sent / Delivered / Read / Failed / Skipped
        MessageId         UNIQUEIDENTIFIER NULL,       -- WaMessages, once sent
        Error             NVARCHAR(400)    NULL,
        EstimatedCost     DECIMAL(12,4)    NOT NULL CONSTRAINT DF_WaRecipients_Estimate DEFAULT (0),
        SentAt            DATETIME2(3)     NULL,
        CONSTRAINT PK_WaBroadcastRecipients PRIMARY KEY (BroadcastId, ContactId)
    );
    CREATE INDEX IX_WaRecipients_Pending ON dbo.WaBroadcastRecipients (BroadcastId, Status);
    PRINT 'Created table: WaBroadcastRecipients';
END
GO

-- ── Money ────────────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.WaRates', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WaRates (
        Country           NVARCHAR(2)      NOT NULL,   -- ISO code: IN, AE, GB...; "**" for every other country
        Category          NVARCHAR(30)     NOT NULL,   -- marketing / utility / authentication / service
        Rate              DECIMAL(12,4)    NOT NULL,   -- per delivered, charged message, before GST
        Currency          NVARCHAR(3)      NOT NULL,
        UpdatedByUserId   UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaRates_UpdatedBy REFERENCES dbo.CmsUsers(UserId),
        UpdatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WaRates_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_WaRates PRIMARY KEY (Country, Category)
    );
    -- India, INR, as published for 2026 in a summary of Meta's rate card. CHECK these against Meta's
    -- rate card in WhatsApp Manager and correct them in CMS → WhatsApp → Settings → Rates.
    INSERT INTO dbo.WaRates (Country, Category, Rate, Currency) VALUES
        ('IN', 'marketing',      0.8631, 'INR'),
        ('IN', 'utility',        0.1150, 'INR'),
        ('IN', 'authentication', 0.1150, 'INR'),
        ('IN', 'service',        0.0000, 'INR');
    PRINT 'Created table: WaRates (India rates added; check them against Meta''s rate card)';
END
GO

IF OBJECT_ID('dbo.WaSettings', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WaSettings (
        SettingsId        INT              NOT NULL CONSTRAINT PK_WaSettings PRIMARY KEY CONSTRAINT CK_WaSettings_One CHECK (SettingsId = 1),
        MonthlyBudget     DECIMAL(12,2)    NULL,       -- null: no limit
        Currency          NVARCHAR(3)      NOT NULL CONSTRAINT DF_WaSettings_Currency DEFAULT ('INR'),
        SendPerSecond     INT              NOT NULL CONSTRAINT DF_WaSettings_Speed DEFAULT (20),
        UpdatedByUserId   UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaSettings_UpdatedBy REFERENCES dbo.CmsUsers(UserId),
        UpdatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WaSettings_UpdatedAt DEFAULT (SYSUTCDATETIME())
    );
    INSERT INTO dbo.WaSettings (SettingsId) VALUES (1);
    PRINT 'Created table: WaSettings';
END
GO

IF OBJECT_ID('dbo.WaConnection', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WaConnection (
        ConnectionId        INT              NOT NULL CONSTRAINT PK_WaConnection PRIMARY KEY CONSTRAINT CK_WaConnection_One CHECK (ConnectionId = 1),
        PhoneNumberId       NVARCHAR(40)     NULL,
        WabaId              NVARCHAR(40)     NULL,
        AppId               NVARCHAR(40)     NULL,
        -- Encrypted by the API (AES-GCM, "v1:..."); never readable from the database alone.
        AccessTokenEnc      NVARCHAR(MAX)    NULL,
        AppSecretEnc        NVARCHAR(400)    NULL,
        VerifyTokenEnc      NVARCHAR(400)    NULL,
        -- The last 4 characters of the token, to recognise which one is in use.
        AccessTokenHint     NVARCHAR(8)      NULL,
        WebhookUrl          NVARCHAR(400)    NULL,
        WebhookConnectedAt  DATETIME2(3)     NULL,
        LastWebhookAt       DATETIME2(3)     NULL,
        UpdatedByUserId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_WaConnection_UpdatedBy REFERENCES dbo.CmsUsers(UserId),
        UpdatedAt           DATETIME2(3)     NOT NULL CONSTRAINT DF_WaConnection_UpdatedAt DEFAULT (SYSUTCDATETIME())
    );
    INSERT INTO dbo.WaConnection (ConnectionId) VALUES (1);
    PRINT 'Created table: WaConnection';
END
GO

-- ── Permissions ──────────────────────────────────────────────────────────────

MERGE dbo.CmsPermissions AS target
USING (VALUES
    ('whatsapp.view',      'whatsapp', 'view',      'Read WhatsApp chats, broadcasts, templates and spend', 120),
    ('whatsapp.reply',     'whatsapp', 'reply',     'Reply to WhatsApp chats, assign them and add notes',   121),
    ('whatsapp.contacts',  'whatsapp', 'contacts',  'Add, import and change WhatsApp contacts and opt-ins', 122),
    ('whatsapp.broadcast', 'whatsapp', 'broadcast', 'Create and send WhatsApp broadcasts',                  123),
    ('whatsapp.templates', 'whatsapp', 'templates', 'Write WhatsApp templates and send them for approval',  124),
    ('whatsapp.approve',   'whatsapp', 'approve',   'Approve WhatsApp broadcasts that go over the budget',   125),
    ('whatsapp.settings',  'whatsapp', 'settings',  'Change the WhatsApp profile, budget and rates',        126),
    ('whatsapp.connect',   'whatsapp', 'connect',   'Connect the WhatsApp number: Meta keys and webhook',   127)
) AS source ([Key], PageKey, Action, DisplayName, SortOrder)
ON target.[Key] = source.[Key]
WHEN NOT MATCHED THEN
    INSERT (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (NEWID(), source.[Key], source.PageKey, source.Action, source.DisplayName, 'WhatsApp', source.SortOrder)
WHEN MATCHED THEN
    UPDATE SET DisplayName = source.DisplayName, Category = 'WhatsApp', SortOrder = source.SortOrder;
PRINT CONCAT('WhatsApp permissions added or updated: ', @@ROWCOUNT);
GO

-- The Marketing team role (a role someone made by hand with this name keeps its people, renamed "(own)").
UPDATE dbo.CmsRoles SET Name = LEFT(Name + ' (own)', 100)
WHERE Name = 'Marketing team' AND RoleId <> 'B0000001-0000-0000-0000-000000000007';

MERGE dbo.CmsRoles AS target
USING (VALUES ('B0000001-0000-0000-0000-000000000007', 'Marketing team',
               'WhatsApp marketing: the inbox, contacts, templates and broadcasts (not budget or settings).')) AS source (RoleId, Name, Description)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, Name, Description, IsSystemDefined, IsActive, CreatedAt)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), source.Name, source.Description, 1, 1, SYSUTCDATETIME())
WHEN MATCHED THEN
    UPDATE SET Name = source.Name, Description = source.Description, IsSystemDefined = 1, IsActive = 1;
GO

DECLARE @Grants TABLE (RoleId UNIQUEIDENTIFIER, [Key] NVARCHAR(100));
INSERT @Grants SELECT 'B0000001-0000-0000-0000-000000000001', [Key] FROM dbo.CmsPermissions WHERE [Key] LIKE 'whatsapp.%';  -- Administrator
INSERT @Grants SELECT 'B0000001-0000-0000-0000-000000000004', [Key] FROM dbo.CmsPermissions WHERE [Key] LIKE 'whatsapp.%' AND [Key] <> 'whatsapp.connect';  -- Manager
INSERT @Grants VALUES
    ('B0000001-0000-0000-0000-000000000007', 'whatsapp.view'),
    ('B0000001-0000-0000-0000-000000000007', 'whatsapp.reply'),
    ('B0000001-0000-0000-0000-000000000007', 'whatsapp.contacts'),
    ('B0000001-0000-0000-0000-000000000007', 'whatsapp.broadcast'),
    ('B0000001-0000-0000-0000-000000000007', 'whatsapp.templates');

INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
SELECT DISTINCT g.RoleId, p.PermissionId
FROM @Grants g
JOIN dbo.CmsPermissions p ON p.[Key] = g.[Key]
JOIN dbo.CmsRoles r ON r.RoleId = g.RoleId
WHERE NOT EXISTS (SELECT 1 FROM dbo.CmsRolePermissions rp WHERE rp.RoleId = g.RoleId AND rp.PermissionId = p.PermissionId);
PRINT CONCAT('WhatsApp grants added: ', @@ROWCOUNT);
GO
