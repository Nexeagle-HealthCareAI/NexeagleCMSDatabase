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
        IsActive BIT NOT NULL CONSTRAINT DF_SubscriptionPlans_IsActive DEFAULT (1),
        CreatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_SubscriptionPlans_CreatedAt DEFAULT SYSUTCDATETIME()
    );

    PRINT 'Created table: SubscriptionPlans';
END
GO
