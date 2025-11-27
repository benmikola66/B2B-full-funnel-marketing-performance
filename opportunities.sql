/*
    Stage Opportunities Data
    ------------------------
    Creates a staging table (opportunities_stg) from dbo.opportunities,
    checks for duplicate opportunity and lead IDs,
    and standardizes date fields.
*/

-- Create staging table
SELECT *
INTO dbo.opportunities_stg
FROM dbo.opportunities;

-- Inspect staging table contents
SELECT *
FROM dbo.opportunities_stg;

-- Check for duplicate opportunity IDs
SELECT *
FROM dbo.opportunities_stg
WHERE opportunity_id IN (
    SELECT opportunity_id
    FROM dbo.opportunities_stg
    GROUP BY opportunity_id
    HAVING COUNT(*) > 1
);  -- Expecting none

-- Check for duplicate lead IDs
SELECT *
FROM dbo.opportunities_stg
WHERE lead_id IN (
    SELECT lead_id
    FROM dbo.opportunities_stg
    GROUP BY lead_id
    HAVING COUNT(*) > 1
);

-- Standardize date columns
ALTER TABLE dbo.opportunities_stg
ALTER COLUMN created_at DATE;

ALTER TABLE dbo.opportunities_stg
ALTER COLUMN close_date DATE;
