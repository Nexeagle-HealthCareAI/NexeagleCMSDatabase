-- =============================================================================
-- CMSDatabase -- Daily Work Board, tab "Docs": tables + permissions
-- =============================================================================
-- The team's document space: folders, pages written in the CMS editor, and
-- uploaded files (Word, PDF, Excel, images ...). Needs script 26 (WorkItems).
--
-- Tables
--   DocFolders          nested folders. IsRestricted locks a folder, and
--                       everything under it, to the people in DocFolderAccess.
--   DocFolderAccess     who may open a restricted folder.
--   Documents           one row per page or file. A page keeps its text here
--                       (Content = editor JSON, ContentText = plain text for
--                       search). A file keeps only its details here; the bytes
--                       are in object storage under StorageKey, never in SQL.
--   DocVersions         earlier versions: a page's previous text, or a file
--                       that was replaced by a new upload of the same name.
--   DocAccessLog        who opened, downloaded, changed, moved or binned what.
--   WorkItemDocuments   documents tagged on a work item.
--
-- Deleting moves a folder or document to the bin (IsDeleted = 1); it can be
-- restored. Nothing here removes rows or stored files.
--
-- Permissions
--   docs.view        open the Docs tab and every document that is not locked away
--   docs.edit        create folders and pages, upload, rename, move, tag, link
--   docs.delete      move to the bin and restore from it. Apart on purpose,
--                    like work.delete: few people should hold it.
--   docs.sensitive   see every restricted folder, choose who may open one, and
--                    read the access log
-- All four are granted to the Administrator role here, and to nobody else.
--
-- Idempotent and safe to re-run.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── DocFolders ───────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.DocFolders', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocFolders (
        FolderId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_DocFolders PRIMARY KEY,
        ParentId        UNIQUEIDENTIFIER NULL CONSTRAINT FK_DocFolders_Parent REFERENCES dbo.DocFolders(FolderId),
        Name            NVARCHAR(150)    NOT NULL,
        Color           NVARCHAR(20)     NULL,       -- a name from the web app's palette, e.g. 'blue'
        IsRestricted    BIT              NOT NULL CONSTRAINT DF_DocFolders_IsRestricted DEFAULT (0),
        CreatedByUserId UNIQUEIDENTIFIER NULL CONSTRAINT FK_DocFolders_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_DocFolders_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_DocFolders_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        IsDeleted       BIT              NOT NULL CONSTRAINT DF_DocFolders_IsDeleted DEFAULT (0),
        DeletedAt       DATETIME2(3)     NULL,
        DeletedByUserId UNIQUEIDENTIFIER NULL CONSTRAINT FK_DocFolders_DeletedBy REFERENCES dbo.CmsUsers(UserId)
    );

    CREATE INDEX IX_DocFolders_ParentId ON dbo.DocFolders (ParentId);

    PRINT 'Created table: DocFolders';
END
ELSE PRINT 'Table already exists: DocFolders';
GO

-- ── DocFolderAccess ──────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.DocFolderAccess', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocFolderAccess (
        FolderId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_DocFolderAccess_Folder REFERENCES dbo.DocFolders(FolderId),
        UserId          UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_DocFolderAccess_User REFERENCES dbo.CmsUsers(UserId),
        AddedByUserId   UNIQUEIDENTIFIER NULL,
        AddedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_DocFolderAccess_AddedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DocFolderAccess PRIMARY KEY (FolderId, UserId)
    );
    PRINT 'Created table: DocFolderAccess';
END
ELSE PRINT 'Table already exists: DocFolderAccess';
GO

-- ── Documents ────────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.Documents', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Documents (
        DocumentId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Documents PRIMARY KEY,
        FolderId        UNIQUEIDENTIFIER NULL CONSTRAINT FK_Documents_Folder REFERENCES dbo.DocFolders(FolderId),  -- NULL = top level
        Kind            NVARCHAR(10)     NOT NULL,   -- 'Page' | 'File'
        Name            NVARCHAR(255)    NOT NULL,   -- page title, or the file name
        Content         NVARCHAR(MAX)    NULL,       -- page: editor JSON
        ContentText     NVARCHAR(MAX)    NULL,       -- page: plain text, for search
        ContentType     NVARCHAR(150)    NULL,       -- file: MIME type
        SizeBytes       BIGINT           NOT NULL CONSTRAINT DF_Documents_SizeBytes DEFAULT (0),
        StorageKey      NVARCHAR(400)    NULL,       -- file: object key in storage
        VersionNumber   INT              NOT NULL CONSTRAINT DF_Documents_VersionNumber DEFAULT (1),
        Tags            NVARCHAR(400)    NULL,       -- comma-separated, lower case
        CreatedByUserId UNIQUEIDENTIFIER NULL CONSTRAINT FK_Documents_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_Documents_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedByUserId UNIQUEIDENTIFIER NULL CONSTRAINT FK_Documents_UpdatedBy REFERENCES dbo.CmsUsers(UserId),
        UpdatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_Documents_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        IsDeleted       BIT              NOT NULL CONSTRAINT DF_Documents_IsDeleted DEFAULT (0),
        DeletedAt       DATETIME2(3)     NULL,
        DeletedByUserId UNIQUEIDENTIFIER NULL CONSTRAINT FK_Documents_DeletedBy REFERENCES dbo.CmsUsers(UserId),
        CONSTRAINT CK_Documents_Kind CHECK (Kind IN ('Page', 'File'))
    );

    CREATE INDEX IX_Documents_FolderId ON dbo.Documents (FolderId, IsDeleted);

    PRINT 'Created table: Documents';
