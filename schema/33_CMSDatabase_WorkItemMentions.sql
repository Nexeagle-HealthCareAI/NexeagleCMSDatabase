-- =============================================================================
-- CMSDatabase -- Daily Work Board: tagging people in work items
-- =============================================================================
-- Run after 26_CMSDatabase_WorkBoard.sql (any time after; it does not depend on
-- scripts 27 to 32).
--
--   WorkItemMentions       who is tagged where in a work item, right now. Place
--                          is one of:
--                            comment      in a comment (CommentId says which)
--                            description  in the description
--                            blocked      in what is blocking the item
--                          A change to the text replaces its rows; a removed
--                          comment keeps them, hidden with the comment.
--   WorkItemNotifications  what each person should be told: someone tagged
--                          them (Kind = Mention) in that place. Excerpt is the
--                          words around the tag when it was written.
--
-- No new permission: anyone who can edit items (work.edit) can tag people who
-- can open the board (everyone active on an open board, its members on a
-- members-only one).
-- Safe to run more than once.
-- =============================================================================

USE CMSDatabase;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.WorkItemMentions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkItemMentions (
        MentionId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkItemMentions PRIMARY KEY,
        WorkItemId  UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkItemMentions_Item REFERENCES dbo.WorkItems(WorkItemId),
        Place       NVARCHAR(12)     NOT NULL,
        CommentId   UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkItemMentions_Comment REFERENCES dbo.WorkItemComments(CommentId),
        UserId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkItemMentions_User REFERENCES dbo.CmsUsers(UserId),
        CreatedAt   DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkItemMentions_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_WorkItemMentions_Item ON dbo.WorkItemMentions (WorkItemId, Place);

    PRINT 'Created table: WorkItemMentions';
END
ELSE PRINT 'Table already exists: WorkItemMentions';
GO

IF OBJECT_ID('dbo.WorkItemNotifications', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkItemNotifications (
        NotificationId  UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkItemNotifications PRIMARY KEY,
        UserId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkItemNotifications_User REFERENCES dbo.CmsUsers(UserId),
        Kind            NVARCHAR(12)     NOT NULL,
        WorkItemId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkItemNotifications_Item REFERENCES dbo.WorkItems(WorkItemId),
        Place           NVARCHAR(12)     NOT NULL,
        CommentId       UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkItemNotifications_Comment REFERENCES dbo.WorkItemComments(CommentId),
        ActorUserId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkItemNotifications_Actor REFERENCES dbo.CmsUsers(UserId),
        Excerpt         NVARCHAR(300)    NULL,
        IsRead          BIT              NOT NULL CONSTRAINT DF_WorkItemNotifications_IsRead DEFAULT (0),
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkItemNotifications_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_WorkItemNotifications_User ON dbo.WorkItemNotifications (UserId, IsRead, CreatedAt DESC);

    PRINT 'Created table: WorkItemNotifications';
END
ELSE PRINT 'Table already exists: WorkItemNotifications';
GO
