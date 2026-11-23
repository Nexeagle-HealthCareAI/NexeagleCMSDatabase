-- =============================================================================
-- CMSDatabase -- Insights: full phone numbers of people who used the WhatsApp bot
-- =============================================================================
-- The Insights page now shows who wrote to the WhatsApp booking bot, what they
-- searched and whether they booked. Everyone with insights.view sees those rows
-- with the number masked (98XXXXXX10). This permission shows the full number,
-- click-to-chat and call links, the CSV export with numbers, and the whole
-- conversation.
--
--   insights.contacts   granted to the Administrator role here, to nobody else.
--                       Give it to the people who follow up with patients.
--                       People sign in again to pick up a new permission.
-- Safe to run more than once.
-- =============================================================================

USE CMSDatabase;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.CmsPermissions WHERE [Key] = 'insights.contacts')
BEGIN
    INSERT INTO dbo.CmsPermissions (PermissionId, [Key], PageKey, Action, DisplayName, Category, SortOrder)
    VALUES (NEWID(), 'insights.contacts', 'insights', 'contacts', 'See phone numbers and chats of WhatsApp bot users', 'Doctor Dekho', 91);
    PRINT 'Permission added: insights.contacts';
END
ELSE PRINT 'Permission already exists: insights.contacts';

INSERT INTO dbo.CmsRolePermissions (RoleId, PermissionId)
SELECT 'B0000001-0000-0000-0000-000000000001', c.PermissionId
FROM dbo.CmsPermissions c
WHERE c.[Key] = 'insights.contacts'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.CmsRolePermissions rp
      WHERE rp.RoleId = 'B0000001-0000-0000-0000-000000000001' AND rp.PermissionId = c.PermissionId
  );

PRINT CONCAT('Administrator grants added: ', @@ROWCOUNT);
GO
