-- =============================================================================
-- CMSDatabase -- Add drip-campaign columns to CmsSalesLeadFollowUps
-- =============================================================================
-- CmsSalesLeadFollowUp.cs (the EF entity) has carried Direction, TemplateName,
-- MediaUrl, WhatsappMessageId and Status properties since the WhatsApp drip
-- campaign feature (DripCampaignWorker.cs) was added, but the CmsSalesLeadFollowUps
-- table (created in 14_CMSDatabase_SalesLeads.sql) was never altered to match.
-- EF Core includes all five in every SELECT/INSERT against this table (e.g. the
-- Marketing tab's GET /marketing/leads, which .Include()s FollowUps), so every
-- one has been failing with "Invalid column name" -- the leads-list 500 error.
-- Idempotent and safe to re-run.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.CmsSalesLeadFollowUps', 'Direction') IS NULL
    ALTER TABLE dbo.CmsSalesLeadFollowUps ADD Direction NVARCHAR(10) NOT NULL CONSTRAINT DF_CmsSalesLeadFollowUps_Direction DEFAULT ('OUTBOUND');
IF COL_LENGTH('dbo.CmsSalesLeadFollowUps', 'TemplateName') IS NULL
    ALTER TABLE dbo.CmsSalesLeadFollowUps ADD TemplateName NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.CmsSalesLeadFollowUps', 'MediaUrl') IS NULL
    ALTER TABLE dbo.CmsSalesLeadFollowUps ADD MediaUrl NVARCHAR(500) NULL;
IF COL_LENGTH('dbo.CmsSalesLeadFollowUps', 'WhatsappMessageId') IS NULL
    ALTER TABLE dbo.CmsSalesLeadFollowUps ADD WhatsappMessageId NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.CmsSalesLeadFollowUps', 'Status') IS NULL
    ALTER TABLE dbo.CmsSalesLeadFollowUps ADD Status NVARCHAR(30) NOT NULL CONSTRAINT DF_CmsSalesLeadFollowUps_Status DEFAULT ('DELIVERED');

PRINT 'CmsSalesLeadFollowUps drip-campaign columns verified.';
GO
