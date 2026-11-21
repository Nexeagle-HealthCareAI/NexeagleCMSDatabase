-- =============================================================================
-- CMSDatabase -- Daily Work Board: activity log, sign-ins and "last seen"
-- =============================================================================
-- Run after 28_CMSDatabase_WorkBoardAccess.sql.
--
-- The activity log screen is a reading of what is already recorded
-- (WorkItemHistory, WorkItemComments, WorkProjectAccessLog, DocAccessLog) plus
-- the two tables added here:
--
--   WorkPresence     one row per person: when they were last on the board
--                    ("last seen") and when and from where they last opened it.
--   WorkSessionLog   one row each time someone opens the board, and each time
--                    the protected screen stops a copy, a print, a save or sees
--                    the screenshot key. Kind is one of:
--                    Opened | CopyBlocked | PrintBlocked | SaveBlocked | ScreenshotKey
--                    The address and browser are kept for compliance review.
--
-- Permission
--   work.audit   read the activity log of the Daily Work Board. Granted to the
--                Administrator role here, and to nobody else.
-- Safe to run more than once.
-- =============================================================================

USE CMSDatabase;
GO

IF OBJECT_ID('dbo.WorkPresence', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkPresence (
        UserId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkPresence PRIMARY KEY
                                       CONSTRAINT FK_WorkPresence_User REFERENCES dbo.CmsUsers(UserId),
        LastSeenAt    DATETIME2(3)     NOT NULL,
        LastOpenedAt  DATETIME2(3)     NULL,
        -- The visit before the current one, shown to the person as "your previous visit".
        PreviousOpenedAt DATETIME2(3)  NULL,
        PreviousIp    NVARCHAR(64)     NULL,
        LastIp        NVARCHAR(64)     NULL,
        LastUserAgent NVARCHAR(300)    NULL
    );
    PRINT 'Created table: WorkPresence';
END
ELSE PRINT 'Table already exists: WorkPresence';
GO

IF OBJECT_ID('dbo.WorkSessionLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkSessionLog (
        LogId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkSessionLog PRIMARY KEY,
        UserId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkSessionLog_User REFERENCES dbo.CmsUsers(UserId),
        Kind       NVARCHAR(20)     NOT NULL,
        Ip         NVARCHAR(64)     NULL,
        UserAgent  NVARCHAR(300)    NULL,
        CreatedAt  DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkSessionLog_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_WorkSessionLog_CreatedAt ON dbo.WorkSessionLog (CreatedAt DESC);
    CREATE INDEX IX_WorkSessionLog_User ON dbo.WorkSessionLog (UserId, CreatedAt DESC);

    PRINT 'Created table: WorkSessionLog';
END
ELSE PRINT 'Table already exists: WorkSessionLog';
GO

-- The activity log reads these newest-first.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WorkItemHistory_CreatedAt' AND object_id = OBJECT_ID('dbo.WorkItemHistory'))
    CREATE INDEX IX_WorkItemHistory_CreatedAt ON dbo.WorkItemHistory (CreatedAt DESC);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WorkItemComments_CreatedAt' AND object_id = OBJECT_ID('dbo.WorkItemComments'))
    CREATE INDEX IX_WorkItemComments_CreatedAt ON dbo.WorkItemComments (CreatedAt DESC);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.CmsPermissions WHERE [Key] = 'work.audit')
BEGIN
    INSERT INTO dbo.CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (NEWID(), 'work.audit', 'work', 'audit', 'View the Daily Work Board activity log', 'Daily Work Board', 136);
    PRINT 'Permission added: work.audit';
END

INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
SELECT 'B0000001-0000-0000-0000-000000000001', c.PermissionId
FROM dbo.CmsPermissions c
WHERE c.[Key] = 'work.audit'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.CmsRolePermissions rp
      WHERE rp.RoleId = 'B0000001-0000-0000-0000-000000000001' AND rp.PermissionId = c.PermissionId
  );
GO
