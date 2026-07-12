USE CMSDatabase;
GO

IF OBJECT_ID('dbo.SubscriptionPlans', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SubscriptionPlans (
        PlanId UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_SubscriptionPlans PRIMARY KEY CONSTRAINT DF_SubscriptionPlans_PlanId DEFAULT NEWID(),
        Name NVARCHAR(100) NOT NULL,
        BasePrice DECIMAL(18,2) NOT NULL,
        DiscountPrice DECIMAL(18,2) NOT NULL,
        BillingCycle NVARCHAR(50) NOT NULL,
        ApplicationName NVARCHAR(50) NOT NULL CONSTRAINT DF_SubscriptionPlans_ApplicationName DEFAULT '1Rad',
        IsActive BIT NOT NULL CONSTRAINT DF_SubscriptionPlans_IsActive DEFAULT (1),
        CreatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_SubscriptionPlans_CreatedAt DEFAULT SYSUTCDATETIME()
    );

    PRINT 'Created table: SubscriptionPlans';
END
GO

-- Added by EF migration AddApplicationNameToSubscriptionPlans; backfill for tables created before it.
IF OBJECT_ID('dbo.SubscriptionPlans', 'U') IS NOT NULL
   AND COL_LENGTH('dbo.SubscriptionPlans', 'ApplicationName') IS NULL
BEGIN
    ALTER TABLE dbo.SubscriptionPlans
        ADD ApplicationName NVARCHAR(50) NOT NULL
            CONSTRAINT DF_SubscriptionPlans_ApplicationName DEFAULT '1Rad';

    PRINT 'Added column: ApplicationName to SubscriptionPlans';
END
GO
