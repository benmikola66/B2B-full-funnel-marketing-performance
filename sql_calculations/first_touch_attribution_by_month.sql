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

