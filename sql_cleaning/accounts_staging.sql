/*
    Stage and Clean Accounts
    ------------------------
    1. Inspect raw Accounts data.
    2. Create a staging table (accounts_stg) from dbo.accounts.
    3. Check for duplicate account_ids.
    4. Clean and standardize account_name, industry, region, and subscription plan.
    5. Standardize numeric data type for current_mrr.
*/

-- Quick peek at raw source data
SELECT *
FROM dbo.accounts;

-- Create staging table
SELECT *
INTO dbo.accounts_stg
FROM dbo.accounts;

-- Inspect staging table contents
SELECT *
FROM dbo.accounts_stg;

-- Check table structure
EXEC sp_help 'dbo.accounts_stg';

-- Check for duplicate account_ids
SELECT *
FROM dbo.accounts_stg
WHERE account_id IN (
    SELECT account_id
    FROM dbo.accounts_stg
    GROUP BY account_id
    HAVING COUNT(*) > 1
);

-------------------------
-- Clean account_name  --
-------------------------
UPDATE dbo.accounts_stg
SET account_name = LOWER(LTRIM(RTRIM(account_name)));

UPDATE dbo.accounts_stg
SET account_name = REPLACE(account_name, ' ', '_');

-- Count distinct cleaned account names
SELECT COUNT(DISTINCT account_name) AS distinct_account_name_count
FROM dbo.accounts_stg;

------------------
-- Clean industry
------------------
UPDATE dbo.accounts_stg
SET industry = LOWER(LTRIM(RTRIM(industry)));

SELECT DISTINCT industry
FROM dbo.accounts_stg;

-- Inspect cleaned accounts
SELECT *
FROM dbo.accounts_stg;

----------------------------
-- Review employee_bucket --
----------------------------
SELECT DISTINCT employee_bucket
FROM dbo.accounts_stg;

---------------
-- Clean region
---------------
UPDATE dbo.accounts_stg
SET region = LOWER(LTRIM(RTRIM(region)));

-------------------------------------
-- Standardize current_mrr data type
-------------------------------------
ALTER TABLE dbo.accounts_stg
ALTER COLUMN current_mrr DECIMAL(10, 2);

---------------------------
-- Clean subscription plan
---------------------------
EXEC sp_rename
    'dbo.accounts_stg.plan',
    'subscription_plan',
    'COLUMN';

UPDATE dbo.accounts_stg
SET subscription_plan = LOWER(LTRIM(RTRIM(subscription_plan)));
