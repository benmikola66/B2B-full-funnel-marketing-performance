SELECT * FROM accounts_stg;

SELECT * FROM abm_accounts_stg;

SELECT * FROM assets_stg;
SELECT * FROM content_engagement_stg;
SELECT * FROM crm_contacts_stg;
SELECT * FROM campaigns_stg;


SELECT * FROM opportunities_stg;

SELECT * FROM sales_stg;


SELECT * FROM leads_stg
WHERE contact_id = 'CON100000';
SELECT * FROM sales_activities_stg;
SELECT * FROM seo_search_console_stg;
SELECT * FROM spend_stg;
SELECT * FROM subscriptions_stg
WHERE account_id = 'ACC1236';
SELECT * FROM web_pageviews_stg;
SELECT * FROM web_sessions_stg
SELECT * FROM email_engagement_stg;



/*
    Attribution Models: First Touch, Last Touch, and Multi-Touch (Linear)
    --------------------------------------------------------------------
    This script builds reusable CTEs to model marketing attribution across:
      - Web sessions
      - Email engagements
      - Sales activities

    Core concepts:
      - "Touch": any meaningful interaction before a sale:
          * Web session with a non-null campaign_id
          * Email engagement
          * Sales activity with outcome <> 'no_answer'

      - "Buyer": a closed-won sale (order) joined back to the contact_id
        via opportunity and lead.

      - "All touches before sale": all valid touchpoints for a contact_id
        that occurred on or before the sale (booked_at).

    Models produced:
      1) First-touch attribution:
         - 100 percent of revenue from an order is attributed to the earliest touch
           for that order.

      2) Last-touch attribution:
         - 100 percent of revenue from an order is attributed to the latest touch
           before the sale.

      3) Multi-touch (linear) attribution:
         - Revenue is split evenly across all touches associated with the order.

    Notes:
      - Orders that have no qualifying touches are excluded from the attribution
        tables. You measured the revenue gap using the QA queries at the bottom
        of this script.
*/


/***********************************************************************
    FIRST TOUCH ATTRIBUTION - SUMMARY BY CHANNEL
***********************************************************************/
WITH buyers AS (
    -- Closed-won sales joined back to the contact that bought
    SELECT DISTINCT
        l.contact_id,
        o.opportunity_id,
        s.order_id,
        s.booked_amount AS sale_amount,
        s.booked_at
    FROM dbo.sales_stg s
    JOIN dbo.opportunities_stg o
        ON s.opportunity_id = o.opportunity_id
    JOIN dbo.leads_stg l
        ON o.lead_id = l.lead_id
    WHERE o.win_flag = 1
),

-- Optional: earliest lead creation date per contact (not used directly here,
-- but can be helpful for additional analysis or constraints).
lead_date AS (
    SELECT
        l.contact_id,
        MIN(l.created_at) AS first_lead_at
    FROM dbo.leads_stg l
    GROUP BY l.contact_id
),

-- Web touchpoints (only sessions tied to a campaign)
tp_web AS (
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
),

-- Email touchpoints
tp_email AS (
    SELECT
        ee.contact_id,
        ee.sent_at AS ts,  -- closest available timestamp to engagement
        CAST('email' AS VARCHAR(50)) AS touch_type,
        NULL AS source_label,
        NULL AS campaign_id,
        ee.utm_source,
        ee.utm_medium,
        ee.utm_campaign
    FROM dbo.email_engagement_stg ee
),

