-- =============================================================================
-- CMSDatabase — Plan capacity, feature modules, and module charges
-- =============================================================================
-- Supports capacity + module based plans and the pricing calculator:
--   1. Adds capacity (MaxDoctors, MaxBeds), module toggles (IPD/OPD/Billing/Lab/RAD),
--      and an IsCustom flag to SubscriptionPlans.
--   2. Creates ModuleCharges (admin-set add-on price per module per platform;
--      Charge = 0 means the module is free/included) and seeds the 5 modules
--      for both platforms at 0.
-- Idempotent and safe to re-run.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ── SubscriptionPlans: capacity + modules + custom flag ──────────────────────
IF OBJECT_ID('dbo.SubscriptionPlans', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.SubscriptionPlans', 'MaxDoctors') IS NULL
        ALTER TABLE dbo.SubscriptionPlans ADD MaxDoctors INT NOT NULL CONSTRAINT DF_SubscriptionPlans_MaxDoctors DEFAULT (0);
    IF COL_LENGTH('dbo.SubscriptionPlans', 'MaxBeds') IS NULL
        ALTER TABLE dbo.SubscriptionPlans ADD MaxBeds INT NOT NULL CONSTRAINT DF_SubscriptionPlans_MaxBeds DEFAULT (0);
    IF COL_LENGTH('dbo.SubscriptionPlans', 'ModuleIPD') IS NULL
        ALTER TABLE dbo.SubscriptionPlans ADD ModuleIPD BIT NOT NULL CONSTRAINT DF_SubscriptionPlans_ModuleIPD DEFAULT (0);
    IF COL_LENGTH('dbo.SubscriptionPlans', 'ModuleOPD') IS NULL
        ALTER TABLE dbo.SubscriptionPlans ADD ModuleOPD BIT NOT NULL CONSTRAINT DF_SubscriptionPlans_ModuleOPD DEFAULT (0);
    IF COL_LENGTH('dbo.SubscriptionPlans', 'ModuleBilling') IS NULL
        ALTER TABLE dbo.SubscriptionPlans ADD ModuleBilling BIT NOT NULL CONSTRAINT DF_SubscriptionPlans_ModuleBilling DEFAULT (0);
    IF COL_LENGTH('dbo.SubscriptionPlans', 'ModuleLab') IS NULL
        ALTER TABLE dbo.SubscriptionPlans ADD ModuleLab BIT NOT NULL CONSTRAINT DF_SubscriptionPlans_ModuleLab DEFAULT (0);
    IF COL_LENGTH('dbo.SubscriptionPlans', 'ModuleRAD') IS NULL
        ALTER TABLE dbo.SubscriptionPlans ADD ModuleRAD BIT NOT NULL CONSTRAINT DF_SubscriptionPlans_ModuleRAD DEFAULT (0);
    IF COL_LENGTH('dbo.SubscriptionPlans', 'IsCustom') IS NULL
        ALTER TABLE dbo.SubscriptionPlans ADD IsCustom BIT NOT NULL CONSTRAINT DF_SubscriptionPlans_IsCustom DEFAULT (0);

    PRINT 'SubscriptionPlans capacity/module columns verified.';
END
GO

-- ── ModuleCharges (per platform, per module; 0 = free) ───────────────────────
IF OBJECT_ID('dbo.ModuleCharges', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ModuleCharges (
        ModuleChargeId  UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_ModuleCharges_Id DEFAULT (NEWID()),
        ApplicationName NVARCHAR(50)     NOT NULL,
        ModuleKey       NVARCHAR(20)     NOT NULL,   -- IPD | OPD | Billing | Lab | RAD
        Charge          DECIMAL(18,2)    NOT NULL CONSTRAINT DF_ModuleCharges_Charge DEFAULT (0),
        UpdatedAt       DATETIME2(3)     NOT NULL CONSTRAINT DF_ModuleCharges_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_ModuleCharges PRIMARY KEY (ModuleChargeId),
        CONSTRAINT UQ_ModuleCharges_App_Module UNIQUE (ApplicationName, ModuleKey)
    );
    PRINT 'Created table: ModuleCharges';
END
ELSE PRINT 'Table already exists: ModuleCharges';
GO

-- Seed the 5 modules for both platforms at Charge = 0 (idempotent).
MERGE dbo.ModuleCharges AS target
USING (VALUES
    ('EasyHMS','IPD'),('EasyHMS','OPD'),('EasyHMS','Billing'),('EasyHMS','Lab'),('EasyHMS','RAD'),
    ('1Rad','IPD'),('1Rad','OPD'),('1Rad','Billing'),('1Rad','Lab'),('1Rad','RAD')
) AS source (ApplicationName, ModuleKey)
ON target.ApplicationName = source.ApplicationName AND target.ModuleKey = source.ModuleKey
WHEN NOT MATCHED THEN
    INSERT (ApplicationName, ModuleKey, Charge) VALUES (source.ApplicationName, source.ModuleKey, 0);

PRINT 'ModuleCharges seeded (0 = free) for both platforms.';
GO
