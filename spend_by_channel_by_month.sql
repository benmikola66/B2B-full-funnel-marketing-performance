--spend and campaign table joined for tableau
--PURPOSE OF THIS QUERY (spend_by_channel_month)
-- -------------------------------------------------
-- 1. Join raw spend data (spend_stg) to campaigns (campaigns_stg)
--    so each spend row knows which marketing channel it belongs to.
--    (campaigns_stg.channel = 'paid_search', 'paid_social', 'email', etc.)
--
-- 2. Aggregate spend, impressions, and clicks to MONTH + CHANNEL level.
--    Grain of the final table:
--         one row per (month_start, channel)
--
-- 3. This table is safe to use in Tableau and safe to join against
--    first-touch attribution that’s also aggregated by
--         month_start + channel.
--
-- 4. This is the main input for CAC, ROAS, and channel performance:
--       CAC = total_spend / customers_acquired
--       ROAS = total_revenue / total_spend
--
-- 5. Export the final SELECT as spend_by_channel_month.csv
--    and use that in Tableau instead of raw spend_stg.
-
WITH spend_enriched AS (
    SELECT
        s.campaign_id,
        s.month AS month_start, --to better show the campaign month start date in my spend and campaign join   
        s.spend,
        s.impressions,
        s.clicks,
        c.utm_source,
        c.utm_medium,
        c.utm_campaign,
        c.channel            
    FROM dbo.spend_stg s
    JOIN dbo.campaigns_stg c 
      ON s.campaign_id = c.campaign_id
),

spend_by_channel_month AS (
    SELECT
        month_start,
        channel,
        SUM(spend)       AS total_spend,
        SUM(impressions) AS total_impressions,
        SUM(clicks)      AS total_clicks
    FROM spend_enriched
    GROUP BY
        month_start,
        channel
)

SELECT
    month_start,
    channel,
    total_spend,
    total_impressions,
    total_clicks
FROM spend_by_channel_month
ORDER BY month_start, channel;

