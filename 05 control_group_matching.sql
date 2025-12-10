-- Control Group Matching for Third Eye Blind Event Analysis
-- Creates a 1:1 matched control group based on:
-- - 91-day and 28-day pre-event GTV
-- - 91-day and 28-day pre-event order counts
-- - Zone/Region (soft match)
-- - Account age (activation date)
-- - IC+ membership status (soft match)
--
-- NOTE: Only 155 treatment users had pre-event Instacart activity.
-- Matching is performed on these active users only for valid comparison.

-- ============================================================
-- STEP 1: Build Treatment Group Feature Set (Event Attendees)
-- ============================================================
CREATE OR REPLACE TABLE sandbox_db.sarthakchudgar.thirdeyeblind_treatment_features AS
WITH treatment_users AS (
    SELECT DISTINCT user_id
    FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist_with_userid
    WHERE user_id IS NOT NULL
),

-- Get pre-event order metrics
pre_event_orders AS (
    SELECT 
        fod.user_id,
        fod.zone_id,
        MAX(CASE WHEN fod.express = 'Y' THEN 1 ELSE 0 END) AS is_express,
        
        -- 28-day pre-event metrics
        COUNT(DISTINCT CASE 
            WHEN fod.delivered_date_pt >= '2025-08-07' AND fod.delivered_date_pt <= '2025-09-03'
            THEN fod.order_delivery_id 
        END) AS orders_28d_pre,
        COALESCE(SUM(CASE 
            WHEN fod.delivered_date_pt >= '2025-08-07' AND fod.delivered_date_pt <= '2025-09-03'
            THEN gtv.gtv_amt_usd 
        END), 0) AS gtv_28d_pre,
        
        -- 91-day pre-event metrics
        COUNT(DISTINCT CASE 
            WHEN fod.delivered_date_pt >= '2025-06-05' AND fod.delivered_date_pt <= '2025-09-03'
            THEN fod.order_delivery_id 
        END) AS orders_91d_pre,
        COALESCE(SUM(CASE 
            WHEN fod.delivered_date_pt >= '2025-06-05' AND fod.delivered_date_pt <= '2025-09-03'
            THEN gtv.gtv_amt_usd 
        END), 0) AS gtv_91d_pre
        
    FROM instadata.dwh.fact_order_delivery fod
    INNER JOIN instadata.dwh.vw_delivery_gtv gtv
        ON fod.order_delivery_id = gtv.order_delivery_id
    WHERE fod.user_id IN (SELECT user_id FROM treatment_users)
      AND fod.delivery_state = 'delivered'
      AND fod.delivery_finalized_ind = 'Y'
      AND fod.deleted_ind = 'N'
      AND fod.delivered_date_pt >= '2025-06-05'
      AND fod.delivered_date_pt <= '2025-09-03'
    GROUP BY fod.user_id, fod.zone_id
)

SELECT 
    t.user_id,
    du.activation_date_pt,
    DATEDIFF('day', du.activation_date_pt, '2025-09-04') AS account_age_days,
    COALESCE(po.zone_id, du.activation_zone_id) AS zone_id,
    COALESCE(po.is_express, 0) AS is_express,
    COALESCE(po.orders_28d_pre, 0) AS orders_28d_pre,
    COALESCE(po.gtv_28d_pre, 0) AS gtv_28d_pre,
    COALESCE(po.orders_91d_pre, 0) AS orders_91d_pre,
    COALESCE(po.gtv_91d_pre, 0) AS gtv_91d_pre,
    'treatment' AS group_type
FROM treatment_users t
LEFT JOIN instadata.dwh.dim_user du ON t.user_id = du.user_id
LEFT JOIN pre_event_orders po ON t.user_id = po.user_id;


-- ============================================================
-- STEP 2: Build Candidate Pool (Non-Attendees with Activity)
-- ============================================================
CREATE OR REPLACE TABLE sandbox_db.sarthakchudgar.thirdeyeblind_candidate_pool AS
WITH treatment_users AS (
    SELECT DISTINCT user_id
    FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist_with_userid
    WHERE user_id IS NOT NULL
),

