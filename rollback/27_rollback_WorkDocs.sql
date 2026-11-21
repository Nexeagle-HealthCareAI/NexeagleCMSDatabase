-- =============================================================================
-- Rollback for 27_CMSDatabase_WorkDocs.sql
-- =============================================================================
-- Removes the Docs tables and its four permissions. Every folder, page, version
-- and link is deleted; uploaded files stay in object storage and must be
-- removed there by hand. Take a backup first.
-- =============================================================================

USE CMSDatabase;
GO

DELETE rp FROM dbo.CmsRolePermissions rp
JOIN dbo.CmsPermissions p ON p.PermissionId = rp.PermissionId
WHERE p.[Key] IN ('docs.view', 'docs.edit', 'docs.delete', 'docs.sensitive');

DELETE up FROM dbo.CmsUserPermissions up
JOIN dbo.CmsPermissions p ON p.PermissionId = up.PermissionId
WHERE p.[Key] IN ('docs.view', 'docs.edit', 'docs.delete', 'docs.sensitive');

DELETE FROM dbo.CmsPermissions WHERE [Key] IN ('docs.view', 'docs.edit', 'docs.delete', 'docs.sensitive');
GO

IF OBJECT_ID('dbo.WorkItemDocuments', 'U') IS NOT NULL DROP TABLE dbo.WorkItemDocuments;
IF OBJECT_ID('dbo.DocAccessLog', 'U')      IS NOT NULL DROP TABLE dbo.DocAccessLog;
IF OBJECT_ID('dbo.DocVersions', 'U')       IS NOT NULL DROP TABLE dbo.DocVersions;
IF OBJECT_ID('dbo.Documents', 'U')         IS NOT NULL DROP TABLE dbo.Documents;
IF OBJECT_ID('dbo.DocFolderAccess', 'U')   IS NOT NULL DROP TABLE dbo.DocFolderAccess;
IF OBJECT_ID('dbo.DocFolders', 'U')        IS NOT NULL DROP TABLE dbo.DocFolders;
GO

PRINT 'Docs removed.';
GO
