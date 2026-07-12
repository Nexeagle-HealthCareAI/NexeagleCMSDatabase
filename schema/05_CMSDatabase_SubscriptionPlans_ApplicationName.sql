-- =============================================================================
-- CMSDatabase — Add ApplicationName to SubscriptionPlans
-- =============================================================================
-- Incremental migration. The base script 04_CMSDatabase_Subscriptions.sql was
-- already applied to existing databases (tracked in __MigrationHistory) and is
-- never re-run, so this new script backfills the column added by EF migration
-- AddApplicationNameToSubscriptionPlans on databases that predate it.
-- Idempotent and safe to run against any CMSDatabase.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.SubscriptionPlans', 'U') IS NOT NULL
   AND COL_LENGTH('dbo.SubscriptionPlans', 'ApplicationName') IS NULL
BEGIN
    ALTER TABLE dbo.SubscriptionPlans
        ADD ApplicationName NVARCHAR(50) NOT NULL
            CONSTRAINT DF_SubscriptionPlans_ApplicationName DEFAULT '1Rad';

    PRINT 'Added column: ApplicationName to SubscriptionPlans';
END
ELSE
    PRINT 'ApplicationName already present (or SubscriptionPlans missing) — no change';
GO
