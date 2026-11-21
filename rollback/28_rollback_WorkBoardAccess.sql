-- =============================================================================
-- Rollback for 28_CMSDatabase_WorkBoardAccess.sql
-- =============================================================================
-- Removes board members, their log, the members-only switch and the two
-- permissions. Every board becomes open to everyone with work.view again.
-- Roll back the API build that reads WorkProjects.IsRestricted first.
-- =============================================================================

USE CMSDatabase;
GO

DELETE rp FROM dbo.CmsRolePermissions rp
JOIN dbo.CmsPermissions p ON p.PermissionId = rp.PermissionId
WHERE p.[Key] IN ('work.members', 'work.export');

DELETE up FROM dbo.CmsUserPermissions up
JOIN dbo.CmsPermissions p ON p.PermissionId = up.PermissionId
WHERE p.[Key] IN ('work.members', 'work.export');

DELETE FROM dbo.CmsPermissions WHERE [Key] IN ('work.members', 'work.export');
GO

IF OBJECT_ID('dbo.WorkProjectAccessLog', 'U') IS NOT NULL DROP TABLE dbo.WorkProjectAccessLog;
IF OBJECT_ID('dbo.WorkProjectMembers', 'U')   IS NOT NULL DROP TABLE dbo.WorkProjectMembers;
GO

IF COL_LENGTH('dbo.WorkProjects', 'IsRestricted') IS NOT NULL
BEGIN
    ALTER TABLE dbo.WorkProjects DROP CONSTRAINT DF_WorkProjects_IsRestricted;
    ALTER TABLE dbo.WorkProjects DROP COLUMN IsRestricted;
END
GO