-- Get all users with pre-event activity (excluding treatment)
candidate_orders AS (
    SELECT 
        fod.user_id,
        fod.zone_id,
        MAX(CASE WHEN fod.express = 'Y' THEN 1 ELSE 0 END) AS is_express,
        
        -- 28-day pre-event metrics
        COUNT(DISTINCT CASE 
            WHEN fod.delivered_date_pt >= '2025-08-07' AND fod.delivered_date_pt <= '2025-09-03'
            THEN fod.order_delivery_id 
        END) AS orders_28d_pre,
        COALESCE(SUM(CASE 
            WHEN fod.delivered_date_pt >= '2025-08-07' AND fod.delivered_date_pt <= '2025-09-03'
            THEN gtv.gtv_amt_usd 
        END), 0) AS gtv_28d_pre,
        
        -- 91-day pre-event metrics
        COUNT(DISTINCT CASE 
            WHEN fod.delivered_date_pt >= '2025-06-05' AND fod.delivered_date_pt <= '2025-09-03'
            THEN fod.order_delivery_id 
        END) AS orders_91d_pre,
        COALESCE(SUM(CASE 
            WHEN fod.delivered_date_pt >= '2025-06-05' AND fod.delivered_date_pt <= '2025-09-03'
            THEN gtv.gtv_amt_usd 
        END), 0) AS gtv_91d_pre
        
    FROM instadata.dwh.fact_order_delivery fod
    INNER JOIN instadata.dwh.vw_delivery_gtv gtv
        ON fod.order_delivery_id = gtv.order_delivery_id
    WHERE fod.user_id NOT IN (SELECT user_id FROM treatment_users)
      AND fod.delivery_state = 'delivered'
      AND fod.delivery_finalized_ind = 'Y'
      AND fod.deleted_ind = 'N'
      AND fod.delivered_date_pt >= '2025-06-05'
      AND fod.delivered_date_pt <= '2025-09-03'
    GROUP BY fod.user_id, fod.zone_id
)

SELECT 
    co.user_id,
    du.activation_date_pt,
    DATEDIFF('day', du.activation_date_pt, '2025-09-04') AS account_age_days,
    COALESCE(co.zone_id, du.activation_zone_id) AS zone_id,
    co.is_express,
    co.orders_28d_pre,
    co.gtv_28d_pre,
    co.orders_91d_pre,
    co.gtv_91d_pre
FROM candidate_orders co
LEFT JOIN instadata.dwh.dim_user du ON co.user_id = du.user_id
WHERE co.gtv_91d_pre > 0;  -- Only users with pre-event activity


-- ============================================================
-- STEP 3: Nearest Neighbor Matching
-- Match each treatment user to closest control user
-- Exact match on: zone_id, is_express
-- Distance match on: GTV, orders, account age (normalized)
-- ============================================================
CREATE OR REPLACE TABLE sandbox_db.sarthakchudgar.thirdeyeblind_control_group AS
WITH treatment AS (
    SELECT * FROM sandbox_db.sarthakchudgar.thirdeyeblind_treatment_features
),

candidates AS (
    SELECT * FROM sandbox_db.sarthakchudgar.thirdeyeblind_candidate_pool
),

-- Calculate normalization stats from treatment group
norm_stats AS (
    SELECT 
        STDDEV(gtv_28d_pre) AS std_gtv_28d,
        STDDEV(gtv_91d_pre) AS std_gtv_91d,
        STDDEV(orders_28d_pre) AS std_orders_28d,
        STDDEV(orders_91d_pre) AS std_orders_91d,
        STDDEV(account_age_days) AS std_account_age
    FROM treatment
),

