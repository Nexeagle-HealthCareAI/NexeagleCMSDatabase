-- =============================================================================
-- CMSDatabase — Data Migration (batches, rows, doctor mapping) + management permission
-- =============================================================================
-- Backs the new "Data Migration" page in CMS: a company admin uploads a legacy
-- hospital's CSV, reviews a detected column mapping and a transformed/flagged
-- preview, before anything is written to the hospital's real clinical tables.
--
-- Phase 1 (the only phase built so far) never writes to easyHMSDatabase at all --
-- MigrationBatchRows holds the full preview state (raw + transformed row data)
-- so an admin can navigate away and back without re-uploading. CommittedAt/By
-- and RolledBackAt/By are reserved now, nullable, so Phase 2 (commit) and
-- Phase 3 (rollback) need no further schema change to start using them.
--
-- No FK from MigrationBatches.HospitalId to Hospitals, and none from
-- MigrationDoctorMap.MappedDoctorId to Doctors: both live in the other physical
-- database (easyHMSDatabase), same reason CmsPartners/ReferralCodes have none.
-- Idempotent and safe to re-run.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.MigrationBatches', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationBatches (
        BatchId            UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_MigrationBatches PRIMARY KEY,
        HospitalId         UNIQUEIDENTIFIER NOT NULL,
        DataType           NVARCHAR(30)     NOT NULL,
        SourceFileName     NVARCHAR(260)    NOT NULL,
        SourceRowCount     INT              NULL,
        Status             NVARCHAR(20)     NOT NULL CONSTRAINT DF_MigrationBatches_Status DEFAULT ('Uploaded'),
        ColumnMappingJson  NVARCHAR(MAX)    NULL,
        SummaryJson        NVARCHAR(MAX)    NULL,
        ErrorMessage       NVARCHAR(2000)   NULL,
        CreatedByUserId    UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_MigrationBatches_CreatedBy REFERENCES dbo.CmsUsers(UserId),
        CreatedAt          DATETIME2(3)     NOT NULL CONSTRAINT DF_MigrationBatches_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt          DATETIME2(3)     NOT NULL CONSTRAINT DF_MigrationBatches_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        -- Reserved for Phase 2 (commit) / Phase 3 (rollback) -- nullable so no future ALTER is needed.
        CommittedAt        DATETIME2(3)     NULL,
        CommittedByUserId  UNIQUEIDENTIFIER NULL,
        RolledBackAt       DATETIME2(3)     NULL,
        RolledBackByUserId UNIQUEIDENTIFIER NULL,
        CONSTRAINT CK_MigrationBatches_DataType CHECK (DataType IN ('AppointmentsRegister','PatientMaster')),
        CONSTRAINT CK_MigrationBatches_Status CHECK (Status IN ('Uploaded','Detected','Transforming','Ready','Failed','Committing','Committed','RolledBack'))
    );
    CREATE INDEX IX_MigrationBatches_HospitalId ON dbo.MigrationBatches (HospitalId, CreatedAt DESC);
    PRINT 'Created table: MigrationBatches';
END
ELSE PRINT 'Table already exists: MigrationBatches';
GO

IF OBJECT_ID('dbo.MigrationBatchRows', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationBatchRows (
        RowId               UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_MigrationBatchRows PRIMARY KEY,
        BatchId             UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_MigrationBatchRows_Batch REFERENCES dbo.MigrationBatches(BatchId) ON DELETE CASCADE,
        SourceRowNumber     INT              NOT NULL,
        RawDataJson         NVARCHAR(MAX)    NOT NULL,
        TransformedDataJson NVARCHAR(MAX)    NULL,
        IdentityKey         NVARCHAR(400)    NULL,
        ResolvedPatientId   NVARCHAR(20)     NULL,
        IsNewPatient        BIT              NOT NULL CONSTRAINT DF_MigrationBatchRows_IsNew DEFAULT (0),
        FlagsJson           NVARCHAR(MAX)    NULL,
        RowStatus           NVARCHAR(20)     NOT NULL CONSTRAINT DF_MigrationBatchRows_RowStatus DEFAULT ('Pending'),
        CreatedAt           DATETIME2(3)     NOT NULL CONSTRAINT DF_MigrationBatchRows_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_MigrationBatchRows_RowStatus CHECK (RowStatus IN ('Pending','Ready','Flagged','Excluded'))
    );
    CREATE INDEX IX_MigrationBatchRows_BatchId ON dbo.MigrationBatchRows (BatchId, SourceRowNumber);
    CREATE INDEX IX_MigrationBatchRows_IdentityKey ON dbo.MigrationBatchRows (BatchId, IdentityKey);
    PRINT 'Created table: MigrationBatchRows';
END
ELSE PRINT 'Table already exists: MigrationBatchRows';
GO

IF OBJECT_ID('dbo.MigrationDoctorMap', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MigrationDoctorMap (
        MapId              UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_MigrationDoctorMap PRIMARY KEY,
        BatchId            UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_MigrationDoctorMap_Batch REFERENCES dbo.MigrationBatches(BatchId) ON DELETE CASCADE,
        SourceDoctorName   NVARCHAR(200)    NOT NULL,
        SourceDepartment   NVARCHAR(200)    NULL,
        MappedDoctorId     UNIQUEIDENTIFIER NULL,
        MappedDoctorName   NVARCHAR(200)    NULL,
        CreatedAt          DATETIME2(3)     NOT NULL CONSTRAINT DF_MigrationDoctorMap_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt          DATETIME2(3)     NOT NULL CONSTRAINT DF_MigrationDoctorMap_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_MigrationDoctorMap UNIQUE (BatchId, SourceDoctorName, SourceDepartment)
    );
    PRINT 'Created table: MigrationDoctorMap';
END
ELSE PRINT 'Table already exists: MigrationDoctorMap';
GO

-- ── Permission: data-migration.manage ────────────────────────────────────────
-- GUID note: 0001-000F are all already claimed (see 12_CMSDatabase_ReferralCodes.sql) --
-- 0010 is the next free value in sequence.
MERGE dbo.CmsPermissions AS target
USING (VALUES
    ('A0000001-0000-0000-0000-000000000010', 'data-migration.manage', 'data-migration', 'manage', 'Manage Data Migration', 'Data Migration', 110)
) AS source (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
ON target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.PermissionId), source.[Key], source.PageKey, source.Action, source.DisplayName, source.Category, source.SortOrder)
WHEN MATCHED AND (
    target.[Key]       <> source.[Key]       OR
    target.DisplayName <> source.DisplayName OR
    target.SortOrder   <> source.SortOrder
) THEN
    UPDATE SET
        [Key]       = source.[Key],
        PageKey     = source.PageKey,
        Action      = source.Action,
        DisplayName = source.DisplayName,
        Category    = source.Category,
        SortOrder   = source.SortOrder;

PRINT 'Permission seeded: data-migration.manage';
GO

-- ── Grant data-migration.manage to Administrator ─────────────────────────────
MERGE dbo.CmsRolePermissions AS target
USING (VALUES
    ('B0000001-0000-0000-0000-000000000001', 'A0000001-0000-0000-0000-000000000010')  -- Administrator -> data-migration.manage
) AS source (RoleId, PermissionId)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
   AND target.PermissionId = CONVERT(UNIQUEIDENTIFIER, source.PermissionId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, PermissionId)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), CONVERT(UNIQUEIDENTIFIER, source.PermissionId));

PRINT 'Role-permission mapping seeded: Administrator -> data-migration.manage';
GO
