-- =============================================================================
-- CMSDatabase -- Add insights.manage Permission
-- =============================================================================
-- The SymptomRouterController's mutating endpoints (POST/PUT/DELETE training
-- examples, POST retrain) were previously gated by insights.view, meaning any
-- read-only user could modify training data and trigger model retraining.
-- They now require insights.manage. This script seeds the new permission and
-- grants it to the Administrator role.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Insert insights.manage
IF NOT EXISTS (SELECT 1 FROM dbo.CmsPermissions WHERE [Key] = 'insights.manage')
BEGIN
    INSERT INTO dbo.CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (
        NEWID(),
        'insights.manage',
        'insights',
        'manage',
        'Manage Insights (Edit Training Data / Trigger Retrain)',
        'Doctor Dekho',
        91
    );
    PRINT 'Permission inserted: insights.manage';
END
ELSE
BEGIN
    PRINT 'Permission already exists: insights.manage -- skipping insert.';
END
GO

-- Grant insights.manage to Administrator
DECLARE @ManagePermId UNIQUEIDENTIFIER = (
    SELECT PermissionId FROM dbo.CmsPermissions WHERE [Key] = 'insights.manage'
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
        PRINT 'Role-permission mapping created: Administrator -> insights.manage';
    END
    ELSE
    BEGIN
        PRINT 'Mapping already exists: Administrator -> insights.manage -- skipping.';
    END
END
ELSE
BEGIN
    PRINT 'ERROR: Could not find insights.manage PermissionId after insert.';
END
GO