-- Find best match for each treatment user
matched AS (
    SELECT 
        t.user_id AS treatment_user_id,
        c.user_id AS control_user_id,
        c.zone_id,
        c.is_express,
        c.orders_28d_pre,
        c.gtv_28d_pre,
        c.orders_91d_pre,
        c.gtv_91d_pre,
        c.account_age_days,
        -- Calculate Euclidean distance on normalized features
        SQRT(
            POW((t.gtv_28d_pre - c.gtv_28d_pre) / NULLIF(ns.std_gtv_28d, 0), 2) +
            POW((t.gtv_91d_pre - c.gtv_91d_pre) / NULLIF(ns.std_gtv_91d, 0), 2) +
            POW((t.orders_28d_pre - c.orders_28d_pre) / NULLIF(ns.std_orders_28d, 0), 2) +
            POW((t.orders_91d_pre - c.orders_91d_pre) / NULLIF(ns.std_orders_91d, 0), 2) +
            POW((t.account_age_days - c.account_age_days) / NULLIF(ns.std_account_age, 0), 2)
        ) AS distance,
        ROW_NUMBER() OVER (
            PARTITION BY t.user_id 
            ORDER BY SQRT(
                POW((t.gtv_28d_pre - c.gtv_28d_pre) / NULLIF(ns.std_gtv_28d, 0), 2) +
                POW((t.gtv_91d_pre - c.gtv_91d_pre) / NULLIF(ns.std_gtv_91d, 0), 2) +
                POW((t.orders_28d_pre - c.orders_28d_pre) / NULLIF(ns.std_orders_28d, 0), 2) +
                POW((t.orders_91d_pre - c.orders_91d_pre) / NULLIF(ns.std_orders_91d, 0), 2) +
                POW((t.account_age_days - c.account_age_days) / NULLIF(ns.std_account_age, 0), 2)
            )
        ) AS match_rank
    FROM treatment t
    CROSS JOIN norm_stats ns
    INNER JOIN candidates c 
        ON t.zone_id = c.zone_id  -- Exact match on zone
        AND t.is_express = c.is_express  -- Exact match on IC+ status
)

SELECT 
    control_user_id AS user_id,
    treatment_user_id,
    zone_id,
    is_express,
    orders_28d_pre,
    gtv_28d_pre,
    orders_91d_pre,
    gtv_91d_pre,
    account_age_days,
    distance AS match_distance,
    'control' AS group_type
FROM matched
WHERE match_rank = 1;


-- ============================================================
-- STEP 4: Calculate GTV Pre/Post for Control Group
-- ============================================================
CREATE OR REPLACE TABLE sandbox_db.sarthakchudgar.thirdeyeblind_control_gtv_analysis AS
WITH control_users AS (
    SELECT user_id FROM sandbox_db.sarthakchudgar.thirdeyeblind_control_group
),

orders_with_gtv AS (
    SELECT 
        fod.user_id,
        fod.order_delivery_id,
        fod.delivered_date_pt,
        gtv.gtv_amt_usd
    FROM instadata.dwh.fact_order_delivery fod
    INNER JOIN instadata.dwh.vw_delivery_gtv gtv
        ON fod.order_delivery_id = gtv.order_delivery_id
    WHERE fod.user_id IN (SELECT user_id FROM control_users)
      AND fod.delivery_state = 'delivered'
      AND fod.delivery_finalized_ind = 'Y'
      AND fod.deleted_ind = 'N'
      AND fod.delivered_date_pt >= '2025-06-05'
      AND fod.delivered_date_pt <= '2025-12-04'
)

