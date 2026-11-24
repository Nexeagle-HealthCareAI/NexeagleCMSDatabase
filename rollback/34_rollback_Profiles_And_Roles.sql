-- =============================================================================
-- Rollback for 34_CMSDatabase_Profiles_And_Roles.sql
-- =============================================================================
-- Removes photos and job titles, and the roles Manager, Team member and Insights
-- viewer (the people in them lose those roles). Hospital Manager is switched back
-- on, but its former people are not put back: give it to them again by hand.
-- Permission names and areas are left as they are (they change nobody's access).
-- =============================================================================

USE CMSDatabase;
GO

DELETE FROM dbo.CmsRoles WHERE RoleId IN (
    'B0000001-0000-0000-0000-000000000004',
    'B0000001-0000-0000-0000-000000000005',
    'B0000001-0000-0000-0000-000000000006');
UPDATE dbo.CmsRoles SET IsActive = 1, Description = 'Can view and manage hospitals.' WHERE RoleId = 'B0000001-0000-0000-0000-000000000003';
UPDATE dbo.CmsRoles SET Name = 'Support Agent', Description = 'Access to live support only.' WHERE RoleId = 'B0000001-0000-0000-0000-000000000002';
GO

IF OBJECT_ID('dbo.CmsUserPhotos', 'U') IS NOT NULL DROP TABLE dbo.CmsUserPhotos;
IF COL_LENGTH('dbo.CmsUsers', 'PhotoUpdatedAt') IS NOT NULL ALTER TABLE dbo.CmsUsers DROP COLUMN PhotoUpdatedAt;
IF COL_LENGTH('dbo.CmsUsers', 'JobTitle') IS NOT NULL ALTER TABLE dbo.CmsUsers DROP COLUMN JobTitle;
GO
