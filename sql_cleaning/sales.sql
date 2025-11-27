/*
    Stage Sales Data
    ----------------
    Creates a staging table (sales_stg) from dbo.sales,
    checks for duplicate order IDs, and standardizes the booked_at date column.
*/

-- Create staging table
SELECT *
INTO dbo.sales_stg
FROM dbo.sales;

-- Inspect staging table contents
SELECT *
FROM dbo.sales_stg;

-- Identify duplicate order IDs
SELECT *
FROM dbo.sales_stg
WHERE order_id IN (
    SELECT order_id
    FROM dbo.sales_stg
    GROUP BY order_id
    HAVING COUNT(*) > 1
);

-- Standardize booked_at column data type
ALTER TABLE dbo.sales_stg
ALTER COLUMN booked_at DATE;
