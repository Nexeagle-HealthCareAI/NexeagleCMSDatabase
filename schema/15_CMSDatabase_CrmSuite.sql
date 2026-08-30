-- ============================================================
-- 15_CMSDatabase_CrmSuite.sql
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CrmLeads')
BEGIN
    CREATE TABLE CrmLeads (
        Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        LeadNumber NVARCHAR(50) NOT NULL UNIQUE,
        ContactName NVARCHAR(150) NOT NULL,
        FacilityName NVARCHAR(200) NOT NULL,
        FacilityType NVARCHAR(50) NOT NULL, 
        BedCount INT NOT NULL DEFAULT 0,
        City NVARCHAR(100) NOT NULL,
        State NVARCHAR(100) NOT NULL DEFAULT 'Bihar',
        PhoneNumber NVARCHAR(20) NOT NULL,
        Email NVARCHAR(150),
        SourceChannel NVARCHAR(50) NOT NULL,
        UtmSource NVARCHAR(100),
        UtmMedium NVARCHAR(100),
        UtmCampaign NVARCHAR(150),
        UtmAdId NVARCHAR(100),
        Status NVARCHAR(50) NOT NULL DEFAULT 'NEW',
        AiIntentScore INT NOT NULL DEFAULT 50,
        AiPersonaSummary NVARCHAR(MAX),
        AssignedSalesRepId UNIQUEIDENTIFIER NULL REFERENCES CmsUsers(UserId) ON DELETE SET NULL,
        DealValue DECIMAL(12,2) DEFAULT 0.00,
        LostReason NVARCHAR(MAX),
        CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
    );

    CREATE INDEX IX_CrmLeads_PhoneNumber ON CrmLeads(PhoneNumber);
    CREATE INDEX IX_CrmLeads_Status ON CrmLeads(Status);
    CREATE INDEX IX_CrmLeads_SourceChannel ON CrmLeads(SourceChannel);
    
    PRINT 'Created table CrmLeads';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CrmLeadActivities')
BEGIN
    CREATE TABLE CrmLeadActivities (
        Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        LeadId UNIQUEIDENTIFIER NOT NULL REFERENCES CrmLeads(Id) ON DELETE CASCADE,
        ActivityType NVARCHAR(50) NOT NULL, 
        Direction NVARCHAR(10) NOT NULL DEFAULT 'OUTBOUND',
        MessageBody NVARCHAR(MAX) NOT NULL,
        TemplateName NVARCHAR(100),
        MediaUrl NVARCHAR(500),
        WhatsappMessageId NVARCHAR(100),
        Status NVARCHAR(30) NOT NULL DEFAULT 'DELIVERED',
        PerformedBy UNIQUEIDENTIFIER NULL REFERENCES CmsUsers(UserId) ON DELETE SET NULL,
        CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
    );

    CREATE INDEX IX_CrmLeadActivities_LeadId ON CrmLeadActivities(LeadId, CreatedAt DESC);

    PRINT 'Created table CrmLeadActivities';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CrmCampaigns')
BEGIN
    CREATE TABLE CrmCampaigns (
        Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        CampaignName NVARCHAR(200) NOT NULL,
        Platform NVARCHAR(50) NOT NULL,
        ExternalCampaignId NVARCHAR(100),
        StartDate DATE NOT NULL,
        EndDate DATE,
        BudgetAllocated DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        ActualSpend DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        TargetSpecialty NVARCHAR(100),
        TargetGeography NVARCHAR(100) DEFAULT 'Bihar',
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Created table CrmCampaigns';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CrmSocialPosts')
BEGIN
    CREATE TABLE CrmSocialPosts (
        Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        CampaignId UNIQUEIDENTIFIER NULL REFERENCES CrmCampaigns(Id) ON DELETE SET NULL,
        PlatformsTargeted NVARCHAR(MAX) NOT NULL, -- JSON array
        PostTitle NVARCHAR(250) NOT NULL,
        PostCaption NVARCHAR(MAX) NOT NULL,
        MediaAssetUrls NVARCHAR(MAX) NOT NULL DEFAULT '[]', -- JSON array
        ScheduledPublishTime DATETIME2(0) NOT NULL,
        PublishedStatus NVARCHAR(30) NOT NULL DEFAULT 'SCHEDULED',
        PublishedPostIds NVARCHAR(MAX) DEFAULT '{}', -- JSON object
        GroqPromptUsed NVARCHAR(MAX),
        CreatedBy UNIQUEIDENTIFIER NULL REFERENCES CmsUsers(UserId) ON DELETE SET NULL,
        CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Created table CrmSocialPosts';
END
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'CrmWhatsappTemplates')
BEGIN
    CREATE TABLE CrmWhatsappTemplates (
        Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        TemplateName NVARCHAR(100) NOT NULL UNIQUE,
        Category NVARCHAR(50) NOT NULL,
        Language NVARCHAR(10) NOT NULL DEFAULT 'en',
        HeaderType NVARCHAR(20) DEFAULT 'VIDEO',
        HeaderMediaUrl NVARCHAR(500),
        BodyText NVARCHAR(MAX) NOT NULL,
        FooterText NVARCHAR(150),
        ButtonsConfig NVARCHAR(MAX) DEFAULT '[]', -- JSON array
        MetaApprovalStatus NVARCHAR(30) NOT NULL DEFAULT 'APPROVED',
        IsActive BIT NOT NULL DEFAULT 1
    );
    PRINT 'Created table CrmWhatsappTemplates';
END
GO
