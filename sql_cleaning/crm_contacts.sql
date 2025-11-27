/*
    Stage and Clean CRM Contacts
    ----------------------------
    1. Create a staging table (crm_contacts_stg) from dbo.crm_contacts.
    2. Clean and standardize email addresses.
    3. Identify suspicious/invalid email values.
    4. Standardize created_at date column.
    5. Rename lead_source to contact_source.
    6. De-duplicate contacts, keeping the most recent record per contact_id.
*/

-- Create staging table
SELECT *
INTO dbo.crm_contacts_stg
FROM dbo.crm_contacts;

-- Inspect staging table contents
SELECT *
FROM dbo.crm_contacts_stg;

-----------------
-- Clean emails --
-----------------
-- Trim whitespace and lowercase
UPDATE dbo.crm_contacts_stg
SET email = LOWER(LTRIM(RTRIM(email)));

-- Replace obfuscated [at] with @
UPDATE dbo.crm_contacts_stg
SET email = REPLACE(email, ' [at] ', '@');

-- Review suspicious / invalid emails
SELECT *
FROM dbo.crm_contacts_stg
WHERE email NOT LIKE '%@%.com'
   OR email IS NULL;

--------------------
-- Standardize dates
--------------------
ALTER TABLE dbo.crm_contacts_stg
ALTER COLUMN created_at DATE;

--------------------------------------------
-- Rename lead_source to contact_source
--------------------------------------------
EXEC sp_rename
    'dbo.crm_contacts_stg.lead_source',
    'contact_source',
    'COLUMN';

-----------------------
-- Check for duplicates
-----------------------
SELECT *
FROM dbo.crm_contacts_stg
WHERE contact_id IN (
    SELECT contact_id
    FROM dbo.crm_contacts_stg
    GROUP BY contact_id
    HAVING COUNT(*) > 1
);

-- Example: inspect a specific contact in source table (debugging)
SELECT *
FROM dbo.crm_contacts
WHERE contact_id = 'CON101963';

-- Inspect which rows would be considered duplicates
WITH dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY contact_id
               ORDER BY created_at DESC
           ) AS rn
    FROM dbo.crm_contacts_stg
)
SELECT *
FROM dedup
WHERE rn > 1;

---------------------------------------------
-- Remove duplicates: keep most recent record
---------------------------------------------
WITH dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY contact_id
               ORDER BY created_at DESC
           ) AS rn
    FROM dbo.crm_contacts_stg
)
DELETE
FROM dedup
WHERE rn > 1;
