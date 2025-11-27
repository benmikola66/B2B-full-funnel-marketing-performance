/*
    Stage Sales Activities
    ----------------------
    Creates a staging table (sales_activities_stg) from dbo.sales_activities,
    checks for duplicate activity records, and standardizes the date column.
*/

-- Create staging table
SELECT *
INTO dbo.sales_activities_stg
FROM dbo.sales_activities;

-- Inspect staging table contents
SELECT *
FROM dbo.sales_activities_stg;

-- Identify duplicate activity IDs
SELECT *
FROM dbo.sales_activities_stg
WHERE activity_id IN (
    SELECT activity_id
    FROM dbo.sales_activities_stg
    GROUP BY activity_id
    HAVING COUNT(*) > 1
);

-- Standardize date column
ALTER TABLE dbo.sales_activities_stg
ALTER COLUMN ts DATE;
