-- =============================================================================
-- Rollback for 32_CMSDatabase_Insights_Contacts.sql
-- =============================================================================
-- Removes insights.contacts. WhatsApp bot numbers are then masked for everyone.
-- =============================================================================

USE CMSDatabase;
GO

DELETE rp FROM dbo.CmsRolePermissions rp
JOIN dbo.CmsPermissions p ON p.PermissionId = rp.PermissionId WHERE p.[Key] = 'insights.contacts';
DELETE up FROM dbo.CmsUserPermissions up
JOIN dbo.CmsPermissions p ON p.PermissionId = up.PermissionId WHERE p.[Key] = 'insights.contacts';
DELETE FROM dbo.CmsPermissions WHERE [Key] = 'insights.contacts';
GO
