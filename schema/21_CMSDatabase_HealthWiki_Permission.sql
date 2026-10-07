-- =============================================================================
-- CMSDatabase -- Add health-wiki.manage Permission
-- =============================================================================
-- The CMS "Health Wiki" area (articles, contributors, verification, WhatsApp
-- invitations) is gated by health-wiki.manage in the CMS web app (sidebar item
-- and routes) and will be enforced on the CMS API endpoints too. Without this
-- row no user can see the menu. This script seeds the permission and grants it
-- to the Administrator role. Other roles can be given it from Users & Access.
--
-- Idempotent and safe to re-run. Users must sign in again to pick up the new
-- permission, because the CMS web app reads permissions at login.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Insert health-wiki.manage
IF NOT EXISTS (SELECT 1 FROM dbo.CmsPermissions WHERE [Key] = 'health-wiki.manage')
BEGIN
    INSERT INTO dbo.CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (
        NEWID(),
        'health-wiki.manage',
        'health-wiki',
        'manage',
        'Manage Health Wiki',
        'Health Wiki',
        110
    );
    PRINT 'Permission inserted: health-wiki.manage';
END
ELSE
BEGIN
    PRINT 'Permission already exists: health-wiki.manage -- skipping insert.';
END
GO

-- Grant health-wiki.manage to Administrator
DECLARE @ManagePermId UNIQUEIDENTIFIER = (
    SELECT PermissionId FROM dbo.CmsPermissions WHERE [Key] = 'health-wiki.manage'
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
        PRINT 'Role-permission mapping created: Administrator -> health-wiki.manage';
    END
    ELSE
    BEGIN
        PRINT 'Mapping already exists: Administrator -> health-wiki.manage -- skipping.';
    END
END
ELSE
BEGIN
    PRINT 'ERROR: Could not find health-wiki.manage PermissionId after insert.';
END
GO
