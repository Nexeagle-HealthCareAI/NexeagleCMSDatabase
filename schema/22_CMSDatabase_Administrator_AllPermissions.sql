-- =============================================================================
-- CMSDatabase -- Grant every existing permission to the Administrator role
-- =============================================================================
-- Several permissions were seeded without being granted to Administrator (for
-- example hospitals.manage, which stayed ungranted until script 18), so an
-- admin could miss menu tabs or be unable to save changes. This one-time sweep
-- grants Administrator every permission that exists in dbo.CmsPermissions today.
--
-- It does NOT cover permissions added later: each new permission script must
-- still grant itself to Administrator (as 21_CMSDatabase_HealthWiki_Permission
-- does), or the CMS API can treat Administrator as holding all permissions.
--
-- Idempotent and safe to re-run. Users must sign in again to pick up the new
-- permissions, because the CMS web app reads them at login.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

DECLARE @AdministratorRoleId UNIQUEIDENTIFIER = 'B0000001-0000-0000-0000-000000000001';

IF NOT EXISTS (SELECT 1 FROM dbo.CmsRoles WHERE RoleId = @AdministratorRoleId)
BEGIN
    PRINT 'ERROR: Administrator role not found -- nothing granted.';
END
ELSE
BEGIN
    INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
    SELECT @AdministratorRoleId, p.PermissionId
    FROM dbo.CmsPermissions p
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.CmsRolePermissions rp
        WHERE rp.RoleId = @AdministratorRoleId
          AND rp.PermissionId = p.PermissionId
    );

    PRINT CONCAT('Granted to Administrator: ', @@ROWCOUNT, ' permission(s) that were missing.');
END
GO
