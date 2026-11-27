-- =============================================================================
-- Rollback of 35_CMSDatabase_WhatsApp_Marketing.sql
-- Removes the WhatsApp marketing tables (all chats, contacts, templates and
-- broadcasts in them are lost), its permissions and the Marketing team role.
-- =============================================================================

USE CMSDatabase;
GO

DELETE rp FROM dbo.CmsRolePermissions rp JOIN dbo.CmsPermissions p ON p.PermissionId = rp.PermissionId WHERE p.[Key] LIKE 'whatsapp.%';
DELETE up FROM dbo.CmsUserPermissions up JOIN dbo.CmsPermissions p ON p.PermissionId = up.PermissionId WHERE p.[Key] LIKE 'whatsapp.%';
DELETE FROM dbo.CmsPermissions WHERE [Key] LIKE 'whatsapp.%';
DELETE FROM dbo.CmsUserRoles WHERE RoleId = 'B0000001-0000-0000-0000-000000000007';
DELETE FROM dbo.CmsRolePermissions WHERE RoleId = 'B0000001-0000-0000-0000-000000000007';
DELETE FROM dbo.CmsRoles WHERE RoleId = 'B0000001-0000-0000-0000-000000000007';
GO

IF OBJECT_ID('dbo.WaBroadcastRecipients', 'U') IS NOT NULL DROP TABLE dbo.WaBroadcastRecipients;
IF OBJECT_ID('dbo.WaNotes', 'U') IS NOT NULL DROP TABLE dbo.WaNotes;
IF OBJECT_ID('dbo.WaMessages', 'U') IS NOT NULL DROP TABLE dbo.WaMessages;
IF OBJECT_ID('dbo.WaBroadcasts', 'U') IS NOT NULL DROP TABLE dbo.WaBroadcasts;
IF OBJECT_ID('dbo.WaTemplates', 'U') IS NOT NULL DROP TABLE dbo.WaTemplates;
IF OBJECT_ID('dbo.WaContacts', 'U') IS NOT NULL DROP TABLE dbo.WaContacts;
IF OBJECT_ID('dbo.WaRates', 'U') IS NOT NULL DROP TABLE dbo.WaRates;
IF OBJECT_ID('dbo.WaSettings', 'U') IS NOT NULL DROP TABLE dbo.WaSettings;
IF OBJECT_ID('dbo.WaConnection', 'U') IS NOT NULL DROP TABLE dbo.WaConnection;
GO
