/*
    Stage Content Engagement Data
    -----------------------------
    1. Create a staging table (content_engagement_stg) from dbo.content_engagement.
    2. Inspect table structure.
    3. Standardize the engaged_at column data type.
*/

-- Create staging table
SELECT *
INTO dbo.content_engagement_stg
FROM dbo.content_engagement;

-- Inspect staging table contents
SELECT *
FROM dbo.content_engagement_stg;

-- Review table schema
EXEC sp_help 'dbo.content_engagement_stg';

-- Standardize engaged_at date column
ALTER TABLE dbo.content_engagement_stg
ALTER COLUMN engaged_at DATE;
