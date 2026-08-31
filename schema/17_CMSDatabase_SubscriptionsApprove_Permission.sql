-- =============================================================================
-- CMSDatabase — Add subscriptions.approve Permission
-- =============================================================================
-- Guards the Approve/Reject actions on SubscriptionApprovalController.
-- Only the Administrator role receives this permission by default.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── Insert subscriptions.approve ───────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM CmsPermissions WHERE [Key] = 'subscriptions.approve')
BEGIN
    INSERT INTO CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (NEWID(), 'subscriptions.approve', 'subscriptions', 'approve', 'Approve/Reject Subscriptions', 'Subscriptions', 200);
END
GO

-- ── Grant subscriptions.approve to Administrator ───────────────────────────
DECLARE @PermId UNIQUEIDENTIFIER = (SELECT PermissionId FROM CmsPermissions WHERE [Key] = 'subscriptions.approve');

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

PRINT 'Permission inserted and granted to Administrator: subscriptions.approve';
GO
