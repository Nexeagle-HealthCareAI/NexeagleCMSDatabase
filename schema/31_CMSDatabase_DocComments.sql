-- =============================================================================
-- CMSDatabase -- Daily Work Board: comments on documents
-- =============================================================================
-- Run after 27_CMSDatabase_WorkDocs.sql (any time after; it does not depend on
-- scripts 28 to 30).
--
--   DocComments         a comment on a document (page or file). ParentId NULL is
--                       the start of a thread; a reply points at that first
--                       comment. Quote holds the text the comment is about, when
--                       the person selected some. A thread is resolved on its
--                       first comment. Removing hides the row.
--   DocCommentMentions  who was tagged in a comment.
--   DocNotifications    what each person should be told. Kind is one of:
--                         Mention  someone tagged you
--                         Reply    someone answered in a thread you started
--                         Comment  someone commented on a document you created
--
-- No new permission: everyone who can open a document (docs.view, and let into
-- its folder) can read and write comments on it. People change and remove their
-- own; removing someone else's needs docs.delete.
-- Safe to run more than once.
-- =============================================================================

USE CMSDatabase;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.DocComments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocComments (
        CommentId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_DocComments PRIMARY KEY,
        DocumentId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_DocComments_Document REFERENCES dbo.Documents(DocumentId),
        ParentId          UNIQUEIDENTIFIER NULL CONSTRAINT FK_DocComments_Parent REFERENCES dbo.DocComments(CommentId),
        AuthorUserId      UNIQUEIDENTIFIER NULL CONSTRAINT FK_DocComments_Author REFERENCES dbo.CmsUsers(UserId),
        Body              NVARCHAR(4000)   NOT NULL,
        Quote             NVARCHAR(500)    NULL,
        IsResolved        BIT              NOT NULL CONSTRAINT DF_DocComments_IsResolved DEFAULT (0),
        ResolvedByUserId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_DocComments_ResolvedBy REFERENCES dbo.CmsUsers(UserId),
        ResolvedAt        DATETIME2(3)     NULL,
        EditedAt          DATETIME2(3)     NULL,
        IsDeleted         BIT              NOT NULL CONSTRAINT DF_DocComments_IsDeleted DEFAULT (0),
        CreatedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_DocComments_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_DocComments_Document ON dbo.DocComments (DocumentId, CreatedAt);

    PRINT 'Created table: DocComments';
END
ELSE PRINT 'Table already exists: DocComments';
GO

IF OBJECT_ID('dbo.DocCommentMentions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocCommentMentions (
        CommentId  UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_DocCommentMentions_Comment REFERENCES dbo.DocComments(CommentId),
        UserId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_DocCommentMentions_User REFERENCES dbo.CmsUsers(UserId),
        CONSTRAINT PK_DocCommentMentions PRIMARY KEY (CommentId, UserId)
    );
    PRINT 'Created table: DocCommentMentions';
END
ELSE PRINT 'Table already exists: DocCommentMentions';
GO

IF OBJECT_ID('dbo.DocNotifications', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocNotifications (
        NotificationId  UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_DocNotifications PRIMARY KEY,
        UserId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_DocNotifications_User REFERENCES dbo.CmsUsers(UserId),
        Kind            NVARCHAR(12)     NOT NULL,
        DocumentId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_DocNotifications_Document REFERENCES dbo.Documents(DocumentId),
        CommentId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_DocNotifications_Comment REFERENCES dbo.DocComments(CommentId),
        ActorUserId     UNIQUEIDENTIFIER NULL CONSTRAINT FK_DocNotifications_Actor REFERENCES dbo.CmsUsers(UserId),
        IsRead          BIT              NOT NULL CONSTRAINT DF_DocNotifications_IsRead DEFAULT (0),
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_DocNotifications_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_DocNotifications_User ON dbo.DocNotifications (UserId, IsRead, CreatedAt DESC);

    PRINT 'Created table: DocNotifications';
END
ELSE PRINT 'Table already exists: DocNotifications';
GO
