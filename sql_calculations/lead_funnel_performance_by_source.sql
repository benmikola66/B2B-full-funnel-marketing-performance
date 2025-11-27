/*
    Lead Funnel Performance by Source
    ---------------------------------
    Purpose:
      This query analyzes the full lead-to-revenue funnel broken down by
      lead_source. It connects leads to their downstream opportunities
      and closed-won revenue.

    What this query does:
      1. Builds a base table (lead_base) that:
         - Starts with all leads
         - Left joins opportunities created from those leads
         - Left joins sales tied to those opportunities

      2. Calculates funnel metrics for each lead source:
         - Lead count
         - MQL count
         - SQL count
         - Opportunities created
         - Closed-won opportunities
         - Pipeline generated
         - Revenue generated

      3. Computes conversion rates:
         - Lead to Opportunity
         - Opportunity to Win
         - Lead to Win

    Output:
      One row per lead_source with pipeline, revenue, and funnel conversion metrics.
*/

WITH lead_base AS (
    SELECT
        l.lead_id,
        l.source AS lead_source,     -- original channel that created the lead
        l.created_at,
        l.mql_flag AS mql_status,
        l.sql_flag AS sql_status,

        -- opportunity level data
        o.opportunity_id,
        o.stage,
        o.amount AS pipeline_amount,
        o.win_flag,

        -- sales level data
        s.order_id,
        s.booked_amount AS revenue
    FROM dbo.leads_stg l
    LEFT JOIN dbo.opportunities_stg o
        ON o.lead_id = l.lead_id
    LEFT JOIN dbo.sales_stg s
        ON s.opportunity_id = o.opportunity_id
)

SELECT
    lead_source,

    -- lead counts and qualification
    COUNT(DISTINCT lead_id) AS leads,
    COUNT(DISTINCT CASE WHEN mql_status = 1 THEN lead_id END) AS mqls,
    COUNT(DISTINCT CASE WHEN sql_status = 1 THEN lead_id END) AS sqls,

    -- opportunity metrics
    COUNT(DISTINCT opportunity_id) AS opps,
    COUNT(DISTINCT CASE WHEN win_flag = 1 THEN opportunity_id END) AS won_opps,

    -- pipeline and revenue
    SUM(pipeline_amount) AS pipeline_amount,
    SUM(CASE WHEN win_flag = 1 THEN revenue END) AS closed_won_revenue,

    -- conversion rates
    CAST(
        COUNT(DISTINCT opportunity_id) * 1.0 /
        NULLIF(COUNT(DISTINCT lead_id), 0)
        AS DECIMAL(18,4)
    ) AS lead_to_opp_rate,

    CAST(
        COUNT(DISTINCT CASE WHEN win_flag = 1 THEN opportunity_id END) * 1.0 /
        NULLIF(COUNT(DISTINCT opportunity_id), 0)
        AS DECIMAL(18,4)
    ) AS opp_to_win_rate,

    CAST(
        COUNT(DISTINCT CASE WHEN win_flag = 1 THEN opportunity_id END) * 1.0 /
        NULLIF(COUNT(DISTINCT lead_id), 0)
        AS DECIMAL(18,4)
    ) AS lead_to_win_rate

FROM lead_base
GROUP BY lead_source
ORDER BY closed_won_revenue DESC;