-- Sales touchpoints (exclude "no_answer" since that is not a true touch)
tp_sales AS (
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

-- Union of all valid touchpoints across channels
all_touches AS (
    SELECT * FROM tp_web
    UNION ALL
    SELECT * FROM tp_email
    UNION ALL
    SELECT * FROM tp_sales
),

-- Closed-won sales with the contact_id attached
sales_with_contact AS (
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

-- All touches for each sale that occurred on or before the sale date.
-- There can be multiple touches per order_id.
all_closed_sales_touches AS (
    SELECT
        s.order_id,
        s.sale_amount,
        s.booked_at,
        s.contact_id,
        t.ts AS touch_ts,
        t.touch_type,
        t.utm_source,
        t.utm_medium,
        t.utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts ASC
        ) AS rn_first,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts DESC
        ) AS rn_last,
        COUNT(*) OVER (
            PARTITION BY s.order_id
        ) AS touches_per_order   -- used later for multi-touch splitting
    FROM sales_with_contact s
    JOIN all_touches t
        ON t.contact_id = s.contact_id
       AND t.ts <= s.booked_at
),

-- First-touch attribution: earliest touch for each order
first_touch_attribution AS (
    SELECT
        order_id,
        sale_amount,
        booked_at,
        contact_id,
        touch_ts,
        utm_source,
        utm_medium,
        utm_campaign,
        touch_type
    FROM all_closed_sales_touches
    WHERE rn_first = 1
),

-- Multi-touch linear attribution: revenue split evenly per touch
multi_touch_linear AS (
    SELECT
        order_id,
        sale_amount,
        booked_at,
        contact_id,
        touch_ts,
        utm_source,
        utm_medium,
        utm_campaign,
        touch_type,
        touches_per_order,
        sale_amount * 1.0 / NULLIF(touches_per_order, 0) AS attributed_revenue
    FROM all_closed_sales_touches
),

-- Last-touch attribution: latest touch before the sale
last_touch_attribution AS (
    SELECT
        order_id,
        sale_amount,
        booked_at,
        contact_id,
        touch_ts,
        utm_source,
        utm_medium,
        utm_campaign,
        touch_type
    FROM all_closed_sales_touches
    WHERE rn_last = 1
)

-- First-touch results summarized by channel (touch_type)
SELECT
    COALESCE(touch_type, 'Unknown') AS channel,
    COUNT(*)                        AS num_sales,
    SUM(sale_amount)                AS total_revenue
FROM first_touch_attribution
GROUP BY COALESCE(touch_type, 'Unknown')
ORDER BY total_revenue DESC;
-- Note: In my original exploration, a large share of revenue showed up as
-- "Unknown" when using UTM fields. Switching to touch_type (web, email, sales)
-- produced more meaningful channel splits.


/***********************************************************************
    LAST TOUCH ATTRIBUTION - SUMMARY BY CHANNEL
***********************************************************************/
WITH buyers AS (
    SELECT DISTINCT
        l.contact_id,
        o.opportunity_id,
        s.order_id,
        s.booked_amount AS sale_amount,
        s.booked_at
    FROM dbo.sales_stg s
    JOIN dbo.opportunities_stg o
        ON s.pros opportunity_id = o.opportunity_id
    JOIN dbo.leads_stg l
        ON o.lead_id = l.lead_id
    WHERE o.win_flag = 1
),

lead_date AS (
    SELECT
        l.contact_id,
        MIN(l.created_at) AS first_lead_at
    FROM dbo.leads_stg l
    GROUP BY l.contact_id
),

tp_web AS (
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
),

tp_email AS (
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
),

tp_sales AS (
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

all_touches AS (
    SELECT * FROM tp_web
    UNION ALL
    SELECT * FROM tp_email
    UNION ALL
    SELECT * FROM tp_sales
),

sales_with_contact AS (
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

all_closed_sales_touches AS (
    SELECT
        s.order_id,
        s.sale_amount,
        s.booked_at,
        s.contact_id,
        t.ts AS touch_ts,
        t.touch_type,
        t.utm_source,
        t.utm_medium,
        t.utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts ASC
        ) AS rn_first,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts DESC
        ) AS rn_last,
        COUNT(*) OVER (
            PARTITION BY s.order_id
        ) AS touches_per_order
    FROM sales_with_contact s
    JOIN all_touches t
        ON t.contact_id = s.contact_id
       AND t.ts <= s.booked_at
),

