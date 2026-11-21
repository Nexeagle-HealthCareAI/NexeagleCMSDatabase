-- =============================================================================
-- Rollback for 29_CMSDatabase_WorkActivity.sql
-- =============================================================================
-- Removes "last seen", the sign-in and protected-screen log, and work.audit.
-- Item history, comments and access changes are untouched.
-- =============================================================================

USE CMSDatabase;
GO

DELETE rp FROM dbo.CmsRolePermissions rp
JOIN dbo.CmsPermissions p ON p.PermissionId = rp.PermissionId WHERE p.[Key] = 'work.audit';
DELETE up FROM dbo.CmsUserPermissions up
JOIN dbo.CmsPermissions p ON p.PermissionId = up.PermissionId WHERE p.[Key] = 'work.audit';
DELETE FROM dbo.CmsPermissions WHERE [Key] = 'work.audit';
GO

IF OBJECT_ID('dbo.WorkSessionLog', 'U') IS NOT NULL DROP TABLE dbo.WorkSessionLog;
IF OBJECT_ID('dbo.WorkPresence', 'U')   IS NOT NULL DROP TABLE dbo.WorkPresence;
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WorkItemHistory_CreatedAt' AND object_id = OBJECT_ID('dbo.WorkItemHistory'))
    DROP INDEX IX_WorkItemHistory_CreatedAt ON dbo.WorkItemHistory;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WorkItemComments_CreatedAt' AND object_id = OBJECT_ID('dbo.WorkItemComments'))
    DROP INDEX IX_WorkItemComments_CreatedAt ON dbo.WorkItemComments;
GO
