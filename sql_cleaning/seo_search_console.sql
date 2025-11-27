/*
    Stage SEO Search Console Data
    -----------------------------
    Creates a staging table (seo_search_console_stg) from dbo.seo_search_console
    and standardizes the data type for avg_position.
*/

-- Create staging table
SELECT *
INTO dbo.seo_search_console_stg
FROM dbo.seo_search_console;

-- Inspect staging table contents
SELECT *
FROM dbo.seo_search_console_stg;

-- Clean avg_position column data type
ALTER TABLE dbo.seo_search_console_stg
ALTER COLUMN avg_position DECIMAL(10, 2);
