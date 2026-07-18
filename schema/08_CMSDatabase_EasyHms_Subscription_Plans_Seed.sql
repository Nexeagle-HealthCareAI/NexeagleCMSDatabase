-- =============================================================================
-- Seed: EasyHMS subscription plan catalog (dbo.EasyHmsSubscriptionPlans)
-- Description: The 6 fixed tiers + Enterprise, as specified for the EasyHMS
--              subscription page. Idempotent by Name so it is safe to leave in
--              the numbered migration set (tracked apply-once via
--              __MigrationHistory, but guarded here too in case of manual re-run).
-- =============================================================================

DECLARE @Features NVARCHAR(MAX) = N'["OPD","IPD","Billing","ICU Management","OT Management","Patient Follow-ups","Patient Engagement via Doctor Dekho"]';

IF NOT EXISTS (SELECT 1 FROM dbo.EasyHmsSubscriptionPlans WHERE Name = N'2 Doctors / 20 Beds')
BEGIN
    INSERT INTO dbo.EasyHmsSubscriptionPlans (PlanId, Name, BasePrice, DiscountPrice, BillingCycle, IsActive, Features, MaxDoctors, MaxBeds, IsEnterprise)
    VALUES (NEWID(), N'2 Doctors / 20 Beds', 999, 999, N'Monthly', 1, @Features, 2, 20, 0);
END

IF NOT EXISTS (SELECT 1 FROM dbo.EasyHmsSubscriptionPlans WHERE Name = N'2 Doctors / 40 Beds')
BEGIN
    INSERT INTO dbo.EasyHmsSubscriptionPlans (PlanId, Name, BasePrice, DiscountPrice, BillingCycle, IsActive, Features, MaxDoctors, MaxBeds, IsEnterprise)
    VALUES (NEWID(), N'2 Doctors / 40 Beds', 1199, 1199, N'Monthly', 1, @Features, 2, 40, 0);
END

IF NOT EXISTS (SELECT 1 FROM dbo.EasyHmsSubscriptionPlans WHERE Name = N'2 Doctors / 100 Beds')
BEGIN
    INSERT INTO dbo.EasyHmsSubscriptionPlans (PlanId, Name, BasePrice, DiscountPrice, BillingCycle, IsActive, Features, MaxDoctors, MaxBeds, IsEnterprise)
    VALUES (NEWID(), N'2 Doctors / 100 Beds', 1499, 1499, N'Monthly', 1, @Features, 2, 100, 0);
END

IF NOT EXISTS (SELECT 1 FROM dbo.EasyHmsSubscriptionPlans WHERE Name = N'4 Doctors / 20 Beds')
BEGIN
    INSERT INTO dbo.EasyHmsSubscriptionPlans (PlanId, Name, BasePrice, DiscountPrice, BillingCycle, IsActive, Features, MaxDoctors, MaxBeds, IsEnterprise)
    VALUES (NEWID(), N'4 Doctors / 20 Beds', 1199, 1199, N'Monthly', 1, @Features, 4, 20, 0);
END

IF NOT EXISTS (SELECT 1 FROM dbo.EasyHmsSubscriptionPlans WHERE Name = N'4 Doctors / 40 Beds')
BEGIN
    INSERT INTO dbo.EasyHmsSubscriptionPlans (PlanId, Name, BasePrice, DiscountPrice, BillingCycle, IsActive, Features, MaxDoctors, MaxBeds, IsEnterprise)
    VALUES (NEWID(), N'4 Doctors / 40 Beds', 1499, 1499, N'Monthly', 1, @Features, 4, 40, 0);
END

IF NOT EXISTS (SELECT 1 FROM dbo.EasyHmsSubscriptionPlans WHERE Name = N'4 Doctors / 100 Beds')
BEGIN
    INSERT INTO dbo.EasyHmsSubscriptionPlans (PlanId, Name, BasePrice, DiscountPrice, BillingCycle, IsActive, Features, MaxDoctors, MaxBeds, IsEnterprise)
    VALUES (NEWID(), N'4 Doctors / 100 Beds', 1999, 1999, N'Monthly', 1, @Features, 4, 100, 0);
END

IF NOT EXISTS (SELECT 1 FROM dbo.EasyHmsSubscriptionPlans WHERE Name = N'Enterprise')
BEGIN
    INSERT INTO dbo.EasyHmsSubscriptionPlans (PlanId, Name, BasePrice, DiscountPrice, BillingCycle, IsActive, Features, MaxDoctors, MaxBeds, IsEnterprise)
    VALUES (NEWID(), N'Enterprise', 0, 0, N'Monthly', 1, @Features, NULL, NULL, 1);
END
GO
