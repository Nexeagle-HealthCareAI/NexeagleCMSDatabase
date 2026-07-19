-- =============================================================================
-- Product database — HospitalSubscriptions (EasyHMS & 1Rad)
-- =============================================================================
-- Ensures the HospitalSubscriptions table the CMS reads/writes exists with the
-- expected columns. This is NOT run by the CMSDatabase deploy pipeline (that
-- pipeline only targets CMSDatabase). Run it manually against EACH product
-- database owned by the product apps:
--
--   sqlcmd ... -d EasyHMSDatabase -i HospitalSubscriptions.sql
--   sqlcmd ... -d 1RadDatabase    -i HospitalSubscriptions.sql
--
-- PlanId is a soft reference to CMSDatabase.dbo.SubscriptionPlans (cross-database;
-- FK not enforced). Idempotent and safe to re-run.
-- =============================================================================

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.HospitalSubscriptions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.HospitalSubscriptions (
        HospitalSubscriptionId UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_HospitalSubscriptions_Id DEFAULT (NEWID()),
        HospitalId             UNIQUEIDENTIFIER NOT NULL,
        PlanId                 UNIQUEIDENTIFIER NULL,
        Status                 NVARCHAR(50)     NOT NULL CONSTRAINT DF_HospitalSubscriptions_Status DEFAULT ('Trial'),
        TrialStartDate         DATETIME2(3)     NULL,
        TrialEndDate           DATETIME2(3)     NULL,
        SubscriptionStartDate  DATETIME2(3)     NULL,
        SubscriptionEndDate    DATETIME2(3)     NULL,
        NextBillingDate        DATETIME2(3)     NULL,
        PaymentAmount          DECIMAL(18,2)    NULL,
        PaymentReference       NVARCHAR(100)    NULL,
        PaymentDate            DATETIME2(3)     NULL,
        CreatedAt              DATETIME2(3)     NOT NULL CONSTRAINT DF_HospitalSubscriptions_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt              DATETIME2(3)     NOT NULL CONSTRAINT DF_HospitalSubscriptions_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_HospitalSubscriptions      PRIMARY KEY (HospitalSubscriptionId),
        CONSTRAINT FK_HospitalSubscriptions_Hosp FOREIGN KEY (HospitalId) REFERENCES dbo.Hospitals (HospitalID) ON DELETE CASCADE
    );
    PRINT 'Created table: HospitalSubscriptions';
END
ELSE PRINT 'Table already exists: HospitalSubscriptions';
GO

-- Backfill any columns the CMS depends on, for tables created before this script.
IF OBJECT_ID('dbo.HospitalSubscriptions', 'U') IS NOT NULL
BEGIN
    IF COL_LENGTH('dbo.HospitalSubscriptions', 'NextBillingDate') IS NULL
        ALTER TABLE dbo.HospitalSubscriptions ADD NextBillingDate DATETIME2(3) NULL;
    IF COL_LENGTH('dbo.HospitalSubscriptions', 'PaymentAmount') IS NULL
        ALTER TABLE dbo.HospitalSubscriptions ADD PaymentAmount DECIMAL(18,2) NULL;
    IF COL_LENGTH('dbo.HospitalSubscriptions', 'PaymentReference') IS NULL
        ALTER TABLE dbo.HospitalSubscriptions ADD PaymentReference NVARCHAR(100) NULL;
    IF COL_LENGTH('dbo.HospitalSubscriptions', 'PaymentDate') IS NULL
        ALTER TABLE dbo.HospitalSubscriptions ADD PaymentDate DATETIME2(3) NULL;
    PRINT 'HospitalSubscriptions columns verified.';
END
GO
