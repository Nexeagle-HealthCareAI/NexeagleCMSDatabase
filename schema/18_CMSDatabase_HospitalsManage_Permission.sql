-- =============================================================================
-- CMSDatabase -- Add hospitals.manage Permission
-- =============================================================================
-- FreeTierSettingsController's mutating endpoints (PUT global limit, PUT
-- per-hospital override) and HospitalsController's mutating endpoints were
-- gated by hospitals.manage, but this permission was never seeded -- meaning
-- no role, including Administrator, could actually save a free-tier limit
-- change from the CMS web "Free-Tier Monthly Limit" panel. This script seeds
-- the permission and grants it to the Administrator role.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Insert hospitals.manage
IF NOT EXISTS (SELECT 1 FROM dbo.CmsPermissions WHERE [Key] = 'hospitals.manage')
BEGIN
    INSERT INTO dbo.CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (
        NEWID(),
        'hospitals.manage',
        'hospitals',
        'manage',
        'Manage Hospitals (Free-Tier Limits)',
        'Hospitals',
        33
    );
    PRINT 'Permission inserted: hospitals.manage';
END
ELSE
BEGIN
    PRINT 'Permission already exists: hospitals.manage -- skipping insert.';
END
GO

-- Grant hospitals.manage to Administrator
DECLARE @ManagePermId UNIQUEIDENTIFIER = (
    SELECT PermissionId FROM dbo.CmsPermissions WHERE [Key] = 'hospitals.manage'
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
        PRINT 'Role-permission mapping created: Administrator -> hospitals.manage';
    END
    ELSE
    BEGIN
        PRINT 'Mapping already exists: Administrator -> hospitals.manage -- skipping.';
    END
END
ELSE
BEGIN
    PRINT 'ERROR: Could not find hospitals.manage PermissionId after insert.';
END
GO
