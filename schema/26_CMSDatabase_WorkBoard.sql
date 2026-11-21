-- =============================================================================
-- CMSDatabase -- Daily Work Board (work management): tables + permissions
-- =============================================================================
-- Backs the CMS "Daily Work Board" page, tab "Work management": the team's own
-- Jira-style tracker. Work is grouped by project (one per product). Each item
-- has a type and sits in this hierarchy, the parent being optional except for
-- a subtask:
--
--     Epic -> Feature -> Story | Task | Bug -> Subtask
--
-- Tables
--   WorkProjects       one row per product; NextNumber gives each item its
--                      number, shown with the project key (HMS-142).
--   WorkSprints        time boxes (11 days by default). Items point at a sprint;
--                      the sprint screens arrive in the next release.
--   WorkItems          the work itself. Deleting hides the row (IsDeleted).
--   WorkItemComments   discussion on an item.
--   WorkItemHistory    one row per changed field, for the item's history list.
--
-- Permissions
--   work.view     open the board and read everything on it
--   work.edit     create and change items, comment
--   work.manage   add projects, delete items
-- All three are granted to the Administrator role here. Give them to other
-- roles or people from Users & access. People must sign in again to pick up a
-- new permission, because the CMS web app reads permissions at login.
--
-- Idempotent and safe to re-run.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── WorkProjects ─────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.WorkProjects', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkProjects (
        ProjectId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkProjects PRIMARY KEY,
        [Key]           NVARCHAR(10)     NOT NULL,   -- 'HMS', 'RAD' ... upper case, shown in item keys
        Name            NVARCHAR(100)    NOT NULL,
        Description     NVARCHAR(500)    NULL,
        NextNumber      INT              NOT NULL CONSTRAINT DF_WorkProjects_NextNumber DEFAULT (1),
        SprintDays      INT              NOT NULL CONSTRAINT DF_WorkProjects_SprintDays DEFAULT (11),
        IsArchived      BIT              NOT NULL CONSTRAINT DF_WorkProjects_IsArchived DEFAULT (0),
        CreatedByUserId UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkProjects_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkProjects_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_WorkProjects_Key UNIQUE ([Key])
    );
    PRINT 'Created table: WorkProjects';
END
ELSE PRINT 'Table already exists: WorkProjects';
GO

-- ── WorkSprints ──────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.WorkSprints', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkSprints (
        SprintId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkSprints PRIMARY KEY,
        ProjectId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkSprints_Project REFERENCES dbo.WorkProjects(ProjectId),
        Name            NVARCHAR(100)    NOT NULL,
        Goal            NVARCHAR(500)    NULL,
        StartDate       DATE             NULL,
        EndDate         DATE             NULL,
        State           NVARCHAR(20)     NOT NULL CONSTRAINT DF_WorkSprints_State DEFAULT ('Planned'),
        CreatedByUserId UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkSprints_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkSprints_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CompletedAt     DATETIME2(3)     NULL,
        CONSTRAINT CK_WorkSprints_State CHECK (State IN ('Planned', 'Active', 'Completed'))
    );

    CREATE INDEX IX_WorkSprints_ProjectId ON dbo.WorkSprints (ProjectId);

    PRINT 'Created table: WorkSprints';
END
ELSE PRINT 'Table already exists: WorkSprints';
GO

-- ── WorkItems ────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.WorkItems', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkItems (
        WorkItemId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkItems PRIMARY KEY,
        ProjectId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkItems_Project REFERENCES dbo.WorkProjects(ProjectId),
        Number          INT              NOT NULL,   -- per project; key shown as '<ProjectKey>-<Number>'
        ItemType        NVARCHAR(20)     NOT NULL,
        Title           NVARCHAR(300)    NOT NULL,
        Description     NVARCHAR(MAX)    NULL,       -- markdown from the editor
        Status          NVARCHAR(20)     NOT NULL CONSTRAINT DF_WorkItems_Status DEFAULT ('ToDo'),
        Priority        NVARCHAR(20)     NOT NULL CONSTRAINT DF_WorkItems_Priority DEFAULT ('Medium'),
        StoryPoints     DECIMAL(5,1)     NULL,
        AssigneeUserId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkItems_Assignee REFERENCES dbo.CmsUsers(UserId),
        ReporterUserId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkItems_Reporter REFERENCES dbo.CmsUsers(UserId),
        ParentId        UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkItems_Parent REFERENCES dbo.WorkItems(WorkItemId),
        SprintId        UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkItems_Sprint REFERENCES dbo.WorkSprints(SprintId),
        Labels          NVARCHAR(400)    NULL,       -- comma-separated, lower case
        DueDate         DATE             NULL,
        IsBlocked       BIT              NOT NULL CONSTRAINT DF_WorkItems_IsBlocked DEFAULT (0),
        BlockedReason   NVARCHAR(300)    NULL,
        [Rank]          FLOAT            NOT NULL CONSTRAINT DF_WorkItems_Rank DEFAULT (0),  -- order in the backlog
        IsDeleted       BIT              NOT NULL CONSTRAINT DF_WorkItems_IsDeleted DEFAULT (0),
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkItems_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkItems_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CompletedAt     DATETIME2(3)     NULL,
        CONSTRAINT UQ_WorkItems_Project_Number UNIQUE (ProjectId, Number),
        CONSTRAINT CK_WorkItems_ItemType CHECK (ItemType IN ('Epic', 'Feature', 'Story', 'Task', 'Bug', 'Subtask')),
        CONSTRAINT CK_WorkItems_Status   CHECK (Status IN ('ToDo', 'InProgress', 'InReview', 'Done')),
        CONSTRAINT CK_WorkItems_Priority CHECK (Priority IN ('Highest', 'High', 'Medium', 'Low', 'Lowest'))
    );

    CREATE INDEX IX_WorkItems_Project_Deleted ON dbo.WorkItems (ProjectId, IsDeleted) INCLUDE (Status, ItemType, AssigneeUserId, ParentId, SprintId);
    CREATE INDEX IX_WorkItems_ParentId        ON dbo.WorkItems (ParentId);
    CREATE INDEX IX_WorkItems_AssigneeUserId  ON dbo.WorkItems (AssigneeUserId);
    CREATE INDEX IX_WorkItems_SprintId        ON dbo.WorkItems (SprintId);

    PRINT 'Created table: WorkItems';
