/*
    Stage and De-duplicate Leads
    ----------------------------
    Creates a staging table (leads_stg) from dbo.leads,
    checks for duplicate lead IDs, removes duplicates based on first_response_at,
    and standardizes date columns.
*/

-- Create staging table
SELECT *
INTO dbo.leads_stg
FROM dbo.leads;

-- Inspect staging table contents
SELECT *
FROM dbo.leads_stg;

-- Check for duplicate lead IDs
SELECT *
FROM dbo.leads_stg
WHERE lead_id IN (
    SELECT lead_id
    FROM dbo.leads_stg
    GROUP BY lead_id
    HAVING COUNT(*) > 1
);

-- Inspect which rows would be removed as duplicates
WITH dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY lead_id
               ORDER BY first_response_at
           ) AS rn
    FROM dbo.leads_stg
)
SELECT *
FROM dedup
WHERE rn > 1;

-- Remove duplicate lead records, keeping the earliest first_response_at per lead_id
WITH dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY lead_id
               ORDER BY first_response_at
           ) AS rn
    FROM dbo.leads_stg
)
DELETE
FROM dedup
WHERE rn > 1;

-- Standardize date columns
ALTER TABLE dbo.leads_stg
ALTER COLUMN created_at DATE;

ALTER TABLE dbo.leads_stg
ALTER COLUMN first_response_at DATE;
