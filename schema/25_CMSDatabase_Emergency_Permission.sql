-- =============================================================================
-- CMSDatabase -- Add emergency.manage Permission (Vita emergency takeover)
-- =============================================================================
-- The CMS "Emergency takeover" page (Vita, vision Phase 3): verify the
-- emergency details hospitals submit from the 1HMS portal, add emergency
-- places that are not on 1HMS (district hospitals, ambulance services) and
-- read the log of emergency alerts. Gated by emergency.manage in the CMS web
-- app and on the CMS API. This script seeds the permission and grants it to
-- the Administrator role. Other roles can be given it from Users & Access.
--
-- Idempotent and safe to re-run. Users must sign in again to pick up the new
-- permission, because the CMS web app reads permissions at login.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Insert emergency.manage
IF NOT EXISTS (SELECT 1 FROM dbo.CmsPermissions WHERE [Key] = 'emergency.manage')
BEGIN
    INSERT INTO dbo.CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (
        NEWID(),
        'emergency.manage',
        'emergency',
        'manage',
        'Manage emergency takeover (verify hospitals, add places, alert log)',
        'Vita Emergency',
        130
    );
    PRINT 'Permission inserted: emergency.manage';
END
ELSE
BEGIN
    PRINT 'Permission already exists: emergency.manage -- skipping insert.';
END
GO

-- Grant emergency.manage to Administrator
DECLARE @ManagePermId UNIQUEIDENTIFIER = (
    SELECT PermissionId FROM dbo.CmsPermissions WHERE [Key] = 'emergency.manage'
);

IF @ManagePermId IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM dbo.CmsRolePermissions
        WHERE RoleId = 'B0000001-0000-0000-0000-000000000001'
          AND PermissionId = @ManagePermId
    )
    BEGIN
        INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
        VALUES ('B0000001-0000-0000-0000-000000000001', @ManagePermId);
        PRINT 'Role-permission mapping created: Administrator -> emergency.manage';
    END
    ELSE
    BEGIN
        PRINT 'Mapping already exists: Administrator -> emergency.manage -- skipping.';
    END
END
ELSE
BEGIN
    PRINT 'ERROR: Could not find emergency.manage PermissionId after insert.';
END
GO