END
ELSE PRINT 'Table already exists: WorkItems';
GO

-- ── WorkItemComments ─────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.WorkItemComments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkItemComments (
        CommentId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkItemComments PRIMARY KEY,
        WorkItemId    UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkItemComments_Item REFERENCES dbo.WorkItems(WorkItemId),
        AuthorUserId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkItemComments_Author REFERENCES dbo.CmsUsers(UserId),
        Body          NVARCHAR(MAX)    NOT NULL,
        IsDeleted     BIT              NOT NULL CONSTRAINT DF_WorkItemComments_IsDeleted DEFAULT (0),
        CreatedAt     DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkItemComments_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_WorkItemComments_WorkItemId ON dbo.WorkItemComments (WorkItemId);

    PRINT 'Created table: WorkItemComments';
END
ELSE PRINT 'Table already exists: WorkItemComments';
GO

-- ── WorkItemHistory ──────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.WorkItemHistory', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkItemHistory (
        HistoryId    UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_WorkItemHistory PRIMARY KEY,
        WorkItemId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkItemHistory_Item REFERENCES dbo.WorkItems(WorkItemId),
        ActorUserId  UNIQUEIDENTIFIER NULL CONSTRAINT FK_WorkItemHistory_Actor REFERENCES dbo.CmsUsers(UserId),
        Field        NVARCHAR(40)     NOT NULL,   -- 'created', 'status', 'assignee', 'title' ...
        OldValue     NVARCHAR(400)    NULL,
        NewValue     NVARCHAR(400)    NULL,
        CreatedAt    DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkItemHistory_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_WorkItemHistory_WorkItemId ON dbo.WorkItemHistory (WorkItemId, CreatedAt);

    PRINT 'Created table: WorkItemHistory';
END
ELSE PRINT 'Table already exists: WorkItemHistory';
GO

-- ── Starting projects ────────────────────────────────────────────────────────
-- One per product. More can be added from the board by someone with work.manage.
DECLARE @Projects TABLE ([Key] NVARCHAR(10), Name NVARCHAR(100), Description NVARCHAR(500));
INSERT INTO @Projects ([Key], Name, Description) VALUES
    ('HMS', '1HMS',             'Hospital management software and EMR'),
    ('RAD', '1Rad',             'Cloud PACS and radiology reporting'),
    ('DD',  'Doctor Dekho',     'Patient app and doctor listings'),
    ('WEB', 'NexEagle website', 'nexeagle.com'),
    ('CMS', 'CMS',              'This control centre');

INSERT INTO dbo.WorkProjects (ProjectId, [Key], Name, Description)
SELECT NEWID(), p.[Key], p.Name, p.Description
FROM @Projects p
WHERE NOT EXISTS (SELECT 1 FROM dbo.WorkProjects w WHERE w.[Key] = p.[Key]);

PRINT CONCAT('Starting projects added: ', @@ROWCOUNT);
GO

-- ── Permissions ──────────────────────────────────────────────────────────────
DECLARE @Perms TABLE ([Key] NVARCHAR(100), Action NVARCHAR(50), DisplayName NVARCHAR(150), SortOrder INT);
INSERT INTO @Perms ([Key], Action, DisplayName, SortOrder) VALUES
    ('work.view',   'view',   'View the Daily Work Board',            130),
    ('work.edit',   'edit',   'Create and change work items',         131),
    ('work.manage', 'manage', 'Manage work projects and delete items', 132);

INSERT INTO dbo.CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
SELECT NEWID(), p.[Key], 'work', p.Action, p.DisplayName, 'Daily Work Board', p.SortOrder
FROM @Perms p
WHERE NOT EXISTS (SELECT 1 FROM dbo.CmsPermissions c WHERE c.[Key] = p.[Key]);

PRINT CONCAT('Permissions added: ', @@ROWCOUNT);

-- Grant all three to Administrator.
INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
SELECT 'B0000001-0000-0000-0000-000000000001', c.PermissionId
FROM dbo.CmsPermissions c
WHERE c.[Key] IN ('work.view', 'work.edit', 'work.manage')
  AND NOT EXISTS (
      SELECT 1 FROM dbo.CmsRolePermissions rp
      WHERE rp.RoleId = 'B0000001-0000-0000-0000-000000000001' AND rp.PermissionId = c.PermissionId
  );

PRINT CONCAT('Administrator grants added: ', @@ROWCOUNT);
GO
