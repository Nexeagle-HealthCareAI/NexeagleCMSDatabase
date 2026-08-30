-- =============================================================================
-- CMSDatabase — Add marketing.view Permission
-- =============================================================================
-- This permission was originally added via EF Core migration in CMSAPI 
-- (20260813070000_AddMarketingViewPermission.cs) but was missing from the 
-- manual SQL schema repository. It guards the Marketing tab in the CMS Web UI.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── Insert marketing.view ──────────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM CmsPermissions WHERE [Key] = 'marketing.view')
BEGIN
    INSERT INTO CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (NEWID(), 'marketing.view', 'marketing', 'view', 'View Marketing Tab', 'Marketing', 110);
END
GO

-- ── Grant marketing.view to Administrator ────────────────────────────────────
DECLARE @ManagePermId UNIQUEIDENTIFIER = (SELECT PermissionId FROM CmsPermissions WHERE [Key] = 'marketing.view');

IF @ManagePermId IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM CmsRolePermissions 
        WHERE RoleId = 'B0000001-0000-0000-0000-000000000001' AND PermissionId = @ManagePermId
    )
    BEGIN
        INSERT INTO CmsRolePermissions (RoleId, PermissionId)
        VALUES ('B0000001-0000-0000-0000-000000000001', @ManagePermId);
    END
END

PRINT 'Permission inserted and granted to Administrator: marketing.view';
GO
