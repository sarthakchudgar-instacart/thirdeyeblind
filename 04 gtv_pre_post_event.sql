-- GTV Pre/Post Event Analysis for Third Eye Blind Concert (Sep 4, 2025)
-- Calculates 28-day and 91-day GTV before and after the event for checked-in guests

-- Date ranges:
-- 28 days pre-event:  Aug 7, 2025 - Sep 3, 2025
-- 28 days post-event: Sep 5, 2025 - Oct 2, 2025
-- 91 days pre-event:  Jun 5, 2025 - Sep 3, 2025
-- 91 days post-event: Sep 5, 2025 - Dec 4, 2025

CREATE OR REPLACE TABLE sandbox_db.sarthakchudgar.thirdeyeblind_gtv_analysis AS
WITH guest_users AS (
    -- Get all checked-in guests with valid user_ids
    SELECT DISTINCT
        user_id,
        first_name,
        last_name,
        email
    FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist_with_userid
    WHERE user_id IS NOT NULL
),

orders_with_gtv AS (
    -- Get all orders with GTV for our users in the relevant time period
    SELECT 
        fod.user_id,
        fod.order_delivery_id,
        fod.delivered_date_pt,
        gtv.gtv_amt_usd
    FROM instadata.dwh.fact_order_delivery fod
    INNER JOIN instadata.dwh.vw_delivery_gtv gtv
        ON fod.order_delivery_id = gtv.order_delivery_id
    WHERE fod.user_id IN (SELECT user_id FROM guest_users)
      AND fod.delivery_state = 'delivered'
      AND fod.delivery_finalized_ind = 'Y'
      AND fod.deleted_ind = 'N'
      AND fod.delivered_date_pt >= '2025-06-05'  -- 91 days before event
      AND fod.delivered_date_pt <= '2025-12-04'  -- 91 days after event
)

SELECT 
    g.user_id,
    g.first_name,
    g.last_name,
    g.email,
    
    -- 28 days pre-event (Aug 7 - Sep 3, 2025)
    COALESCE(SUM(CASE 
        WHEN o.delivered_date_pt >= '2025-08-07' AND o.delivered_date_pt <= '2025-09-03'
        THEN o.gtv_amt_usd 
    END), 0) AS gtv_28d_pre,
    
    -- 28 days post-event (Sep 5 - Oct 2, 2025)
    COALESCE(SUM(CASE 
        WHEN o.delivered_date_pt >= '2025-09-05' AND o.delivered_date_pt <= '2025-10-02'
        THEN o.gtv_amt_usd 
    END), 0) AS gtv_28d_post,
    
    -- 91 days pre-event (Jun 5 - Sep 3, 2025)
    COALESCE(SUM(CASE 
        WHEN o.delivered_date_pt >= '2025-06-05' AND o.delivered_date_pt <= '2025-09-03'
        THEN o.gtv_amt_usd 
    END), 0) AS gtv_91d_pre,
    
    -- 91 days post-event (Sep 5 - Dec 4, 2025)
    COALESCE(SUM(CASE 
        WHEN o.delivered_date_pt >= '2025-09-05' AND o.delivered_date_pt <= '2025-12-04'
        THEN o.gtv_amt_usd 
    END), 0) AS gtv_91d_post,
    
    -- Order counts for context
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

FROM guest_users g
LEFT JOIN orders_with_gtv o ON g.user_id = o.user_id
GROUP BY g.user_id, g.first_name, g.last_name, g.email;


-- Verify: Sample of individual user data
SELECT user_id, first_name, last_name, email,
       gtv_28d_pre, gtv_28d_post, gtv_91d_pre, gtv_91d_post,
       orders_28d_pre, orders_28d_post, orders_91d_pre, orders_91d_post
FROM sandbox_db.sarthakchudgar.thirdeyeblind_gtv_analysis
LIMIT 10;


-- Summary: Aggregate totals across all checked-in guests
SELECT 
    COUNT(*) AS total_matched_guests,
    
    -- 28-day metrics
    SUM(gtv_28d_pre) AS total_gtv_28d_pre,
    SUM(gtv_28d_post) AS total_gtv_28d_post,
    SUM(gtv_28d_post) - SUM(gtv_28d_pre) AS gtv_28d_change,
    ROUND((SUM(gtv_28d_post) - SUM(gtv_28d_pre)) / NULLIF(SUM(gtv_28d_pre), 0) * 100, 2) AS gtv_28d_pct_change,
    
    -- 91-day metrics
    SUM(gtv_91d_pre) AS total_gtv_91d_pre,
    SUM(gtv_91d_post) AS total_gtv_91d_post,
    SUM(gtv_91d_post) - SUM(gtv_91d_pre) AS gtv_91d_change,
    ROUND((SUM(gtv_91d_post) - SUM(gtv_91d_pre)) / NULLIF(SUM(gtv_91d_pre), 0) * 100, 2) AS gtv_91d_pct_change,
    
    -- Order counts
    SUM(orders_28d_pre) AS total_orders_28d_pre,
    SUM(orders_28d_post) AS total_orders_28d_post,
    SUM(orders_91d_pre) AS total_orders_91d_pre,
    SUM(orders_91d_post) AS total_orders_91d_post,
    
    -- Average per user
    ROUND(AVG(gtv_28d_pre), 2) AS avg_gtv_28d_pre_per_user,
    ROUND(AVG(gtv_28d_post), 2) AS avg_gtv_28d_post_per_user,
    ROUND(AVG(gtv_91d_pre), 2) AS avg_gtv_91d_pre_per_user,
    ROUND(AVG(gtv_91d_post), 2) AS avg_gtv_91d_post_per_user
    
FROM sandbox_db.sarthakchudgar.thirdeyeblind_gtv_analysis;

