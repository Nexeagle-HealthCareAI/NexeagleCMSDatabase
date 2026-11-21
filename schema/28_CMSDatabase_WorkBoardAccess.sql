-- =============================================================================
-- CMSDatabase -- Daily Work Board: board members and the protected screen
-- =============================================================================
-- Run after 26_CMSDatabase_WorkBoard.sql. Run this BEFORE deploying the API
-- build that reads WorkProjects.IsRestricted.
--
-- Board members
--   WorkProjects.IsRestricted   0 = everyone with work.view can open the board
--                               (as before). 1 = only the people listed in
--                               WorkProjectMembers, plus holders of work.members.
--   WorkProjectMembers          who may open a members-only board.
--   WorkProjectAccessLog        who added or removed whom, and who switched a
--                               board to members-only or back. Never edited.
--
-- Permissions
--   work.members   choose who can open each board; opens every board. Granted
--                  to the Administrator role here.
--   work.export    copy text out of, print, and download from the Daily Work
--                  Board. Granted to NOBODY here: without it the screen runs in
--                  protected mode. Give it only to people who must take content
--                  out. People sign in again to pick up a new permission.
-- Safe to run more than once.
-- =============================================================================

USE CMSDatabase;
GO

IF COL_LENGTH('dbo.WorkProjects', 'IsRestricted') IS NULL
BEGIN
    ALTER TABLE dbo.WorkProjects
        ADD IsRestricted BIT NOT NULL CONSTRAINT DF_WorkProjects_IsRestricted DEFAULT (0);
    PRINT 'Added column: WorkProjects.IsRestricted';
END
ELSE PRINT 'Column already exists: WorkProjects.IsRestricted';
GO

IF OBJECT_ID('dbo.WorkProjectMembers', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkProjectMembers (
        ProjectId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkProjectMembers_Project REFERENCES dbo.WorkProjects(ProjectId),
        UserId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkProjectMembers_User REFERENCES dbo.CmsUsers(UserId),
        AddedByUserId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkProjectMembers_AddedBy REFERENCES dbo.CmsUsers(UserId),
        AddedAt        DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkProjectMembers_AddedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_WorkProjectMembers PRIMARY KEY (ProjectId, UserId)
    );

    CREATE INDEX IX_WorkProjectMembers_UserId ON dbo.WorkProjectMembers (UserId);

    PRINT 'Created table: WorkProjectMembers';
END
ELSE PRINT 'Table already exists: WorkProjectMembers';
GO

IF OBJECT_ID('dbo.WorkProjectAccessLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkProjectAccessLog (
        LogId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkProjectAccessLog PRIMARY KEY,
        ProjectId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkProjectAccessLog_Project REFERENCES dbo.WorkProjects(ProjectId),
        -- MemberAdded | MemberRemoved | Restricted | Opened
        Action        NVARCHAR(20)     NOT NULL,
        -- The person added or removed; NULL for Restricted and Opened.
        TargetUserId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkProjectAccessLog_Target REFERENCES dbo.CmsUsers(UserId),
        ActorUserId   UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkProjectAccessLog_Actor REFERENCES dbo.CmsUsers(UserId),
        CreatedAt     DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkProjectAccessLog_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_WorkProjectAccessLog_Project ON dbo.WorkProjectAccessLog (ProjectId, CreatedAt DESC);

    PRINT 'Created table: WorkProjectAccessLog';
END
ELSE PRINT 'Table already exists: WorkProjectAccessLog';
GO

-- ── Permissions ──────────────────────────────────────────────────────────────
DECLARE @Perms TABLE ([Key] NVARCHAR(100), Action NVARCHAR(50), DisplayName NVARCHAR(150), SortOrder INT);
INSERT INTO @Perms ([Key], Action, DisplayName, SortOrder) VALUES
    ('work.members', 'members', 'Choose who can open each work board',               134),
    ('work.export',  'export',  'Copy, print and download from the Daily Work Board', 135);

INSERT INTO dbo.CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
SELECT NEWID(), p.[Key], 'work', p.Action, p.DisplayName, 'Daily Work Board', p.SortOrder
FROM @Perms p
WHERE NOT EXISTS (SELECT 1 FROM dbo.CmsPermissions c WHERE c.[Key] = p.[Key]);

PRINT CONCAT('Permissions added: ', @@ROWCOUNT);

-- work.members goes to Administrator. work.export is deliberately left ungranted.
INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
SELECT 'B0000001-0000-0000-0000-000000000001', c.PermissionId
FROM dbo.CmsPermissions c
WHERE c.[Key] = 'work.members'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.CmsRolePermissions rp
      WHERE rp.RoleId = 'B0000001-0000-0000-0000-000000000001' AND rp.PermissionId = c.PermissionId
  );

PRINT CONCAT('Administrator grants added: ', @@ROWCOUNT);
GO