SELECT 
    cg.user_id,
    cg.treatment_user_id,
    cg.match_distance,
    
    -- 28-day pre-event
    COALESCE(SUM(CASE 
        WHEN o.delivered_date_pt >= '2025-08-07' AND o.delivered_date_pt <= '2025-09-03'
        THEN o.gtv_amt_usd 
    END), 0) AS gtv_28d_pre,
    
    -- 28-day post-event
    COALESCE(SUM(CASE 
        WHEN o.delivered_date_pt >= '2025-09-05' AND o.delivered_date_pt <= '2025-10-02'
        THEN o.gtv_amt_usd 
    END), 0) AS gtv_28d_post,
    
    -- 91-day pre-event
    COALESCE(SUM(CASE 
        WHEN o.delivered_date_pt >= '2025-06-05' AND o.delivered_date_pt <= '2025-09-03'
        THEN o.gtv_amt_usd 
    END), 0) AS gtv_91d_pre,
    
    -- 91-day post-event
    COALESCE(SUM(CASE 
        WHEN o.delivered_date_pt >= '2025-09-05' AND o.delivered_date_pt <= '2025-12-04'
        THEN o.gtv_amt_usd 
    END), 0) AS gtv_91d_post,
    
    -- Order counts
    COUNT(DISTINCT CASE 
        WHEN o.delivered_date_pt >= '2025-08-07' AND o.delivered_date_pt <= '2025-09-03'
        THEN o.order_delivery_id 
    END) AS orders_28d_pre,
    
    COUNT(DISTINCT CASE 
        WHEN o.delivered_date_pt >= '2025-09-05' AND o.delivered_date_pt <= '2025-10-02'
        THEN o.order_delivery_id 
    END) AS orders_28d_post,
    
    COUNT(DISTINCT CASE 
        WHEN o.delivered_date_pt >= '2025-06-05' AND o.delivered_date_pt <= '2025-09-03'
        THEN o.order_delivery_id 
    END) AS orders_91d_pre,
    
    COUNT(DISTINCT CASE 
        WHEN o.delivered_date_pt >= '2025-09-05' AND o.delivered_date_pt <= '2025-12-04'
        THEN o.order_delivery_id 
    END) AS orders_91d_post

FROM sandbox_db.sarthakchudgar.thirdeyeblind_control_group cg
LEFT JOIN orders_with_gtv o ON cg.user_id = o.user_id
GROUP BY cg.user_id, cg.treatment_user_id, cg.match_distance;


-- ============================================================
-- STEP 5: Compare Treatment vs Control
-- ============================================================

-- Summary comparison
SELECT 
    'Treatment (Event Attendees)' AS group_name,
    COUNT(*) AS users,
    ROUND(SUM(gtv_28d_pre), 2) AS total_gtv_28d_pre,
    ROUND(SUM(gtv_28d_post), 2) AS total_gtv_28d_post,
    ROUND(SUM(gtv_28d_post) - SUM(gtv_28d_pre), 2) AS gtv_28d_change,
    ROUND((SUM(gtv_28d_post) - SUM(gtv_28d_pre)) / NULLIF(SUM(gtv_28d_pre), 0) * 100, 2) AS gtv_28d_pct_change,
    ROUND(SUM(gtv_91d_pre), 2) AS total_gtv_91d_pre,
    ROUND(SUM(gtv_91d_post), 2) AS total_gtv_91d_post,
    ROUND(SUM(gtv_91d_post) - SUM(gtv_91d_pre), 2) AS gtv_91d_change,
    ROUND((SUM(gtv_91d_post) - SUM(gtv_91d_pre)) / NULLIF(SUM(gtv_91d_pre), 0) * 100, 2) AS gtv_91d_pct_change
FROM sandbox_db.sarthakchudgar.thirdeyeblind_gtv_analysis

UNION ALL

SELECT 
    'Control (Matched Non-Attendees)' AS group_name,
    COUNT(*) AS users,
    ROUND(SUM(gtv_28d_pre), 2) AS total_gtv_28d_pre,
    ROUND(SUM(gtv_28d_post), 2) AS total_gtv_28d_post,
    ROUND(SUM(gtv_28d_post) - SUM(gtv_28d_pre), 2) AS gtv_28d_change,
    ROUND((SUM(gtv_28d_post) - SUM(gtv_28d_pre)) / NULLIF(SUM(gtv_28d_pre), 0) * 100, 2) AS gtv_28d_pct_change,
    ROUND(SUM(gtv_91d_pre), 2) AS total_gtv_91d_pre,
    ROUND(SUM(gtv_91d_post), 2) AS total_gtv_91d_post,
    ROUND(SUM(gtv_91d_post) - SUM(gtv_91d_pre), 2) AS gtv_91d_change,
    ROUND((SUM(gtv_91d_post) - SUM(gtv_91d_pre)) / NULLIF(SUM(gtv_91d_pre), 0) * 100, 2) AS gtv_91d_pct_change
FROM sandbox_db.sarthakchudgar.thirdeyeblind_control_gtv_analysis;

