-- Reverses schema/25_CMSDatabase_Emergency_Permission.sql: removes emergency.manage from every role, then the permission.
USE CMSDatabase;
GO
DELETE rp FROM dbo.CmsRolePermissions rp
JOIN dbo.CmsPermissions p ON p.PermissionId = rp.PermissionId
WHERE p.[Key] = 'emergency.manage';
DELETE FROM dbo.CmsPermissions WHERE [Key] = 'emergency.manage';
GO
