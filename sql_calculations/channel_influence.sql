/*
    Channel Influence on Opportunities and Customers
    -----------------------------------------------
    Purpose:
      Measure how often each channel (web, email, sales) "touches" opportunities
      and customers, without splitting revenue (pure influence, yes/no).

    Definitions:
      Touch:
        - Web session with non-null campaign_id
        - Email engagement
        - Sales activity with outcome <> 'no_answer'

      Influenced opportunity:
        - An opportunity where the related contact_id had at least one touch
          from that channel on or before the opportunity created date.

      Influenced customer:
        - A closed-won order where the related contact_id had at least one touch
          from that channel on or before the booked_at date.

    Metrics produced:
      1) Channel influence on opportunities:
           - Number of opportunities influenced by each channel
           - Percent of all opportunities influenced by each channel

      2) Channel influence on pipeline:
           - Pipeline dollars (opportunity amount) influenced by each channel
           - Percent of total pipeline influenced

      3) Channel influence on customers:
           - Number of customers (orders) influenced by each channel
           - Percent of all customers influenced
*/


/***********************************************************************
  1. CHANNEL INFLUENCE ON OPPORTUNITIES (COUNT OF OPPS)
***********************************************************************/
WITH all_touches AS (
    SELECT
        ws.contact_id,
        ws.started_at AS ts,
        CAST(ws.channel AS VARCHAR(50)) AS touch_type,
        NULL AS source_label,
        ws.campaign_id,
        ws.utm_source,
        ws.utm_medium,
        ws.utm_campaign
    FROM dbo.web_sessions_stg ws
    WHERE ws.campaign_id IS NOT NULL

    UNION ALL

    SELECT
        ee.contact_id,
        ee.sent_at AS ts,  -- closest available time to engagement
        CAST('email' AS VARCHAR(50)) AS touch_type,
        NULL AS source_label,
        NULL AS campaign_id,
        ee.utm_source,
        ee.utm_medium,
        ee.utm_campaign
    FROM dbo.email_engagement_stg ee

    UNION ALL

    SELECT
        sa.contact_id,
        sa.ts,
        CAST('sales' AS VARCHAR(50)) AS touch_type,
        sa.[type] AS source_label,
        NULL AS campaign_id,
        NULL AS utm_source,
        NULL AS utm_medium,
        NULL AS utm_campaign
    FROM dbo.sales_activities_stg sa
    WHERE sa.outcome <> 'no_answer'
),

opps_with_contactids AS (
    SELECT
        o.opportunity_id,
        o.stage,
        o.amount,
        o.created_at AS opp_created_at,
        l.contact_id
    FROM dbo.opportunities_stg o
    JOIN dbo.leads_stg l
        ON o.lead_id = l.lead_id
),

opportunity_touches AS (
    -- one row per (opportunity_id, touched_channel)
    SELECT DISTINCT
        o.opportunity_id,
        o.amount,
        o.stage,
        o.opp_created_at,
        t.touch_type AS touched_channel
    FROM opps_with_contactids o
    JOIN all_touches t
        ON o.contact_id = t.contact_id
       AND t.ts <= o.opp_created_at
)

SELECT
    touched_channel AS channel,
    COUNT(DISTINCT opportunity_id) AS ops_influenced,
    CAST(
        COUNT(DISTINCT opportunity_id) * 1.0 /
        (SELECT COUNT(DISTINCT opportunity_id) FROM dbo.opportunities_stg)
        AS DECIMAL(18,2)
    ) AS influence_opps_pct
FROM opportunity_touches
GROUP BY touched_channel
ORDER BY influence_opps_pct DESC;



