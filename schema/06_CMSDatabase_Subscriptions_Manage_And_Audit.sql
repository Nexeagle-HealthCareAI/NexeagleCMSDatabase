-- =============================================================================
-- CMSDatabase — Subscription management permission + audit log
-- =============================================================================
-- Supports CMS-driven hospital subscription management (activate/deactivate,
-- trial, validity, plan assignment across EasyHMS and 1Rad):
--   1. Adds the 'subscriptions.manage' permission and grants it to Administrator.
--   2. Creates the SubscriptionAuditLogs table (central audit trail for changes
--      applied to either product database).
-- Idempotent and safe to re-run.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── Permission: subscriptions.manage ─────────────────────────────────────────
MERGE dbo.CmsPermissions AS target
USING (VALUES
    ('A0000001-0000-0000-0000-00000000000C', 'subscriptions.manage', 'subscriptions', 'manage', 'Manage Hospital Subscriptions', 'Subscriptions', 32)
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

PRINT 'Permission seeded: subscriptions.manage';
GO

-- ── Grant subscriptions.manage to Administrator ──────────────────────────────
MERGE dbo.CmsRolePermissions AS target
USING (VALUES
    ('B0000001-0000-0000-0000-000000000001', 'A0000001-0000-0000-0000-00000000000C')  -- Administrator -> subscriptions.manage
) AS source (RoleId, PermissionId)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
   AND target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, PermissionId)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), CONVERT(UNIQUEIDENTIFIER, source.PermissionId));

PRINT 'Role-permission mapping seeded: Administrator -> subscriptions.manage';
GO

-- ── SubscriptionAuditLogs ────────────────────────────────────────────────────
IF OBJECT_ID('dbo.SubscriptionAuditLogs', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SubscriptionAuditLogs (
        AuditId      UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_SubscriptionAuditLogs_AuditId    DEFAULT (NEWID()),
        OccurredAt   DATETIME2(3)     NOT NULL CONSTRAINT DF_SubscriptionAuditLogs_OccurredAt DEFAULT (SYSUTCDATETIME()),
        ActorUserId  UNIQUEIDENTIFIER NULL,
        ActorEmail   NVARCHAR(256)    NULL,
        Platform     NVARCHAR(50)     NOT NULL,
        HospitalId   UNIQUEIDENTIFIER NOT NULL,
        [Action]     NVARCHAR(50)     NOT NULL,
        OldValue     NVARCHAR(1000)   NULL,
        NewValue     NVARCHAR(1000)   NULL,
        CONSTRAINT PK_SubscriptionAuditLogs PRIMARY KEY (AuditId)
    );

    CREATE INDEX IX_SubscriptionAuditLogs_Platform_Hospital
        ON dbo.SubscriptionAuditLogs (Platform, HospitalId);

    PRINT 'Created table: SubscriptionAuditLogs';
END
ELSE PRINT 'Table already exists: SubscriptionAuditLogs';
GO