last_touch_attribution AS (
    SELECT
        order_id,
        sale_amount,
        booked_at,
        contact_id,
        touch_ts,
        utm_source,
        utm_medium,
        utm_campaign,
        touch_type
    FROM all_closed_sales_touches
    WHERE rn_last = 1
)

-- Last-touch results summarized by channel
SELECT
    COALESCE(touch_type, 'Unknown') AS channel,
    COUNT(*)                        AS num_sales,
    SUM(sale_amount)                AS total_revenue
FROM last_touch_attribution
GROUP BY COALESCE(touch_type, 'Unknown')
ORDER BY total_revenue DESC;


/***********************************************************************
    MULTI-TOUCH LINEAR ATTRIBUTION - SUMMARY BY CHANNEL
***********************************************************************/
WITH buyers AS (
    SELECT DISTINCT
        l.contact_id,
        o.opportunity_id,
        s.order_id,
        s.booked_amount AS sale_amount,
        s.booked_at
    FROM dbo.sales_stg s
    JOIN dbo.opportunities_stg o
        ON s.opportunity_id = o.opportunity_id
    JOIN dbo.leads_stg l
        ON o.lead_id = l.lead_id
    WHERE o.win_flag = 1
),

lead_date AS (
    SELECT
        l.contact_id,
        MIN(l.created_at) AS first_lead_at
    FROM dbo.leads_stg l
    GROUP BY l.contact_id
),

tp_web AS (
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
),

tp_email AS (
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
),

tp_sales AS (
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

all_touches AS (
    SELECT * FROM tp_web
    UNION ALL
    SELECT * FROM tp_email
    UNION ALL
    SELECT * FROM tp_sales
),

sales_with_contact AS (
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

all_closed_sales_touches AS (
    SELECT
        s.order_id,
        s.sale_amount,
        s.booked_at,
        s.contact_id,
        t.ts AS touch_ts,
        t.touch_type,
        t.utm_source,
        t.utm_medium,
        t.utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts ASC
        ) AS rn_first,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts DESC
        ) AS rn_last,
        COUNT(*) OVER (
            PARTITION BY s.order_id
        ) AS touches_per_order
    FROM sales_with_contact s
    JOIN all_touches t
        ON t.contact_id = s.contact_id
       AND t.ts <= s.booked_at
),

multi_touch_linear AS (
    SELECT
        order_id,
        sale_amount,
        booked_at,
        contact_id,
        touch_ts,
        utm_source,
        utm_medium,
        utm_campaign,
        touch_type,
        touches_per_order,
        sale_amount * 1.0 / NULLIF(touches_per_order, 0) AS attributed_revenue
    FROM all_closed_sales_touches
)

-- Multi-touch (linear) results summarized by channel
SELECT
    COALESCE(touch_type, 'Unknown') AS channel,
    COUNT(DISTINCT order_id)        AS sales_touched,
    CAST(ROUND(SUM(attributed_revenue), 2) AS DECIMAL(18,2)) AS total_revenue_credit
FROM multi_touch_linear
GROUP BY COALESCE(touch_type, 'Unknown')
ORDER BY total_revenue_credit DESC;


-----------------------------------------------------------------------
-- QA CHECKS (COMMENTED OUT)
-- These were used to validate that attribution totals line up with
-- actual closed-won revenue and to measure revenue with no touches.
-----------------------------------------------------------------------

---- 1. Total won revenue (ground truth)
--SELECT SUM(s.booked_amount) AS total_won_revenue
--FROM dbo.sales_stg s
--JOIN dbo.opportunities_stg o
--    ON s.opportunity_id = o.opportunity_id
--WHERE o.win_flag = 1;

---- 2. How much of that revenue is included in the attribution model?
--SELECT
--    COUNT(DISTINCT s.order_id) AS total_won_orders,
--    SUM(s.sale_amount)         AS revenue_in_attribution
--FROM sales_with_contact s;

