/*
    Customer Acquisition Cost (CAC) and Lifetime Value (LTV) Metrics
    ----------------------------------------------------------------
    1) Overall CAC
       - Uses total marketing spend (spend_stg)
       - Divides by number of customers (count of orders in sales_stg)

    2) Average LTV / churn by ABM vs Non-ABM
       - Builds a per-account LTV table from subscriptions_stg
       - Joins to accounts and ABM accounts to segment by ABM status

    3) Average LTV / churn by industry
       - Same LTV logic, grouped by industry

    4) Overall average LTV / churn (no segmentation)
       - LTV at account level, then averaged across all accounts
*/

------------------------------------------------------------
-- 1. Overall CAC
------------------------------------------------------------
WITH total_spend AS (
    SELECT SUM(spend) AS spend
    FROM dbo.spend_stg
),
total_customers AS (
    SELECT COUNT(order_id) AS customers
    FROM dbo.sales_stg
)
SELECT
    ts.spend / tc.customers AS CAC
FROM total_spend      AS ts
CROSS JOIN total_customers AS tc;


------------------------------------------------------------
-- 2. Avg LTV, churn rate, and lifetime months by ABM status
------------------------------------------------------------
WITH customer_ltv AS (
    SELECT
        account_id,
        COUNT(*)        AS lifetime_months,   -- number of billing periods (rows in subscriptions_stg)
        SUM(mrr)        AS total_ltv,         -- total MRR over lifetime -> a proxy for LTV
        MAX(status)     AS final_status       -- 'active' or 'churned'
    FROM dbo.subscriptions_stg
    GROUP BY account_id
),
ltv_with_segments AS (
    SELECT
        l.*,
        a.industry,
        a.employee_bucket,
        a.region,
        a.subscription_plan
    FROM customer_ltv     AS l
    JOIN dbo.accounts_stg AS a
        ON l.account_id = a.account_id
),
ltv_with_abm AS (
    SELECT
        l.*,
        CASE
            WHEN abm.account_id IS NOT NULL THEN 'ABM'
            ELSE 'Non-ABM'
        END AS abm_status,
        abm.abm_tier
    FROM ltv_with_segments   AS l
    LEFT JOIN dbo.abm_accounts_stg AS abm
        ON l.account_id = abm.account_id
)
SELECT
    abm_status,
    AVG(total_ltv)        AS avg_ltv,
    AVG(lifetime_months)  AS avg_lifetime_months,
    -- churn_rate = % of accounts with final_status = 'churned'
    SUM(CASE WHEN final_status = 'churned' THEN 1 ELSE 0 END) * 1.0
        / COUNT(*)        AS churn_rate
FROM ltv_with_abm
GROUP BY abm_status;


------------------------------------------------------------
-- 3. Avg LTV, churn rate, and lifetime months by industry
------------------------------------------------------------
WITH customer_ltv AS (
    SELECT
        account_id,
        COUNT(*)        AS lifetime_months,
        SUM(mrr)        AS total_ltv,
        MAX(status)     AS final_status
    FROM dbo.subscriptions_stg
    GROUP BY account_id
),
ltv_with_segments AS (
    SELECT
        l.*,
        a.industry,
        a.employee_bucket,
        a.region,
        a.subscription_plan
    FROM customer_ltv     AS l
    JOIN dbo.accounts_stg AS a
        ON l.account_id = a.account_id
),
ltv_with_abm AS (
    SELECT
        l.*,
        CASE
            WHEN abm.account_id IS NOT NULL THEN 'ABM'
            ELSE 'Non-ABM'
        END AS abm_status,
        abm.abm_tier
    FROM ltv_with_segments   AS l
    LEFT JOIN dbo.abm_accounts_stg AS abm
        ON l.account_id = abm.account_id
)
SELECT
    industry,
    AVG(total_ltv)        AS avg_ltv,
    AVG(lifetime_months)  AS avg_lifetime_months,
    SUM(CASE WHEN final_status = 'churned' THEN 1 ELSE 0 END) * 1.0
        / COUNT(*)        AS churn_rate
FROM ltv_with_abm
GROUP BY industry
ORDER BY avg_ltv DESC;


------------------------------------------------------------
-- 4. Overall avg LTV and churn rate (no segmentation)
------------------------------------------------------------
WITH customer_ltv AS (
    SELECT
        account_id,
        COUNT(*)        AS lifetime_months,
        SUM(mrr)        AS total_ltv,
        MAX(status)     AS final_status
    FROM dbo.subscriptions_stg
    GROUP BY account_id
)
SELECT
    AVG(total_ltv)        AS avg_ltv,
    AVG(lifetime_months)  AS avg_lifetime_months,
    SUM(CASE WHEN final_status = 'churned' THEN 1 ELSE 0 END) * 1.0
        / COUNT(*)        AS churn_rate
FROM customer_ltv;
