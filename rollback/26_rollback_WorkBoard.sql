-- =============================================================================
-- Rollback for 26_CMSDatabase_WorkBoard.sql
-- =============================================================================
-- Removes the Daily Work Board tables and its four permissions.
-- ALL work items, comments and history are deleted. Take a backup first.
-- =============================================================================

USE CMSDatabase;
GO

DELETE rp
FROM dbo.CmsRolePermissions rp
JOIN dbo.CmsPermissions p ON p.PermissionId = rp.PermissionId
WHERE p.[Key] IN ('work.view', 'work.edit', 'work.manage', 'work.delete');

DELETE up
FROM dbo.CmsUserPermissions up
JOIN dbo.CmsPermissions p ON p.PermissionId = up.PermissionId
WHERE p.[Key] IN ('work.view', 'work.edit', 'work.manage', 'work.delete');

DELETE FROM dbo.CmsPermissions WHERE [Key] IN ('work.view', 'work.edit', 'work.manage', 'work.delete');
GO

IF OBJECT_ID('dbo.WorkItemHistory', 'U')  IS NOT NULL DROP TABLE dbo.WorkItemHistory;
IF OBJECT_ID('dbo.WorkItemComments', 'U') IS NOT NULL DROP TABLE dbo.WorkItemComments;
IF OBJECT_ID('dbo.WorkItems', 'U')        IS NOT NULL DROP TABLE dbo.WorkItems;
IF OBJECT_ID('dbo.WorkSprints', 'U')      IS NOT NULL DROP TABLE dbo.WorkSprints;
IF OBJECT_ID('dbo.WorkStatuses', 'U')     IS NOT NULL DROP TABLE dbo.WorkStatuses;
IF OBJECT_ID('dbo.WorkProjects', 'U')     IS NOT NULL DROP TABLE dbo.WorkProjects;
GO

PRINT 'Daily Work Board removed.';
GO