---- 3. How many sales have no qualifying touches at all?
--SELECT
--    COUNT(DISTINCT swc.order_id) AS orders_with_no_touches,
--    SUM(swc.sale_amount)         AS revenue_with_no_touches
--FROM sales_with_contact swc
--LEFT JOIN all_closed_sales_touches acst
--    ON acst.order_id = swc.order_id
--WHERE acst.order_id IS NULL;

-- Notes:
-- - The difference between total won revenue and total attributed revenue
--   comes from orders that have no qualifying touches (for example:
--   only web sessions with campaign_id IS NULL, no emails, and only
--   sales_activities with outcome = 'no_answer').
-- - In your exploration, this amounted to 8 orders and about 180,000
--   in revenue, which explained the gap between total revenue and
--   attributed revenue in the first-touch and multi-touch models.




--first touch by month


-- PURPOSE OF THIS QUERY (first_touch_by_month)
-- -----------------------------------------------
-- 1. Start from first_touch_attribution (one row per sale,
--    representing the first touch that led to that sale).
--
-- 2. Bucket each sale into a month using booked_at:
--       month_start = YYYY-MM-01 based on the sale date.
--
-- 3. Treat touch_type as a rough "channel" for now:
--       'web', 'email', 'sales', etc.
--    (Later I can switch this to a more detailed channel
--     using campaigns.channel if needed.)
--
-- 4. Aggregate to MONTH + CHANNEL level:
--       customers_acquired = COUNT(DISTINCT order_id)
--       total_revenue      = SUM(sale_amount)
--
-- 5. Export the final result as first_touch_by_month.csv
--    and use it in Tableau, and/or join it to spend_by_channel_month
--    if I align the channel definitions.
--

WITH buyers AS (
    SELECT DISTINCT
        l.contact_id,
        o.opportunity_id,
        s.order_id,
        s.booked_amount AS sale_amount,
        s.booked_at
    FROM dbo.sales_stg s
    JOIN dbo.opportunities_stg o ON s.opportunity_id = o.opportunity_id
    JOIN dbo.leads_stg l         ON o.lead_id = l.lead_id
    WHERE o.win_flag = 1
),



--touchpoints from web
tp_web AS (
    SELECT
        ws.contact_id,
        started_at AS ts,
        CAST(ws.channel AS varchar(50))  AS touch_type,
		NULL AS source_label,
        ws.campaign_id,
        ws.utm_source,
        ws.utm_medium,
        ws.utm_campaign
    FROM dbo.web_sessions_stg ws
	WHERE campaign_id IS NOT NULL
),

--email touchpoints
tp_email AS (
    SELECT
        ee.contact_id,
        ee.sent_at,--closest I could get to the engagement time
        CAST('email' AS varchar(50)) AS touch_type,
		NULL AS source_label,
		NULL AS campaign_id,
        ee.utm_source,
        ee.utm_medium,
        ee.utm_campaign
    FROM dbo.email_engagement_stg ee
),

--could add sales touchpoints here but would have to add ones with successful outcomes. would be cool to check successful
--outcomes in sales activities against who was touched before!!!!need to do this
--but should be only one order id tied to each sale so maybe i need to do something with that

--sales touchpoints
tp_sales AS (
    SELECT
        sa.contact_id,
        sa.ts,
        CAST('sales' AS varchar(50)) AS touch_type,
		sa.[type] AS source_label,
		NULL AS campaign_id,
        NULL AS utm_source,
        NULL AS utm_medium,
        NULL AS utm_campaign
    FROM dbo.sales_activities_stg sa
	WHERE sa.outcome <> 'no_answer'--removing these because it wasn't a touch
),


all_touches AS (
    --SELECT * FROM tp_contact
    --UNION ALL
    --SELECT * FROM tp_lead
    --UNION ALL--removed because they don't actually show new touches..
    SELECT * FROM tp_web
    UNION ALL
    SELECT * FROM tp_email
	UNION ALL
	SELECT * FROM tp_sales
),


