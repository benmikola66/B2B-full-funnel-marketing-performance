/*
    Stage Email Engagement Data
    ---------------------------
    1. Create a staging table (email_engagement_stg) from dbo.email_engagement.
    2. Inspect contents of the staging table.
    3. Standardize sent_at date column.
    4. Review distinct UTM campaign values.
*/

-- Create staging table
SELECT *
INTO dbo.email_engagement_stg
FROM dbo.email_engagement;

-- Inspect staging table contents
SELECT *
FROM dbo.email_engagement_stg;

-- Standardize sent_at date column
ALTER TABLE dbo.email_engagement_stg
ALTER COLUMN sent_at DATE;

-- Review distinct UTM campaign values
SELECT DISTINCT utm_campaign
FROM dbo.email_engagement_stg;
