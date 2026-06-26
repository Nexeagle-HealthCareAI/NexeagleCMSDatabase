-- =============================================================================
-- CMSDatabase Partners Setup Script
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.CmsPartners', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CmsPartners (
        PartnerId              UNIQUEIDENTIFIER NOT NULL,
        Name                   NVARCHAR(150)    NOT NULL,
        Age                    INT              NOT NULL,
        Sex                    NVARCHAR(20)     NOT NULL,
        HighestQualification   NVARCHAR(100)    NOT NULL,
        CurrentProfession      NVARCHAR(100)    NOT NULL,
        Address                NVARCHAR(255)    NOT NULL,
        City                   NVARCHAR(100)    NOT NULL,
        State                  NVARCHAR(100)    NOT NULL,
        Country                NVARCHAR(100)    NOT NULL,
        Pincode                NVARCHAR(20)     NOT NULL,
        Email                  NVARCHAR(256)    NULL,
        PhoneNumber            NVARCHAR(20)     NULL,
        PartnerCode            NVARCHAR(6)      NOT NULL UNIQUE,
        DashboardToken         NVARCHAR(64)     NOT NULL UNIQUE,
        CreatedByUserId        UNIQUEIDENTIFIER NULL,
        CreatedAt              DATETIME2        NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT PK_CmsPartners PRIMARY KEY (PartnerId),
        CONSTRAINT FK_CmsPartners_CreatedBy FOREIGN KEY (CreatedByUserId) REFERENCES dbo.CmsUsers (UserId) ON DELETE SET NULL
    );
    PRINT 'Created table: CmsPartners';
END
ELSE PRINT 'Table already exists: CmsPartners';
GO