sales_with_contact AS (
    SELECT
        s.order_id,
        s.booked_amount          AS sale_amount,
        s.booked_at,
        l.contact_id
    FROM sales_stg s
    JOIN opportunities_stg o ON s.opportunity_id = o.opportunity_id
    JOIN leads_stg l         ON o.lead_id = l.lead_id
    WHERE o.win_flag = 1),

all_closed_sales_touches AS (
    SELECT
        s.order_id,
        s.sale_amount,
        s.booked_at,
        s.contact_id,
        t.ts                     AS touch_ts,
        t.touch_type,
        t.utm_source,
        t.utm_medium,
        t.utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts ASC
        ) AS rn_first,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts DESC
        ) AS rn_last,
		COUNT(*) OVER (
            PARTITION BY s.order_id
        ) AS touches_per_order --this will be used for multi-touch
    FROM sales_with_contact s
    JOIN all_touches t
      ON t.contact_id = s.contact_id
     AND t.ts <= s.booked_at   -- only touches before the sale
),

fta AS (
    SELECT
        order_id,
        sale_amount,
        booked_at,
        contact_id,
        touch_ts,
        utm_source,
        utm_medium,
        utm_campaign,
        touch_type
    FROM all_closed_sales_touches
    WHERE rn_first = 1 
),

first_touch_by_month AS (
    SELECT
        -- month of the sale; aligns with spend.month_start (YYYY-MM-01)
        DATEFROMPARTS(
            YEAR(booked_at),
            MONTH(booked_at),
            1
        ) AS month_start,

        COALESCE(touch_type, 'Unknown') AS channel,
        COUNT(DISTINCT order_id)        AS customers_acquired,
        SUM(sale_amount)                AS total_revenue
    FROM fta
    GROUP BY
        DATEFROMPARTS(
            YEAR(booked_at),
            MONTH(booked_at),
            1
        ),
        COALESCE(touch_type, 'Unknown')
)

SELECT
    month_start,
    channel,
    customers_acquired,
    total_revenue
FROM first_touch_by_month
ORDER BY month_start, channel;



---multi touch by month
WITH buyers AS (
    SELECT DISTINCT
        l.contact_id,
        o.opportunity_id,
        s.order_id,
        s.booked_amount AS sale_amount,
        s.booked_at
    FROM dbo.sales_stg s
    JOIN dbo.opportunities_stg o ON s.opportunity_id = o.opportunity_id
    JOIN dbo.leads_stg l         ON o.lead_id = l.lead_id
    WHERE o.win_flag = 1
),



--touchpoints from web
tp_web AS (
    SELECT
        ws.contact_id,
        started_at AS ts,
        CAST(ws.channel AS varchar(50))  AS touch_type,
		NULL AS source_label,
        ws.campaign_id,
        ws.utm_source,
        ws.utm_medium,
        ws.utm_campaign
    FROM dbo.web_sessions_stg ws
	WHERE campaign_id IS NOT NULL
),

--email touchpoints
tp_email AS (
    SELECT
        ee.contact_id,
        ee.sent_at,--closest I could get to the engagement time
        CAST('email' AS varchar(50)) AS touch_type,
		NULL AS source_label,
		NULL AS campaign_id,
        ee.utm_source,
        ee.utm_medium,
        ee.utm_campaign
    FROM dbo.email_engagement_stg ee
),

--could add sales touchpoints here but would have to add ones with successful outcomes. would be cool to check successful
--outcomes in sales activities against who was touched before!!!!need to do this
--but should be only one order id tied to each sale so maybe i need to do something with that

--sales touchpoints
tp_sales AS (
    SELECT
        sa.contact_id,
        sa.ts,
        CAST('sales' AS varchar(50)) AS touch_type,
		sa.[type] AS source_label,
		NULL AS campaign_id,
        NULL AS utm_source,
        NULL AS utm_medium,
        NULL AS utm_campaign
    FROM dbo.sales_activities_stg sa
	WHERE sa.outcome <> 'no_answer'--removing these because it wasn't a touch
),


