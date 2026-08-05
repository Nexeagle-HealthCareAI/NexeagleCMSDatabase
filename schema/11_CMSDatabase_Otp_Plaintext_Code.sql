-- =============================================================================
-- CMSDatabase — Store OTP codes in plaintext instead of hashed
-- =============================================================================
-- DELIBERATE security trade-off, not an oversight: CmsOtps.CodeHash (SHA-256 of
-- the 6-digit code) meant a DB leak/dump couldn't be used directly to log in as
-- any user without brute-forcing the hash. Replacing it with plaintext Code
-- removes that protection, in exchange for being able to read a currently-valid
-- code straight from the row instead of waiting on OTP email delivery. Rows are
-- still short-lived (10-minute expiry, see AuthService.OtpExpiryMinutes) and
-- single-use (UsedAt), which bounds but does not eliminate the exposure window.
--
-- Idempotent and safe to re-run. Existing in-flight OTP rows (there should be
-- very few at any moment given the 10-minute expiry) are dropped along with the
-- old column -- anyone mid-login just requests a fresh code.
-- =============================================================================

USE CMSDatabase;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.CmsOtps', 'Code') IS NULL
BEGIN
    ALTER TABLE dbo.CmsOtps ADD Code NVARCHAR(6) NULL;
    PRINT 'Added column: Code to CmsOtps';
END
ELSE PRINT 'Column already exists: Code on CmsOtps';
GO

IF COL_LENGTH('dbo.CmsOtps', 'CodeHash') IS NOT NULL
BEGIN
    ALTER TABLE dbo.CmsOtps DROP COLUMN CodeHash;
    PRINT 'Dropped column: CodeHash from CmsOtps';
END
ELSE PRINT 'Column already absent: CodeHash on CmsOtps';
GO

-- NOT NULL only after the column exists everywhere it's needed -- doing this in
-- the same batch as the ADD above would fail on a table with existing rows.
IF COL_LENGTH('dbo.CmsOtps', 'Code') IS NOT NULL
BEGIN
    -- Any leftover NULL Code rows (from before this migration ran) are already
    -- unusable garbage regardless -- they never had a plaintext code recorded,
    -- and match nothing GetActiveOtpAsync's plaintext lookup can find, so they
    -- just sit expired. Clear them out before enforcing NOT NULL rather than
    -- leaving them as permanently-orphaned rows.
    DELETE FROM dbo.CmsOtps WHERE Code IS NULL;
    ALTER TABLE dbo.CmsOtps ALTER COLUMN Code NVARCHAR(6) NOT NULL;
    PRINT 'Column Code on CmsOtps is now NOT NULL.';
END
GO

PRINT '=== CmsOtps plaintext-code migration complete ===';
GO
