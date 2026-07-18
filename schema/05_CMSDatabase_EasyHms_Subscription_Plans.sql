USE CMSDatabase;
GO

-- Dedicated EasyHMS plan catalog, deliberately separate from dbo.SubscriptionPlans (which stays
-- 1Rad-only, untouched). EasyHMS-specific concepts -- doctor/bed limits, an Enterprise "contact
-- us" tier, a per-plan feature list -- don't map onto 1Rad's pricing model, so this is its own
-- table rather than more columns bolted onto the shared one.

IF OBJECT_ID('dbo.EasyHmsSubscriptionPlans', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.EasyHmsSubscriptionPlans (
        PlanId         UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_EasyHmsSubscriptionPlans PRIMARY KEY,
        Name           NVARCHAR(100)  NOT NULL,
        BasePrice      DECIMAL(18,2)  NOT NULL,
        DiscountPrice  DECIMAL(18,2)  NOT NULL,
        BillingCycle   NVARCHAR(50)   NOT NULL,   -- 'Monthly' | 'Yearly'
        IsActive       BIT            NOT NULL CONSTRAINT DF_EasyHmsSubscriptionPlans_IsActive DEFAULT (1),

        -- JSON array of feature strings shown on the plan tile, e.g. ["OPD","IPD","Billing"].
        -- Plain string column (not a child table) -- serialized/deserialized by the controller.
        Features       NVARCHAR(MAX)  NULL,

        -- NULL = unlimited (used for the Enterprise tier); enforced server-side in easyHMSAPI.
        MaxDoctors     INT NULL,
        MaxBeds        INT NULL,

        -- Enterprise tiers have no fixed price -- the EasyHMS tile renders a "Contact Us" CTA
        -- instead of BasePrice/DiscountPrice/a Select-Plan button when this is true.
        IsEnterprise   BIT NOT NULL CONSTRAINT DF_EasyHmsSubscriptionPlans_IsEnterprise DEFAULT (0),

        CreatedAt      DATETIME2(3) NOT NULL CONSTRAINT DF_EasyHmsSubscriptionPlans_CreatedAt DEFAULT SYSUTCDATETIME()
    );

    PRINT 'Created table: EasyHmsSubscriptionPlans';
END
GO
