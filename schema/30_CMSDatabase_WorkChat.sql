-- =============================================================================
-- CMSDatabase -- Daily Work Board: team chat and notifications
-- =============================================================================
-- Run after 29_CMSDatabase_WorkActivity.sql.
--
--   WorkChatChannels    a conversation. Kind is one of:
--                         Board   one per work board (project); everyone who can
--                                 open the board is in it. Created by the API the
--                                 first time it is needed.
--                         Group   a named group; its people are in WorkChatMembers.
--                         Direct  two people. DirectKey is their two ids, smaller
--                                 first, so a pair has exactly one conversation.
--   WorkChatMembers     who is in a Group or Direct channel, and for every kind
--                       how far each person has read (LastReadAt).
--   WorkChatMessages    the messages. IsImportant marks one to find again;
--                       IsEscalation marks a call for help. WorkItemId ties a
--                       message to a work item. Removing hides the row.
--   WorkChatMentions    who was tagged in a message.
--   WorkNotifications   what each person should be told: Mention, Escalation or
--                       Direct.
--
-- No new permission: chat is open to everyone with work.view. Removing someone
-- else's message needs work.delete.
-- Safe to run more than once.
-- =============================================================================

USE CMSDatabase;
GO

-- The two filtered indexes below need these on, and sqlcmd starts with QUOTED_IDENTIFIER off.
-- They stay on for every batch that follows in this script.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.WorkChatChannels', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkChatChannels (
        ChannelId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkChatChannels PRIMARY KEY,
        Kind             NVARCHAR(10)     NOT NULL,
        ProjectId        UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkChatChannels_Project REFERENCES dbo.WorkProjects(ProjectId),
        Name             NVARCHAR(80)     NULL,
        DirectKey        NVARCHAR(80)     NULL,
        CreatedByUserId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkChatChannels_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt        DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkChatChannels_CreatedAt DEFAULT (SYSUTCDATETIME()),
        LastMessageAt    DATETIME2(3)     NULL,
        CONSTRAINT CK_WorkChatChannels_Kind CHECK (Kind IN ('Board', 'Group', 'Direct'))
    );

    PRINT 'Created table: WorkChatChannels';
END
ELSE PRINT 'Table already exists: WorkChatChannels';
GO

-- One conversation per board, and one per pair of people. Made on their own, so a run that
-- created the table but stopped before the indexes is completed by running this script again.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_WorkChatChannels_Project' AND object_id = OBJECT_ID('dbo.WorkChatChannels'))
BEGIN
    CREATE UNIQUE INDEX UX_WorkChatChannels_Project ON dbo.WorkChatChannels (ProjectId) WHERE ProjectId IS NOT NULL;
    PRINT 'Created index: UX_WorkChatChannels_Project';
END
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_WorkChatChannels_DirectKey' AND object_id = OBJECT_ID('dbo.WorkChatChannels'))
BEGIN
    CREATE UNIQUE INDEX UX_WorkChatChannels_DirectKey ON dbo.WorkChatChannels (DirectKey) WHERE DirectKey IS NOT NULL;
    PRINT 'Created index: UX_WorkChatChannels_DirectKey';
END
GO

IF OBJECT_ID('dbo.WorkChatMembers', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkChatMembers (
        ChannelId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkChatMembers_Channel REFERENCES dbo.WorkChatChannels(ChannelId),
        UserId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkChatMembers_User REFERENCES dbo.CmsUsers(UserId),
        -- 1 = a real member of a Group or Direct channel. 0 = only a read marker in a Board channel.
        IsMember    BIT              NOT NULL CONSTRAINT DF_WorkChatMembers_IsMember DEFAULT (1),
        LastReadAt  DATETIME2(3)     NULL,
        JoinedAt    DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkChatMembers_JoinedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_WorkChatMembers PRIMARY KEY (ChannelId, UserId)
    );

    CREATE INDEX IX_WorkChatMembers_UserId ON dbo.WorkChatMembers (UserId);

    PRINT 'Created table: WorkChatMembers';
END
ELSE PRINT 'Table already exists: WorkChatMembers';
GO

IF OBJECT_ID('dbo.WorkChatMessages', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkChatMessages (
        MessageId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkChatMessages PRIMARY KEY,
        ChannelId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkChatMessages_Channel REFERENCES dbo.WorkChatChannels(ChannelId),
        AuthorUserId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkChatMessages_Author REFERENCES dbo.CmsUsers(UserId),
        Body          NVARCHAR(4000)   NOT NULL,
        IsImportant   BIT              NOT NULL CONSTRAINT DF_WorkChatMessages_IsImportant DEFAULT (0),
        IsEscalation  BIT              NOT NULL CONSTRAINT DF_WorkChatMessages_IsEscalation DEFAULT (0),
        WorkItemId    UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkChatMessages_Item REFERENCES dbo.WorkItems(WorkItemId),
        IsDeleted     BIT              NOT NULL CONSTRAINT DF_WorkChatMessages_IsDeleted DEFAULT (0),
        CreatedAt     DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkChatMessages_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_WorkChatMessages_Channel ON dbo.WorkChatMessages (ChannelId, CreatedAt DESC);

    PRINT 'Created table: WorkChatMessages';
END
ELSE PRINT 'Table already exists: WorkChatMessages';
GO

IF OBJECT_ID('dbo.WorkChatMentions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkChatMentions (
        MessageId  UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkChatMentions_Message REFERENCES dbo.WorkChatMessages(MessageId),
        UserId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkChatMentions_User REFERENCES dbo.CmsUsers(UserId),
        CONSTRAINT PK_WorkChatMentions PRIMARY KEY (MessageId, UserId)
    );
    PRINT 'Created table: WorkChatMentions';
END
ELSE PRINT 'Table already exists: WorkChatMentions';
GO

IF OBJECT_ID('dbo.WorkNotifications', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkNotifications (
        NotificationId  UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkNotifications PRIMARY KEY,
        UserId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkNotifications_User REFERENCES dbo.CmsUsers(UserId),
        -- Mention | Escalation | Direct
        Kind            NVARCHAR(12)     NOT NULL,
        ChannelId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkNotifications_Channel REFERENCES dbo.WorkChatChannels(ChannelId),
        MessageId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkNotifications_Message REFERENCES dbo.WorkChatMessages(MessageId),
        ActorUserId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkNotifications_Actor REFERENCES dbo.CmsUsers(UserId),
        IsRead          BIT              NOT NULL CONSTRAINT DF_WorkNotifications_IsRead DEFAULT (0),
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkNotifications_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_WorkNotifications_User ON dbo.WorkNotifications (UserId, IsRead, CreatedAt DESC);

    PRINT 'Created table: WorkNotifications';
END
ELSE PRINT 'Table already exists: WorkNotifications';
GO
