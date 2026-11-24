-- =============================================================================
-- CMSDatabase -- People's profiles and photos; roles and permissions organised
-- =============================================================================
-- Run after scripts 01 to 33.
--
-- 1. Profiles: CmsUsers gets JobTitle and PhotoUpdatedAt; CmsUserPhotos holds each
--    person's photo (small: the CMS resizes it to 512 px before sending it).
-- 2. Permissions: each one is put in an area of the CMS, in menu order, with a
--    plain name saying what it lets a person do. Keys do not change, so nobody's
--    access changes. Permissions for pages that were removed go to the area
--    "No longer used", which the CMS does not show.
-- 3. Roles: Administrator (everything), Manager (everything except people and
--    roles), Team member (Daily Work Board, chat, documents), Support agent (live
--    support plus the board), Insights viewer (patient app insights, read only).
--    "Support Agent" becomes "Support agent" and gains the board; the people who
--    were "Hospital Manager" become Managers, and that role is switched off.
--
-- Safe to run more than once. People see changed access when they next sign in.
-- =============================================================================

USE CMSDatabase;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ── 1. Profiles ──────────────────────────────────────────────────────────────

IF COL_LENGTH('dbo.CmsUsers', 'JobTitle') IS NULL
BEGIN
    ALTER TABLE dbo.CmsUsers ADD JobTitle NVARCHAR(100) NULL;
    PRINT 'Added column: CmsUsers.JobTitle';
END
GO

IF COL_LENGTH('dbo.CmsUsers', 'PhotoUpdatedAt') IS NULL
BEGIN
    ALTER TABLE dbo.CmsUsers ADD PhotoUpdatedAt DATETIME2 NULL;
    PRINT 'Added column: CmsUsers.PhotoUpdatedAt';
END
GO

