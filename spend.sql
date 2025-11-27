/*
    Stage Spend Table
    -----------------
    Copies the dbo.spend table into a staging table (spend_stg)
    and enforces proper data typing on the spend column.
*/

-- Create staging table
SELECT *
INTO dbo.spend_stg
FROM dbo.spend;

-- Inspect staging table contents
SELECT *
FROM dbo.spend_stg;

-- Update data type for spend column
ALTER TABLE dbo.spend_stg
ALTER COLUMN spend DECIMAL(10, 2);