END
ELSE PRINT 'Table already exists: Documents';
GO

-- ── DocVersions ──────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.DocVersions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocVersions (
        VersionId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_DocVersions PRIMARY KEY,
        DocumentId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_DocVersions_Document REFERENCES dbo.Documents(DocumentId),
        VersionNumber   INT              NOT NULL,
        Name            NVARCHAR(255)    NOT NULL,
        Content         NVARCHAR(MAX)    NULL,       -- page: the text as it was
        ContentType     NVARCHAR(150)    NULL,
        SizeBytes       BIGINT           NOT NULL CONSTRAINT DF_DocVersions_SizeBytes DEFAULT (0),
        StorageKey      NVARCHAR(400)    NULL,       -- file: the object that was replaced
        CreatedByUserId UNIQUEIDENTIFIER NULL CONSTRAINT FK_DocVersions_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_DocVersions_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_DocVersions_DocumentId ON dbo.DocVersions (DocumentId, VersionNumber);

    PRINT 'Created table: DocVersions';
END
ELSE PRINT 'Table already exists: DocVersions';
GO

-- ── DocAccessLog ─────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.DocAccessLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DocAccessLog (
        LogId        UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_DocAccessLog PRIMARY KEY,
        DocumentId   UNIQUEIDENTIFIER NULL,   -- no FK: the log outlives what it describes
        FolderId     UNIQUEIDENTIFIER NULL,
        UserId       UNIQUEIDENTIFIER NULL,
        Action       NVARCHAR(30)     NOT NULL,   -- 'open', 'download', 'create', 'upload', 'edit', 'rename', 'move', 'bin', 'restore', 'access'
        Detail       NVARCHAR(300)    NULL,
        CreatedAt    DATETIME2(3)     NOT NULL CONSTRAINT DF_DocAccessLog_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_DocAccessLog_DocumentId ON dbo.DocAccessLog (DocumentId, CreatedAt);
    CREATE INDEX IX_DocAccessLog_FolderId   ON dbo.DocAccessLog (FolderId, CreatedAt);

    PRINT 'Created table: DocAccessLog';
END
ELSE PRINT 'Table already exists: DocAccessLog';
GO

-- ── WorkItemDocuments ────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.WorkItemDocuments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.WorkItemDocuments (
        WorkItemId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkItemDocuments_Item REFERENCES dbo.WorkItems(WorkItemId),
        DocumentId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_WorkItemDocuments_Document REFERENCES dbo.Documents(DocumentId),
        AddedByUserId   UNIQUEIDENTIFIER NULL,
        AddedAt         DATETIME2(3)     NOT NULL CONSTRAINT DF_WorkItemDocuments_AddedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_WorkItemDocuments PRIMARY KEY (WorkItemId, DocumentId)
    );

    CREATE INDEX IX_WorkItemDocuments_DocumentId ON dbo.WorkItemDocuments (DocumentId);

    PRINT 'Created table: WorkItemDocuments';
END
ELSE PRINT 'Table already exists: WorkItemDocuments';
GO

-- ── Permissions ──────────────────────────────────────────────────────────────
DECLARE @Perms TABLE ([Key] NVARCHAR(100), Action NVARCHAR(50), DisplayName NVARCHAR(150), SortOrder INT);
INSERT INTO @Perms ([Key], Action, DisplayName, SortOrder) VALUES
    ('docs.view',      'view',      'View documents',                                  140),
    ('docs.edit',      'edit',      'Create, upload and change documents',             141),
    ('docs.delete',    'delete',    'Move documents to the bin and restore them',      142),
    ('docs.sensitive', 'sensitive', 'Open every restricted folder and manage access',  143);

INSERT INTO dbo.CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
SELECT NEWID(), p.[Key], 'work', p.Action, p.DisplayName, 'Daily Work Board', p.SortOrder
FROM @Perms p
WHERE NOT EXISTS (SELECT 1 FROM dbo.CmsPermissions c WHERE c.[Key] = p.[Key]);

PRINT CONCAT('Permissions added: ', @@ROWCOUNT);

INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
SELECT 'B0000001-0000-0000-0000-000000000001', c.PermissionId
FROM dbo.CmsPermissions c
WHERE c.[Key] IN ('docs.view', 'docs.edit', 'docs.delete', 'docs.sensitive')
  AND NOT EXISTS (
      SELECT 1 FROM dbo.CmsRolePermissions rp
      WHERE rp.RoleId = 'B0000001-0000-0000-0000-000000000001' AND rp.PermissionId = c.PermissionId
  );

PRINT CONCAT('Administrator grants added: ', @@ROWCOUNT);
GO