IF OBJECT_ID('dbo.CmsUserPhotos', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CmsUserPhotos (
        UserId      UNIQUEIDENTIFIER NOT NULL,
        ContentType NVARCHAR(40)     NOT NULL,
        Data        VARBINARY(MAX)   NOT NULL,
        UpdatedAt   DATETIME2        NOT NULL,
        CONSTRAINT PK_CmsUserPhotos PRIMARY KEY (UserId),
        CONSTRAINT FK_CmsUserPhotos_User FOREIGN KEY (UserId) REFERENCES dbo.CmsUsers (UserId) ON DELETE CASCADE
    );
    PRINT 'Created table: CmsUserPhotos';
END
ELSE PRINT 'Table already exists: CmsUserPhotos';
GO

-- ── 2. Permissions, by area of the CMS ───────────────────────────────────────

UPDATE p
SET p.Category = v.Category, p.DisplayName = v.DisplayName, p.SortOrder = v.SortOrder
FROM dbo.CmsPermissions p
JOIN (VALUES
    ('dashboard.view',           'Dashboards',              'See the growth dashboard, radiology centres and Vita conversations', 10),
    ('onboarded-hospitals.view', 'Hospitals',               'See onboarded hospitals and the free tier',                          20),
    ('hospital-details.view',    'Hospitals',               'Open a hospital''s details',                                         21),
    ('hospitals.manage',         'Hospitals',               'Change hospitals, the free tier and night jobs',                     22),
    ('subscriptions.view',       'Money',                   'See approvals, plans and referral codes',                            30),
    ('subscriptions.approve',    'Money',                   'Approve subscription payments',                                      31),
    ('subscriptions.manage',     'Money',                   'Change hospital subscriptions and plans',                            32),
    ('referral-codes.manage',    'Money',                   'Create and change referral codes',                                   33),
    ('insights.view',            'Doctor Dekho & insights', 'See patient app insights and the symptom router',                    40),
    ('insights.contacts',        'Doctor Dekho & insights', 'See WhatsApp bot users'' numbers and chats',                         41),
    ('insights.manage',          'Doctor Dekho & insights', 'Train and change the symptom router',                                42),
    ('work.view',                'Daily Work Board',        'Open the Daily Work Board and team chat',                            50),
    ('work.edit',                'Daily Work Board',        'Create and update tasks',                                            51),
    ('work.manage',              'Daily Work Board',        'Create boards and change their columns',                             52),
    ('work.delete',              'Daily Work Board',        'Delete tasks and board columns',                                     53),
    ('work.members',             'Daily Work Board',        'Choose who can open each board',                                     54),
    ('work.export',              'Daily Work Board',        'Copy, print and download from the board',                            55),
    ('work.audit',               'Daily Work Board',        'See the board''s activity log',                                      56),
    ('docs.view',                'Documents',               'Read documents',                                                     60),
    ('docs.edit',                'Documents',               'Create, upload and change documents',                                61),
    ('docs.delete',              'Documents',               'Move documents to the bin and restore them',                         62),
    ('docs.sensitive',           'Documents',               'Open restricted folders and choose who can',                         63),
    ('live-support.view',        'Support',                 'Answer live support chats',                                          70),
    ('health-wiki.manage',       'Content',                 'Write and publish Health Wiki articles',                             80),
    ('emergency.manage',         'Content',                 'Manage emergency places',                                            81),
    ('vita.view',                'AI agents',               'See Test agent runs and cases',                                      90),
    ('vita.manage',              'AI agents',               'Run the Test agent and change its schedules',                        91),
    ('vita.approve',             'AI agents',               'Approve and retire test cases',                                      92),
    ('radai-cost.view',          'AI agents',               'See RadAI cost figures',                                             93),
    ('marketing.view',           'Marketing',               'See demo logins',                                                   100),
    ('marketing.manage',         'Marketing',               'Manage marketing leads and campaigns',                              101),
    ('user-management.view',     'Administration',          'See people and roles',                                              110),
    ('user-management.manage',   'Administration',          'Add people and change their roles and access',                      111),
    ('data-migration.manage',    'Administration',          'Import hospital data',                                              112),
    ('application-health.view',  'Administration',          'See application health',                                            113),
    -- Pages that were taken out of the CMS. Kept so old grants still mean something.
    ('partners.manage',          'No longer used',          'Partner network (page removed)',                                    900),
    ('settings.view',            'No longer used',          'Settings (now open to everyone as My profile)',                     901)
) AS v ([Key], Category, DisplayName, SortOrder) ON v.[Key] = p.[Key];

PRINT CONCAT('Permissions organised: ', @@ROWCOUNT);
GO

-- ── 3. Roles ─────────────────────────────────────────────────────────────────

-- Role names are unique: a role someone made by hand with one of these names keeps
-- its people and grants, renamed "(own)".
UPDATE r SET r.Name = LEFT(r.Name + ' (own)', 100)
FROM dbo.CmsRoles r
JOIN (VALUES
    ('B0000001-0000-0000-0000-000000000004', 'Manager'),
    ('B0000001-0000-0000-0000-000000000005', 'Team member'),
    ('B0000001-0000-0000-0000-000000000002', 'Support agent'),
    ('B0000001-0000-0000-0000-000000000006', 'Insights viewer')
) AS v (RoleId, Name) ON r.Name = v.Name AND r.RoleId <> CONVERT(UNIQUEIDENTIFIER, v.RoleId);
GO

MERGE dbo.CmsRoles AS target
USING (VALUES
    ('B0000001-0000-0000-0000-000000000001', 'Administrator',   'Everything, including adding people and changing roles and access.', 1),
    ('B0000001-0000-0000-0000-000000000004', 'Manager',         'Everything except adding people and changing roles and access.',    1),
    ('B0000001-0000-0000-0000-000000000005', 'Team member',     'The Daily Work Board, team chat and documents: create and update tasks.', 1),
    ('B0000001-0000-0000-0000-000000000002', 'Support agent',   'Live support chats, and the Daily Work Board as a team member.',     1),
    ('B0000001-0000-0000-0000-000000000006', 'Insights viewer', 'Patient app insights and the symptom router, read only, without patients'' numbers.', 1)
) AS source (RoleId, Name, Description, IsSystemDefined)
ON target.RoleId = CONVERT(UNIQUEIDENTIFIER, source.RoleId)
WHEN NOT MATCHED THEN
    INSERT (RoleId, Name, Description, IsSystemDefined, IsActive, CreatedAt)
    VALUES (CONVERT(UNIQUEIDENTIFIER, source.RoleId), source.Name, source.Description, source.IsSystemDefined, 1, SYSUTCDATETIME())
WHEN MATCHED THEN
    UPDATE SET Name = source.Name, Description = source.Description, IsSystemDefined = source.IsSystemDefined, IsActive = 1;
GO

-- What each role holds. Grants are only added, never taken away, so anything an
-- administrator added to a role by hand stays.
DECLARE @Grants TABLE (RoleId UNIQUEIDENTIFIER, [Key] NVARCHAR(100));

-- Administrator and Manager: every permission (Manager not people and roles).
INSERT @Grants SELECT 'B0000001-0000-0000-0000-000000000001', [Key] FROM dbo.CmsPermissions;
INSERT @Grants SELECT 'B0000001-0000-0000-0000-000000000004', [Key] FROM dbo.CmsPermissions
    WHERE [Key] NOT IN ('user-management.manage') AND Category <> 'No longer used';

INSERT @Grants VALUES
    ('B0000001-0000-0000-0000-000000000005', 'work.view'),
    ('B0000001-0000-0000-0000-000000000005', 'work.edit'),
    ('B0000001-0000-0000-0000-000000000005', 'docs.view'),
    ('B0000001-0000-0000-0000-000000000005', 'docs.edit'),
    ('B0000001-0000-0000-0000-000000000002', 'live-support.view'),
    ('B0000001-0000-0000-0000-000000000002', 'work.view'),
    ('B0000001-0000-0000-0000-000000000002', 'work.edit'),
    ('B0000001-0000-0000-0000-000000000002', 'docs.view'),
    ('B0000001-0000-0000-0000-000000000002', 'docs.edit'),
    ('B0000001-0000-0000-0000-000000000006', 'insights.view');

INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
SELECT DISTINCT g.RoleId, p.PermissionId
FROM @Grants g
JOIN dbo.CmsPermissions p ON p.[Key] = g.[Key]
WHERE NOT EXISTS (SELECT 1 FROM dbo.CmsRolePermissions rp WHERE rp.RoleId = g.RoleId AND rp.PermissionId = p.PermissionId);

PRINT CONCAT('Role grants added: ', @@ROWCOUNT);
GO

-- Hospital Manager: its people become Managers, then the role is switched off.
DECLARE @HospitalManager UNIQUEIDENTIFIER = 'B0000001-0000-0000-0000-000000000003';
DECLARE @Manager UNIQUEIDENTIFIER = 'B0000001-0000-0000-0000-000000000004';

INSERT INTO dbo.CmsUserRoles (UserId, RoleId)
SELECT ur.UserId, @Manager
FROM dbo.CmsUserRoles ur
WHERE ur.RoleId = @HospitalManager
  AND NOT EXISTS (SELECT 1 FROM dbo.CmsUserRoles m WHERE m.UserId = ur.UserId AND m.RoleId = @Manager);
PRINT CONCAT('Hospital Managers made Managers: ', @@ROWCOUNT);

DELETE FROM dbo.CmsUserRoles WHERE RoleId = @HospitalManager;
UPDATE dbo.CmsRoles
SET IsActive = 0, Description = 'No longer used: its people were made Managers (script 34).'
WHERE RoleId = @HospitalManager;
GO
