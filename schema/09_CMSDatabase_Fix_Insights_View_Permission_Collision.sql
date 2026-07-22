-- =============================================================================
-- CMSDatabase — Fix insights.view / subscriptions.manage PermissionId collision
-- =============================================================================
-- 06_CMSDatabase_Subscriptions_Manage_And_Audit.sql reused GUID
-- 'A0000001-0000-0000-0000-00000000000C' for the new 'subscriptions.manage'
-- permission, not realizing 01_CMSDatabase_Setup.sql had already claimed that
-- exact GUID for 'insights.view'. Since MERGE there matches on PermissionId,
-- deploying 06 silently renamed the existing row's Key from 'insights.view' to
-- 'subscriptions.manage' -- the permission wasn't dropped, it was overwritten.
-- Every [HasPermission("insights.view")] endpoint (Insights tab, Symptom Router
-- tab) has been returning 403 ever since, because no permission row named
-- 'insights.view' exists anymore.
--
-- This script re-creates 'insights.view' under a fresh, uncollided GUID and
-- re-grants it to Administrator. It does NOT touch PermissionId ...000C or its
-- role grants -- that GUID now correctly means 'subscriptions.manage' and stays
-- that way. 01_CMSDatabase_Setup.sql has also been corrected in source to use
-- this same new GUID, so brand-new environments never hit the collision; this
-- script exists because __MigrationHistory never re-runs an already-applied
-- script, so already-deployed dev/prod DBs need the fix applied as a new file.
-- Idempotent and safe to re-run.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── Re-create insights.view under its own GUID ───────────────────────────────
MERGE dbo.CmsPermissions AS target
USING (VALUES
    ('A0000001-0000-0000-0000-00000000000D', 'insights.view', 'insights', 'view', 'View Insights (Visits/Logins/Appts)', 'Doctor Dekho', 90)
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

PRINT 'Permission restored: insights.view';
GO

-- ── Grant insights.view to Administrator ─────────────────────────────────────
MERGE dbo.CmsRolePermissions AS target
USING (VALUES
    ('B0000001-0000-0000-0000-000000000001', 'A0000001-0000-0000-0000-00000000000D')  -- Administrator -> insights.view
) AS source (RoleId, PermissionId)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
   AND target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, PermissionId)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), CONVERT(UNIQUEIDENTIFIER, source.PermissionId));

PRINT 'Role-permission mapping restored: Administrator -> insights.view';
GO