/***********************************************************************
  2. CHANNEL INFLUENCE ON PIPELINE (OPPORTUNITY AMOUNT)
***********************************************************************/
WITH all_touches AS (
    SELECT
        ws.contact_id,
        ws.started_at AS ts,
        CAST(ws.channel AS VARCHAR(50)) AS touch_type,
        NULL AS source_label,
        ws.campaign_id,
        ws.utm_source,
        ws.utm_medium,
        ws.utm_campaign
    FROM dbo.web_sessions_stg ws
    WHERE ws.campaign_id IS NOT NULL

    UNION ALL

    SELECT
        ee.contact_id,
        ee.sent_at AS ts,
        CAST('email' AS VARCHAR(50)) AS touch_type,
        NULL AS source_label,
        NULL AS campaign_id,
        ee.utm_source,
        ee.utm_medium,
        ee.utm_campaign
    FROM dbo.email_engagement_stg ee

    UNION ALL

    SELECT
        sa.contact_id,
        sa.ts,
        CAST('sales' AS VARCHAR(50)) AS touch_type,
        sa.[type] AS source_label,
        NULL AS campaign_id,
        NULL AS utm_source,
        NULL AS utm_medium,
        NULL AS utm_campaign
    FROM dbo.sales_activities_stg sa
    WHERE sa.outcome <> 'no_answer'
),

opps_with_contactids AS (
    SELECT
        o.opportunity_id,
        o.stage,
        o.amount,
        o.created_at AS opp_created_at,
        l.contact_id
    FROM dbo.opportunities_stg o
    JOIN dbo.leads_stg l
        ON o.lead_id = l.lead_id
),

opportunity_touches AS (
    -- inner join: only count opportunities that actually had touches
    SELECT DISTINCT
        o.opportunity_id,
        o.amount,
        o.stage,
        o.opp_created_at,
        t.touch_type AS touched_channel
    FROM opps_with_contactids o
    JOIN all_touches t
        ON o.contact_id = t.contact_id
       AND t.ts <= o.opp_created_at
)

SELECT
    touched_channel AS channel,
    SUM(amount) AS pipeline_influenced,
    CAST(
        SUM(amount) * 1.0 /
        (SELECT SUM(amount) FROM dbo.opportunities_stg)
        AS DECIMAL(18,2)
    ) AS influence_pipeline_pct
FROM opportunity_touches
GROUP BY touched_channel
ORDER BY influence_pipeline_pct DESC;



/***********************************************************************
  3. CHANNEL INFLUENCE ON CUSTOMERS (ORDERS)
***********************************************************************/
WITH all_touches AS (
    SELECT
        ws.contact_id,
        ws.started_at AS ts,
        CAST(ws.channel AS VARCHAR(50)) AS touch_type,
        ws.campaign_id,
        ws.utm_source,
        ws.utm_medium,
        ws.utm_campaign
    FROM dbo.web_sessions_stg ws
    WHERE ws.campaign_id IS NOT NULL

    UNION ALL

    SELECT
        ee.contact_id,
        ee.sent_at AS ts,
        'email' AS touch_type,
        NULL AS campaign_id,
        ee.utm_source,
        ee.utm_medium,
        ee.utm_campaign
    FROM dbo.email_engagement_stg ee

    UNION ALL

    SELECT
        sa.contact_id,
        sa.ts,
        'sales' AS touch_type,
        NULL AS campaign_id,
        NULL AS utm_source,
        NULL AS utm_medium,
        NULL AS utm_campaign
    FROM dbo.sales_activities_stg sa
    WHERE sa.outcome <> 'no_answer'
),

sales_with_contact AS (
    -- closed-won orders with their contact_id
    SELECT
        s.order_id,
        s.booked_amount AS sale_amount,
        s.booked_at,
        l.contact_id
    FROM dbo.sales_stg s
    JOIN dbo.opportunities_stg o
        ON s.opportunity_id = o.opportunity_id
    JOIN dbo.leads_stg l
        ON o.lead_id = l.lead_id
    WHERE o.win_flag = 1
),

buyer_touches AS (
    -- one row per (order_id, channel_touched)
    SELECT DISTINCT
        swc.order_id,
        swc.contact_id,
        t.touch_type AS channel_touched
    FROM sales_with_contact swc
    INNER JOIN all_touches t
        ON t.contact_id = swc.contact_id
       AND t.ts <= swc.booked_at
)

SELECT
    channel_touched AS channel,
    COUNT(DISTINCT order_id) AS buyers_influenced,
    CAST(
        COUNT(DISTINCT order_id) * 1.0 /
        (SELECT COUNT(DISTINCT order_id) FROM sales_with_contact)
        AS DECIMAL(18,4)
    ) AS influence_customers_pct
FROM buyer_touches
GROUP BY channel_touched
ORDER BY influence_customers_pct DESC;
