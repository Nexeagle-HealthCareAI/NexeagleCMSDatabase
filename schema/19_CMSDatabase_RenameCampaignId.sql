-- =============================================================================
-- CMSDatabase — Rename CmsCampaigns.Id to CampaignId
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF EXISTS (
    SELECT 1 
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'CmsCampaigns' AND COLUMN_NAME = 'Id'
)
BEGIN
    EXEC sp_rename 'CmsCampaigns.Id', 'CampaignId', 'COLUMN';
    PRINT 'Renamed column CmsCampaigns.Id to CampaignId';
END
ELSE
BEGIN
    PRINT 'Column Id does not exist on CmsCampaigns (maybe already renamed).';
END
GO
