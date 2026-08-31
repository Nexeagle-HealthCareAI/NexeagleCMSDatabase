-- =============================================================================
-- CMSDatabase — Add marketing.manage Permission
-- =============================================================================
-- Guards the Create/Update/Delete actions on MarketingController.
-- Only the Administrator role receives this permission by default.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── Insert marketing.manage ───────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM CmsPermissions WHERE [Key] = 'marketing.manage')
BEGIN
    INSERT INTO CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (NEWID(), 'marketing.manage', 'marketing', 'manage', 'Manage Marketing Leads', 'Marketing', 100);
END
GO

-- ── Grant marketing.manage to Administrator ───────────────────────────
DECLARE @PermId UNIQUEIDENTIFIER = (SELECT PermissionId FROM CmsPermissions WHERE [Key] = 'marketing.manage');

IF @PermId IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM CmsRolePermissions
        WHERE RoleId = 'B0000001-0000-0000-0000-000000000001' AND PermissionId = @PermId
    )
    BEGIN
        INSERT INTO CmsRolePermissions (RoleId, PermissionId)
        VALUES ('B0000001-0000-0000-0000-000000000001', @PermId);
    END
END
GO

PRINT 'Permission inserted and granted to Administrator: marketing.manage';
GO
