/*
    Stage and Clean ABM Accounts
    ----------------------------
    1. Inspect raw ABM accounts data.
    2. Create a staging table (abm_accounts_stg) from dbo.abm_accounts.
    3. Check for duplicate account_ids.
    4. Clean and standardize the target_reason field.
    5. Inspect distinct target_reason values and table metadata.
*/

-- Quick peek at raw source data
SELECT *
FROM dbo.abm_accounts;

-- Create staging table
SELECT *
INTO dbo.abm_accounts_stg
FROM dbo.abm_accounts;

-- Inspect staging table contents
SELECT *
FROM dbo.abm_accounts_stg;

-- Check for duplicate account_ids
SELECT *
FROM dbo.abm_accounts_stg
WHERE account_id IN (
    SELECT account_id
    FROM dbo.abm_accounts_stg
    GROUP BY account_id
    HAVING COUNT(*) > 1
);

-- Clean target_reason: trim + lowercase
UPDATE dbo.abm_accounts_stg
SET target_reason = LOWER(LTRIM(RTRIM(target_reason)));

-- Replace spaces with underscores in target_reason
UPDATE dbo.abm_accounts_stg
SET target_reason = REPLACE(target_reason, ' ', '_');

-- Review cleaned target_reason values
SELECT DISTINCT target_reason
FROM dbo.abm_accounts_stg;

-- Check table structure
EXEC sp_help 'dbo.abm_accounts_stg';

-- Reference data dictionary (if previously created)
SELECT *
FROM dbo.data_dictionary_stg;
