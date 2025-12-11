-- ============================================================
-- Activation Analysis for Third Eye Blind Event
-- Compares activation rates between event attendees and control group
-- for users who had NO pre-event Instacart orders
-- 
-- CONTROL GROUP MATCHING: Matched on lifetime activity
-- - NEW users: Never placed an Instacart order before
-- - DORMANT users: Ordered before but not in pre-event window
-- ============================================================

-- Event Date: September 4, 2025
-- 91-day pre: Jun 5 - Sep 3, 2025  |  91-day post: Sep 5 - Dec 4, 2025
-- 28-day pre: Aug 7 - Sep 3, 2025  |  28-day post: Sep 5 - Oct 2, 2025


-- ============================================================
-- 91-DAY ANALYSIS
-- ============================================================

-- Treatment group breakdown (91-day):
--   - 320 NEW users (never ordered before)
--   - 285 DORMANT users (ordered before Jun 5, 2025 but not since)

-- COMPARISON: 91-Day Activation by User Type
WITH treatment_inactive_91d AS (
    SELECT user_id, gtv_91d_post, orders_91d_post
    FROM sandbox_db.sarthakchudgar.thirdeyeblind_gtv_analysis
    WHERE gtv_91d_pre = 0
),
lifetime_orders_91d AS (
    SELECT DISTINCT fod.user_id 
    FROM instadata.dwh.fact_order_delivery fod
    WHERE fod.delivered_date_pt < '2025-06-05'
      AND fod.delivery_state = 'delivered' 
      AND fod.delivery_finalized_ind = 'Y' 
      AND fod.deleted_ind = 'N'
)
SELECT 
    'Treatment' AS group_name,
    CASE WHEN lo.user_id IS NOT NULL THEN 'dormant' ELSE 'new' END AS user_type,
    COUNT(*) AS total_users,
    COUNT(CASE WHEN ti.orders_91d_post > 0 THEN 1 END) AS activated,
    ROUND(COUNT(CASE WHEN ti.orders_91d_post > 0 THEN 1 END) * 100.0 / COUNT(*), 1) AS activation_rate_pct,
    ROUND(SUM(ti.gtv_91d_post), 2) AS total_gtv
FROM treatment_inactive_91d ti
LEFT JOIN lifetime_orders_91d lo ON ti.user_id = lo.user_id
GROUP BY 1, 2

UNION ALL

SELECT 
    'Control' AS group_name,
    user_type,
    COUNT(*) AS total_users,
    COUNT(CASE WHEN orders_91d_post > 0 THEN 1 END) AS activated,
    ROUND(COUNT(CASE WHEN orders_91d_post > 0 THEN 1 END) * 100.0 / COUNT(*), 1) AS activation_rate_pct,
    ROUND(SUM(gtv_91d_post), 2) AS total_gtv
FROM sandbox_db.sarthakchudgar.thirdeyeblind_control_inactive_91d_matched
GROUP BY 1, 2
ORDER BY user_type, group_name;


-- SUMMARY: Overall 91-Day Activation Comparison
SELECT 
    'Treatment (Event Attendees)' AS group_name,
    COUNT(*) AS total_inactive,
    COUNT(CASE WHEN orders_91d_post > 0 THEN 1 END) AS activated,
    ROUND(COUNT(CASE WHEN orders_91d_post > 0 THEN 1 END) * 100.0 / COUNT(*), 1) AS activation_rate_pct,
    ROUND(SUM(gtv_91d_post), 2) AS total_gtv
FROM sandbox_db.sarthakchudgar.thirdeyeblind_gtv_analysis
WHERE gtv_91d_pre = 0

UNION ALL

SELECT 
    'Control (Matched Non-Attendees)' AS group_name,
    COUNT(*) AS total_inactive,
    COUNT(CASE WHEN orders_91d_post > 0 THEN 1 END) AS activated,
    ROUND(COUNT(CASE WHEN orders_91d_post > 0 THEN 1 END) * 100.0 / COUNT(*), 1) AS activation_rate_pct,
    ROUND(SUM(gtv_91d_post), 2) AS total_gtv
FROM sandbox_db.sarthakchudgar.thirdeyeblind_control_inactive_91d_matched;


-- ============================================================
-- 28-DAY ANALYSIS
-- ============================================================

-- Treatment group breakdown (28-day):
--   - 320 NEW users (never ordered before)
--   - 337 DORMANT users (ordered before Aug 7, 2025 but not since)

-- COMPARISON: 28-Day Activation by User Type
WITH treatment_inactive_28d AS (
    SELECT user_id, gtv_28d_post, orders_28d_post
    FROM sandbox_db.sarthakchudgar.thirdeyeblind_gtv_analysis
    WHERE gtv_28d_pre = 0
),
lifetime_orders_28d AS (
    SELECT DISTINCT fod.user_id 
    FROM instadata.dwh.fact_order_delivery fod
    WHERE fod.delivered_date_pt < '2025-08-07'
      AND fod.delivery_state = 'delivered' 
      AND fod.delivery_finalized_ind = 'Y' 
      AND fod.deleted_ind = 'N'
)
SELECT 
    'Treatment' AS group_name,
    CASE WHEN lo.user_id IS NOT NULL THEN 'dormant' ELSE 'new' END AS user_type,
    COUNT(*) AS total_users,
    COUNT(CASE WHEN ti.orders_28d_post > 0 THEN 1 END) AS activated,
    ROUND(COUNT(CASE WHEN ti.orders_28d_post > 0 THEN 1 END) * 100.0 / COUNT(*), 1) AS activation_rate_pct,
    ROUND(SUM(ti.gtv_28d_post), 2) AS total_gtv
