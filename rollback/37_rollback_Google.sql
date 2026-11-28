-- =============================================================================
-- Rollback of 37_CMSDatabase_Google.sql
-- Removes the Google tables (the Google sign-in, tag IDs, lead links and the record of
-- results sent to Google are lost; CRM leads made from them stay) and the google.* permissions.
-- =============================================================================

USE CMSDatabase;
GO

DELETE rp FROM dbo.CmsRolePermissions rp JOIN dbo.CmsPermissions p ON p.PermissionId = rp.PermissionId WHERE p.[Key] LIKE 'google.%';
DELETE up FROM dbo.CmsUserPermissions up JOIN dbo.CmsPermissions p ON p.PermissionId = up.PermissionId WHERE p.[Key] LIKE 'google.%';
DELETE FROM dbo.CmsPermissions WHERE [Key] LIKE 'google.%';
GO

IF OBJECT_ID('dbo.GoogleConversionUploads', 'U') IS NOT NULL DROP TABLE dbo.GoogleConversionUploads;
IF OBJECT_ID('dbo.GoogleLeads', 'U') IS NOT NULL DROP TABLE dbo.GoogleLeads;
IF OBJECT_ID('dbo.GoogleAccounts', 'U') IS NOT NULL DROP TABLE dbo.GoogleAccounts;
PRINT 'Google tables removed.';
GO