all_touches AS (
    --SELECT * FROM tp_contact
    --UNION ALL
    --SELECT * FROM tp_lead
    --UNION ALL--removed because they don't actually show new touches..
    SELECT * FROM tp_web
    UNION ALL
    SELECT * FROM tp_email
	UNION ALL
	SELECT * FROM tp_sales
),


sales_with_contact AS (
    SELECT
        s.order_id,
        s.booked_amount          AS sale_amount,
        s.booked_at,
        l.contact_id
    FROM sales_stg s
    JOIN opportunities_stg o ON s.opportunity_id = o.opportunity_id
    JOIN leads_stg l         ON o.lead_id = l.lead_id
    WHERE o.win_flag = 1),

all_closed_sales_touches AS (
    SELECT
        s.order_id,
        s.sale_amount,
        s.booked_at,
        s.contact_id,
        t.ts                     AS touch_ts,
        t.touch_type,
        t.utm_source,
        t.utm_medium,
        t.utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts ASC
        ) AS rn_first,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts DESC
        ) AS rn_last,
		COUNT(*) OVER (
            PARTITION BY s.order_id
        ) AS touches_per_order --this will be used for multi-touch
    FROM sales_with_contact s
    JOIN all_touches t
      ON t.contact_id = s.contact_id
     AND t.ts <= s.booked_at   -- only touches before the sale
),

multi_touch_linear AS (
    SELECT
        order_id,
        sale_amount,
        booked_at,
        contact_id,
        touch_ts,
        utm_source,
        utm_medium,
        utm_campaign,
        touch_type,
        touches_per_order,
        sale_amount * 1.0 / NULLIF(touches_per_order, 0) AS attributed_revenue
    FROM all_closed_sales_touches
),

--multi_touch_by_month AS (  ----yoooo mdae a booboo here after realizing the mta table in tablau added up to like 30 million!! this is what i sused
--    SELECT
--        -- month of the sale; aligns with spend.month_start (YYYY-MM-01)
--        DATEFROMPARTS(
--            YEAR(booked_at),
--            MONTH(booked_at),
--            1
--        ) AS month_start,

--        COALESCE(touch_type, 'Unknown') AS channel,
--        COUNT(DISTINCT order_id)        AS customers_acquired,
--        SUM(sale_amount)                AS total_revenue ---this was duplicated over every touch for multi touch so we changed to attributed revenue below
--    FROM multi_touch_linear
--    GROUP BY
--        DATEFROMPARTS(
--            YEAR(booked_at),
--            MONTH(booked_at),
--            1
--        ),
--        COALESCE(touch_type, 'Unknown')

---fuck up explanation:
--
--)
multi_touch_by_month AS (
    SELECT
        DATEFROMPARTS(
            YEAR(booked_at),
            MONTH(booked_at),
            1
        ) AS month_start,

        COALESCE(touch_type, 'Unknown') AS channel,
        COUNT(DISTINCT order_id)        AS customers_touched,   -- rename is clearer
        SUM(attributed_revenue)         AS total_revenue_credit
    FROM multi_touch_linear
    GROUP BY
        DATEFROMPARTS(
            YEAR(booked_at),
            MONTH(booked_at),
            1
        ),
        COALESCE(touch_type, 'Unknown')
)

SELECT
    month_start,
    channel,
    customers_touched,
    total_revenue_credit
FROM multi_touch_by_month
ORDER BY month_start, channel;


--last touch by month
WITH buyers AS (
    SELECT DISTINCT
        l.contact_id,
        o.opportunity_id,
        s.order_id,
        s.booked_amount AS sale_amount,
        s.booked_at
    FROM dbo.sales_stg s
    JOIN dbo.opportunities_stg o ON s.opportunity_id = o.opportunity_id
    JOIN dbo.leads_stg l         ON o.lead_id = l.lead_id
    WHERE o.win_flag = 1
),



