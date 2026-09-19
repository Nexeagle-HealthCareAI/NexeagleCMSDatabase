-- =============================================================================
-- CMSDatabase -- Add missing columns to CmsSalesLeads
-- =============================================================================
-- CmsSalesLead.cs (the EF entity) has carried LeadNumber, FacilityType, BedCount,
-- Utm(Source/Medium/Campaign/AdId), AiIntentScore, AiPersonaSummary, DealValue,
-- LostReason, IsDndEnabled, IsDeleted and DeletedAt for a while (mirroring the
-- separate CrmLeads table added in 15_CMSDatabase_CrmSuite.sql), but the
-- CmsSalesLeads table (created in 14_CMSDatabase_SalesLeads.sql) was never
-- altered to match. GetLeadsPagedAsync's very first clause -- .Where(l =>
-- !l.IsDeleted) -- references a column that doesn't exist, so every call to
-- GET /marketing/leads throws "Invalid column name 'IsDeleted'" and 500s.
-- Idempotent and safe to re-run.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.CmsSalesLeads', 'LeadNumber') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD LeadNumber NVARCHAR(50) NULL;
IF COL_LENGTH('dbo.CmsSalesLeads', 'FacilityType') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD FacilityType NVARCHAR(50) NOT NULL CONSTRAINT DF_CmsSalesLeads_FacilityType DEFAULT ('HOSPITAL');
IF COL_LENGTH('dbo.CmsSalesLeads', 'BedCount') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD BedCount INT NOT NULL CONSTRAINT DF_CmsSalesLeads_BedCount DEFAULT (0);
IF COL_LENGTH('dbo.CmsSalesLeads', 'UtmSource') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD UtmSource NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.CmsSalesLeads', 'UtmMedium') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD UtmMedium NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.CmsSalesLeads', 'UtmCampaign') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD UtmCampaign NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.CmsSalesLeads', 'UtmAdId') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD UtmAdId NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.CmsSalesLeads', 'AiIntentScore') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD AiIntentScore INT NOT NULL CONSTRAINT DF_CmsSalesLeads_AiIntentScore DEFAULT (50);
IF COL_LENGTH('dbo.CmsSalesLeads', 'AiPersonaSummary') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD AiPersonaSummary NVARCHAR(MAX) NULL;
IF COL_LENGTH('dbo.CmsSalesLeads', 'DealValue') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD DealValue DECIMAL(12,2) NOT NULL CONSTRAINT DF_CmsSalesLeads_DealValue DEFAULT (0.00);
IF COL_LENGTH('dbo.CmsSalesLeads', 'LostReason') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD LostReason NVARCHAR(MAX) NULL;
IF COL_LENGTH('dbo.CmsSalesLeads', 'IsDndEnabled') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD IsDndEnabled BIT NOT NULL CONSTRAINT DF_CmsSalesLeads_IsDndEnabled DEFAULT (0);
IF COL_LENGTH('dbo.CmsSalesLeads', 'IsDeleted') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD IsDeleted BIT NOT NULL CONSTRAINT DF_CmsSalesLeads_IsDeleted DEFAULT (0);
IF COL_LENGTH('dbo.CmsSalesLeads', 'DeletedAt') IS NULL
    ALTER TABLE dbo.CmsSalesLeads ADD DeletedAt DATETIME2(0) NULL;

PRINT 'CmsSalesLeads missing columns verified.';
GO
