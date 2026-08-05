-- =============================================================================
-- CMSDatabase — Partners management permission
-- =============================================================================
-- PartnersController's list/create/delete actions have only had [Authorize] (no
-- [HasPermission]) since 03_CMSDatabase_Partners.sql added the table -- any
-- authenticated CMS account, regardless of role, can list/create/hard-delete
-- partners (Remove, not a soft-delete). Adds 'partners.manage' and grants it to
-- Administrator, matching every other feature area's convention.
--
-- GUID note: 001-00D are all already claimed (see
-- 09_CMSDatabase_Fix_Insights_View_Permission_Collision.sql for what happens when
-- a new script reuses one by mistake) -- 00E is the next free value in sequence.
-- Idempotent and safe to re-run.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── Permission: partners.manage ──────────────────────────────────────────────
MERGE dbo.CmsPermissions AS target
USING (VALUES
    ('A0000001-0000-0000-0000-00000000000E', 'partners.manage', 'partners', 'manage', 'Manage Partner Network', 'Partners', 100)
) AS source (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
ON target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.PermissionId), source.[Key], source.PageKey, source.Action, source.DisplayName, source.Category, source.SortOrder)
WHEN MATCHED AND (
    target.[Key]       <> source.[Key]       OR
    target.DisplayName <> source.DisplayName OR
    target.SortOrder   <> source.SortOrder
) THEN
    UPDATE SET
        [Key]       = source.[Key],
        PageKey     = source.PageKey,
        Action      = source.Action,
        DisplayName = source.DisplayName,
        Category    = source.Category,
        SortOrder   = source.SortOrder;

PRINT 'Permission seeded: partners.manage';
GO

-- ── Grant partners.manage to Administrator ───────────────────────────────────
MERGE dbo.CmsRolePermissions AS target
USING (VALUES
    ('B0000001-0000-0000-0000-000000000001', 'A0000001-0000-0000-0000-00000000000E')  -- Administrator -> partners.manage
) AS source (RoleId, PermissionId)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
   AND target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, PermissionId)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), CONVERT(UNIQUEIDENTIFIER, source.PermissionId));

PRINT 'Role-permission mapping seeded: Administrator -> partners.manage';
GO
