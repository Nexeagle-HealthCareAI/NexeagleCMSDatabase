-- =============================================================================
-- CMSDatabase -- Add Vita Test Agent Permissions (vita.view / vita.manage / vita.approve)
-- =============================================================================
-- The CMS "Vita Test Agent" area (test runs, generated test cases, the PR gate
-- and schedules of the autonomous test agent) is gated in the CMS web app and
-- enforced on the CMS API's /api/v1/vita routes (VitaController):
--
--   vita.view     see the Overview, Runs and Cases tabs (read-only)
--   vita.manage   start a run, pause / resume the PR gate, edit schedules
--   vita.approve  promote a shadow case to active, or retire a case
--
-- Without these rows no user can see the menu. This script seeds the three
-- permissions and grants them to the Administrator role. Other roles can be
-- given them from Users & Access.
--
-- Idempotent and safe to re-run. Users must sign in again to pick up the new
-- permissions, because the CMS web app reads them at login.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── Permissions: vita.view / vita.manage / vita.approve ──────────────────────
-- GUID note: 0001-0010 are all already claimed (0010 by 13_CMSDatabase_DataMigration.sql;
-- scripts 16-18 and 21 used NEWID()) -- 0011, 0012 and 0013 are used here, so
-- 0014 is the next free value in sequence.
MERGE dbo.CmsPermissions AS target
USING (VALUES
    ('A0000001-0000-0000-0000-000000000011', 'vita.view',    'vita', 'view',    'View Vita Test Agent (Runs / Cases / Gate)',          'Vita Test Agent', 120),
    ('A0000001-0000-0000-0000-000000000012', 'vita.manage',  'vita', 'manage',  'Manage Vita Test Agent (Run Now / Gate / Schedules)', 'Vita Test Agent', 121),
    ('A0000001-0000-0000-0000-000000000013', 'vita.approve', 'vita', 'approve', 'Approve Vita Test Cases (Promote / Retire)',        'Vita Test Agent', 122)
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

PRINT 'Permissions seeded: vita.view, vita.manage, vita.approve';
GO

-- ── Grant vita.* to Administrator ────────────────────────────────────────────
MERGE dbo.CmsRolePermissions AS target
USING (VALUES
    ('B0000001-0000-0000-0000-000000000001', 'A0000001-0000-0000-0000-000000000011'),  -- Administrator -> vita.view
    ('B0000001-0000-0000-0000-000000000001', 'A0000001-0000-0000-0000-000000000012'),  -- Administrator -> vita.manage
    ('B0000001-0000-0000-0000-000000000001', 'A0000001-0000-0000-0000-000000000013')   -- Administrator -> vita.approve
) AS source (RoleId, PermissionId)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
   AND target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, PermissionId)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), CONVERT(UNIQUEIDENTIFIER, source.PermissionId));

PRINT 'Role-permission mappings seeded: Administrator -> vita.view, vita.manage, vita.approve';
GO