FROM treatment_inactive_28d ti
LEFT JOIN lifetime_orders_28d lo ON ti.user_id = lo.user_id
GROUP BY 1, 2

UNION ALL

SELECT 
    'Control' AS group_name,
    user_type,
    COUNT(*) AS total_users,
    COUNT(CASE WHEN orders_28d_post > 0 THEN 1 END) AS activated,
    ROUND(COUNT(CASE WHEN orders_28d_post > 0 THEN 1 END) * 100.0 / COUNT(*), 1) AS activation_rate_pct,
    ROUND(SUM(gtv_28d_post), 2) AS total_gtv
FROM sandbox_db.sarthakchudgar.thirdeyeblind_control_inactive_28d_matched
GROUP BY 1, 2
ORDER BY user_type, group_name;


-- SUMMARY: Overall 28-Day Activation Comparison
SELECT 
    'Treatment (Event Attendees)' AS group_name,
    COUNT(*) AS total_inactive,
    COUNT(CASE WHEN orders_28d_post > 0 THEN 1 END) AS activated,
    ROUND(COUNT(CASE WHEN orders_28d_post > 0 THEN 1 END) * 100.0 / COUNT(*), 1) AS activation_rate_pct,
    ROUND(SUM(gtv_28d_post), 2) AS total_gtv
FROM sandbox_db.sarthakchudgar.thirdeyeblind_gtv_analysis
WHERE gtv_28d_pre = 0

UNION ALL

SELECT 
    'Control (Matched Non-Attendees)' AS group_name,
    COUNT(*) AS total_inactive,
    COUNT(CASE WHEN orders_28d_post > 0 THEN 1 END) AS activated,
    ROUND(COUNT(CASE WHEN orders_28d_post > 0 THEN 1 END) * 100.0 / COUNT(*), 1) AS activation_rate_pct,
    ROUND(SUM(gtv_28d_post), 2) AS total_gtv
FROM sandbox_db.sarthakchudgar.thirdeyeblind_control_inactive_28d_matched;


-- ============================================================
-- RESULTS SUMMARY (as of analysis date)
-- ============================================================
-- 
-- 91-DAY ACTIVATION COMPARISON (Matched on Lifetime Activity)
-- ============================================================
-- 
-- OVERALL:
--   Treatment: 605 users, 65 activated (10.7%)
--   Control:   605 users, 13 activated (2.1%)
--   LIFT: +8.6 percentage points
-- 
-- BY USER TYPE:
--   NEW (never ordered):
--     Treatment: 320 users, 20 activated (6.2%)
--     Control:   320 users, 0 activated (0.0%)
--     LIFT: +6.2 pp
-- 
--   DORMANT (ordered before, lapsed):
--     Treatment: 285 users, 45 activated (15.8%)
--     Control:   285 users, 13 activated (4.6%)
--     LIFT: +11.2 pp
-- 
-- 
-- 28-DAY ACTIVATION COMPARISON (Matched on Lifetime Activity)
-- ============================================================
-- 
-- OVERALL:
--   Treatment: 657 users, 53 activated (8.1%)
--   Control:   657 users, 11 activated (1.7%)
--   LIFT: +6.4 percentage points
-- 
-- BY USER TYPE:
--   NEW (never ordered):
--     Treatment: 320 users, 13 activated (4.1%)
--     Control:   320 users, 0 activated (0.0%)
--     LIFT: +4.1 pp
-- 
--   DORMANT (ordered before, lapsed):
--     Treatment: 337 users, 40 activated (11.9%)
--     Control:   337 users, 11 activated (3.3%)
--     LIFT: +8.6 pp
-- 
-- 
-- KEY INSIGHTS:
-- =============
-- 1. Event drove first-ever Instacart orders for users who had NEVER ordered:
--    - 91-day: 20 new customers (vs 0 in control)
--    - 28-day: 13 new customers (vs 0 in control)
-- 
-- 2. Dormant users reactivated at ~3-4x the rate of control group
-- 
-- 3. Overall activation lift: +8.6pp (91-day) and +6.4pp (28-day)


-- ============================================================
-- TABLES CREATED
-- ============================================================
-- sandbox_db.sarthakchudgar.thirdeyeblind_control_inactive_91d_matched
--   - 320 new + 285 dormant users (matched to 91-day treatment)
-- 
-- sandbox_db.sarthakchudgar.thirdeyeblind_control_inactive_28d_matched
--   - 320 new + 337 dormant users (matched to 28-day treatment)
