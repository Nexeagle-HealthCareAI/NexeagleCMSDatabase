-- =============================================================================
-- CMSDatabase — Referral Codes (types + individual codes) + management permission
-- =============================================================================
-- Backs the new "Referral Codes" tab under CMS's Manage Subscription section.
-- ReferralCodeTypes is the admin-defined reward template (e.g. "Doctor Partner
-- 5%" = PercentageOff/5.00); ReferralCodes are individual redeemable instances
-- under a type, either typed manually by an admin or auto-generated. A code is
-- single-use globally -- RedeemedByHospitalId/RedeemedAt are set once, by
-- CMSAPI.SubscriptionApprovalController.ApprovePayment, when the redeeming
-- hospital's yearly subscription is actually approved (not at registration,
-- where the code is only tentatively attached to the hospital's trial row).
-- No FK from ReferralCodes to Hospitals: Hospital lives in the other physical
-- database (easyHMSDatabase), same reason CmsPartners has no such FK either.
-- Idempotent and safe to re-run.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.ReferralCodeTypes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ReferralCodeTypes (
        ReferralCodeTypeId UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ReferralCodeTypes PRIMARY KEY,
        Name               NVARCHAR(150)    NOT NULL,
        RewardKind         NVARCHAR(20)     NOT NULL,   -- 'PercentageOff' | 'ExtraMonths'
        RewardValue        DECIMAL(10,2)    NOT NULL,   -- 5.00 (%) or 2.00 (months)
        IsActive           BIT              NOT NULL CONSTRAINT DF_ReferralCodeTypes_IsActive DEFAULT (1),
        CreatedByUserId    UNIQUEIDENTIFIER NULL CONSTRAINT FK_ReferralCodeTypes_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt          DATETIME2(3)     NOT NULL CONSTRAINT DF_ReferralCodeTypes_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_ReferralCodeTypes_RewardKind CHECK (RewardKind IN ('PercentageOff', 'ExtraMonths'))
    );
    PRINT 'Created table: ReferralCodeTypes';
END
ELSE PRINT 'Table already exists: ReferralCodeTypes';
GO

IF OBJECT_ID('dbo.ReferralCodes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ReferralCodes (
        ReferralCodeId       UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ReferralCodes PRIMARY KEY,
        ReferralCodeTypeId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_ReferralCodes_Type REFERENCES dbo.ReferralCodeTypes(ReferralCodeTypeId),
        Code                 NVARCHAR(30)     NOT NULL UNIQUE,
        IsActive             BIT              NOT NULL CONSTRAINT DF_ReferralCodes_IsActive DEFAULT (1),
        RedeemedByHospitalId UNIQUEIDENTIFIER NULL,
        RedeemedAt           DATETIME2(3)     NULL,
        CreatedByUserId      UNIQUEIDENTIFIER NULL CONSTRAINT FK_ReferralCodes_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt            DATETIME2(3)     NOT NULL CONSTRAINT DF_ReferralCodes_CreatedAt DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_ReferralCodes_TypeId ON dbo.ReferralCodes (ReferralCodeTypeId);

    PRINT 'Created table: ReferralCodes';
END
ELSE PRINT 'Table already exists: ReferralCodes';
GO

-- ── Permission: referral-codes.manage ────────────────────────────────────────
-- GUID note: 0001-000E are all already claimed (see 10_CMSDatabase_Partners_Permission.sql) --
-- 000F is the next free value in sequence.
MERGE dbo.CmsPermissions AS target
USING (VALUES
    ('A0000001-0000-0000-0000-00000000000F', 'referral-codes.manage', 'referral-codes', 'manage', 'Manage Referral Codes', 'Subscriptions', 33)
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

PRINT 'Permission seeded: referral-codes.manage';
GO

-- ── Grant referral-codes.manage to Administrator ─────────────────────────────
MERGE dbo.CmsRolePermissions AS target
USING (VALUES
    ('B0000001-0000-0000-0000-000000000001', 'A0000001-0000-0000-0000-00000000000F')  -- Administrator -> referral-codes.manage
) AS source (RoleId, PermissionId)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
   AND target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, PermissionId)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), CONVERT(UNIQUEIDENTIFIER, source.PermissionId));

PRINT 'Role-permission mapping seeded: Administrator -> referral-codes.manage';
GO
