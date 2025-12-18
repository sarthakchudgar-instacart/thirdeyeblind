-- ============================================================
-- IC+ Membership Analysis for Third Eye Blind Event Attendees
-- Checks IC+ status at 3 points in time:
--   1. 3 months before concert (June 4, 2025)
--   2. Day of concert (September 4, 2025)
--   3. 3 months after concert (December 4, 2025)
-- ============================================================

-- Key dates
-- Concert: September 4, 2025
-- 3 months before: June 4, 2025
-- 3 months after: December 4, 2025


-- ============================================================
-- IC+ STATUS FOR ALL 760 MATCHED USERS
-- ============================================================
WITH event_attendees AS (
    SELECT DISTINCT user_id
    FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist_with_userid
    WHERE user_id IS NOT NULL
),

-- Check if user had active IC+ subscription on each date
icplus_status AS (
    SELECT
        ea.user_id,
        
        -- 3 months BEFORE concert (June 4, 2025)
        MAX(CASE 
            WHEN ds.subscription_start_date_time_pt <= '2025-06-04'
             AND (ds.subscription_end_date_time_pt >= '2025-06-04' OR ds.subscription_end_date_time_pt IS NULL)
            THEN 1 ELSE 0 
        END) AS icplus_3m_before,
        
        -- Day of concert (September 4, 2025)
        MAX(CASE 
            WHEN ds.subscription_start_date_time_pt <= '2025-09-04'
             AND (ds.subscription_end_date_time_pt >= '2025-09-04' OR ds.subscription_end_date_time_pt IS NULL)
            THEN 1 ELSE 0 
        END) AS icplus_concert_day,
        
        -- 3 months AFTER concert (December 4, 2025)
        MAX(CASE 
            WHEN ds.subscription_start_date_time_pt <= '2025-12-04'
             AND (ds.subscription_end_date_time_pt >= '2025-12-04' OR ds.subscription_end_date_time_pt IS NULL)
            THEN 1 ELSE 0 
        END) AS icplus_3m_after
        
    FROM event_attendees ea
    LEFT JOIN instadata.dwh.dim_subscription ds
        ON ea.user_id = ds.user_id
    GROUP BY ea.user_id
)

SELECT
    COUNT(*) AS total_users,
    SUM(icplus_3m_before) AS icplus_3m_before,
    SUM(icplus_concert_day) AS icplus_concert_day,
    SUM(icplus_3m_after) AS icplus_3m_after,
    ROUND(SUM(icplus_3m_before) * 100.0 / COUNT(*), 1) AS pct_3m_before,
    ROUND(SUM(icplus_concert_day) * 100.0 / COUNT(*), 1) AS pct_concert_day,
    ROUND(SUM(icplus_3m_after) * 100.0 / COUNT(*), 1) AS pct_3m_after
FROM icplus_status;


-- ============================================================
-- DETAILED BREAKDOWN: IC+ Transitions
-- Shows how membership changed across the 3 time periods
-- ============================================================
WITH event_attendees AS (
    SELECT DISTINCT user_id
    FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist_with_userid
    WHERE user_id IS NOT NULL
),

icplus_status AS (
    SELECT
        ea.user_id,
        
        MAX(CASE 
            WHEN ds.subscription_start_date_time_pt <= '2025-06-04'
             AND (ds.subscription_end_date_time_pt >= '2025-06-04' OR ds.subscription_end_date_time_pt IS NULL)
            THEN 1 ELSE 0 
        END) AS icplus_3m_before,
        
        MAX(CASE 
            WHEN ds.subscription_start_date_time_pt <= '2025-09-04'
             AND (ds.subscription_end_date_time_pt >= '2025-09-04' OR ds.subscription_end_date_time_pt IS NULL)
            THEN 1 ELSE 0 
        END) AS icplus_concert_day,
        
        MAX(CASE 
            WHEN ds.subscription_start_date_time_pt <= '2025-12-04'
             AND (ds.subscription_end_date_time_pt >= '2025-12-04' OR ds.subscription_end_date_time_pt IS NULL)
            THEN 1 ELSE 0 
        END) AS icplus_3m_after
        
    FROM event_attendees ea
    LEFT JOIN instadata.dwh.dim_subscription ds
        ON ea.user_id = ds.user_id
    GROUP BY ea.user_id
)

SELECT
    CASE icplus_3m_before WHEN 1 THEN 'IC+' ELSE 'Non-IC+' END AS status_3m_before,
    CASE icplus_concert_day WHEN 1 THEN 'IC+' ELSE 'Non-IC+' END AS status_concert_day,
    CASE icplus_3m_after WHEN 1 THEN 'IC+' ELSE 'Non-IC+' END AS status_3m_after,
    COUNT(*) AS user_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM icplus_status
GROUP BY 1, 2, 3
ORDER BY user_count DESC;


-- ============================================================
-- NEW IC+ SIGNUPS: Users who became IC+ after the concert
-- (Not IC+ on concert day, but IC+ 3 months after)
-- ============================================================
WITH event_attendees AS (
    SELECT DISTINCT user_id
    FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist_with_userid
    WHERE user_id IS NOT NULL
),

icplus_status AS (
    SELECT
        ea.user_id,
        
        MAX(CASE 
            WHEN ds.subscription_start_date_time_pt <= '2025-09-04'
             AND (ds.subscription_end_date_time_pt >= '2025-09-04' OR ds.subscription_end_date_time_pt IS NULL)
            THEN 1 ELSE 0 
        END) AS icplus_concert_day,
        
        MAX(CASE 
            WHEN ds.subscription_start_date_time_pt <= '2025-12-04'
             AND (ds.subscription_end_date_time_pt >= '2025-12-04' OR ds.subscription_end_date_time_pt IS NULL)
            THEN 1 ELSE 0 
        END) AS icplus_3m_after
        
    FROM event_attendees ea
    LEFT JOIN instadata.dwh.dim_subscription ds
        ON ea.user_id = ds.user_id
    GROUP BY ea.user_id
)

SELECT
    'New IC+ Signups (post-concert)' AS metric,
    COUNT(*) AS user_count,
    (SELECT COUNT(*) FROM icplus_status WHERE icplus_concert_day = 0) AS non_icplus_on_concert_day,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM icplus_status WHERE icplus_concert_day = 0), 1) AS conversion_rate_pct
FROM icplus_status
WHERE icplus_concert_day = 0 
  AND icplus_3m_after = 1;