--touchpoints from web
tp_web AS (
    SELECT
        ws.contact_id,
        started_at AS ts,
        CAST(ws.channel AS varchar(50))  AS touch_type,
		NULL AS source_label,
        ws.campaign_id,
        ws.utm_source,
        ws.utm_medium,
        ws.utm_campaign
    FROM dbo.web_sessions_stg ws
	WHERE campaign_id IS NOT NULL
),

--email touchpoints
tp_email AS (
    SELECT
        ee.contact_id,
        ee.sent_at,--closest I could get to the engagement time
        CAST('email' AS varchar(50)) AS touch_type,
		NULL AS source_label,
		NULL AS campaign_id,
        ee.utm_source,
        ee.utm_medium,
        ee.utm_campaign
    FROM dbo.email_engagement_stg ee
),

--could add sales touchpoints here but would have to add ones with successful outcomes. would be cool to check successful
--outcomes in sales activities against who was touched before!!!!need to do this
--but should be only one order id tied to each sale so maybe i need to do something with that

--sales touchpoints
tp_sales AS (
    SELECT
        sa.contact_id,
        sa.ts,
        CAST('sales' AS varchar(50)) AS touch_type,
		sa.[type] AS source_label,
		NULL AS campaign_id,
        NULL AS utm_source,
        NULL AS utm_medium,
        NULL AS utm_campaign
    FROM dbo.sales_activities_stg sa
	WHERE sa.outcome <> 'no_answer'--removing these because it wasn't a touch
),


all_touches AS (
    --SELECT * FROM tp_contact
    --UNION ALL
    --SELECT * FROM tp_lead
    --UNION ALL--removed because they don't actually show new touches..
    SELECT * FROM tp_web
    UNION ALL
    SELECT * FROM tp_email
	UNION ALL
	SELECT * FROM tp_sales
),


sales_with_contact AS (
    SELECT
        s.order_id,
        s.booked_amount          AS sale_amount,
        s.booked_at,
        l.contact_id
    FROM sales_stg s
    JOIN opportunities_stg o ON s.opportunity_id = o.opportunity_id
    JOIN leads_stg l         ON o.lead_id = l.lead_id
    WHERE o.win_flag = 1),

all_closed_sales_touches AS (
    SELECT
        s.order_id,
        s.sale_amount,
        s.booked_at,
        s.contact_id,
        t.ts                     AS touch_ts,
        t.touch_type,
        t.utm_source,
        t.utm_medium,
        t.utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts ASC
        ) AS rn_first,
        ROW_NUMBER() OVER (
            PARTITION BY s.order_id
            ORDER BY t.ts DESC
        ) AS rn_last,
		COUNT(*) OVER (
            PARTITION BY s.order_id
        ) AS touches_per_order --this will be used for multi-touch
    FROM sales_with_contact s
    JOIN all_touches t
      ON t.contact_id = s.contact_id
     AND t.ts <= s.booked_at   -- only touches before the sale
),


last_touch_attribution AS (
    SELECT
        order_id,
        sale_amount,
        booked_at,
        contact_id,
        touch_ts,
        utm_source,
        utm_medium,
        utm_campaign,
        touch_type
    FROM all_closed_sales_touches
    WHERE rn_last = 1
),

last_touch_by_month AS (
    SELECT
        -- month of the sale; aligns with spend.month_start (YYYY-MM-01)
        DATEFROMPARTS(
            YEAR(booked_at),
            MONTH(booked_at),
            1
        ) AS month_start,

        COALESCE(touch_type, 'Unknown') AS channel,
        COUNT(DISTINCT order_id)        AS customers_acquired,
        SUM(sale_amount)                AS total_revenue
    FROM last_touch_attribution
    GROUP BY
        DATEFROMPARTS(
            YEAR(booked_at),
            MONTH(booked_at),
            1
        ),
        COALESCE(touch_type, 'Unknown')
)

SELECT
    month_start,
    channel,
    customers_acquired,
    total_revenue
FROM last_touch_by_month
ORDER BY month_start, channel;





