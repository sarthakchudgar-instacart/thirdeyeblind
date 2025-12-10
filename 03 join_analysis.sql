-- Analysis of different join strategies to maximize user_id matches
-- Run each query to see match rates for different approaches

-- ============================================
-- OPTION 1: Join on EMAIL only (most reliable)
-- ============================================
SELECT 
    'Email Only' AS join_strategy,
    COUNT(*) AS total_guests,
    COUNT(u.id) AS matched,
    COUNT(*) - COUNT(u.id) AS not_matched,
    ROUND(COUNT(u.id) * 100.0 / COUNT(*), 2) AS match_rate_pct
FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist g
LEFT JOIN instadata.eclipse.users u
    ON LOWER(TRIM(g.email)) = LOWER(TRIM(u.email));

-- ============================================
-- OPTION 2: Join on FIRST_NAME + LAST_NAME only
-- ============================================
SELECT 
    'First + Last Name Only' AS join_strategy,
    COUNT(*) AS total_guests,
    COUNT(u.id) AS matched,
    COUNT(*) - COUNT(u.id) AS not_matched,
    ROUND(COUNT(u.id) * 100.0 / COUNT(*), 2) AS match_rate_pct
FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist g
LEFT JOIN instadata.eclipse.users u
    ON LOWER(TRIM(g.first_name)) = LOWER(TRIM(u.first_name))
    AND LOWER(TRIM(g.last_name)) = LOWER(TRIM(u.last_name));

-- ============================================
-- OPTION 3: Join on ALL THREE (current approach)
-- ============================================
SELECT 
    'Email + First + Last Name' AS join_strategy,
    COUNT(*) AS total_guests,
    COUNT(u.id) AS matched,
    COUNT(*) - COUNT(u.id) AS not_matched,
    ROUND(COUNT(u.id) * 100.0 / COUNT(*), 2) AS match_rate_pct
FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist g
LEFT JOIN instadata.eclipse.users u
    ON LOWER(TRIM(g.email)) = LOWER(TRIM(u.email))
    AND LOWER(TRIM(g.first_name)) = LOWER(TRIM(u.first_name))
    AND LOWER(TRIM(g.last_name)) = LOWER(TRIM(u.last_name));

-- ============================================
-- OPTION 4: Join on EMAIL OR (FIRST_NAME + LAST_NAME)
-- Uses COALESCE to prefer email match, fall back to name match
-- ============================================
SELECT 
    'Email OR Name (Cascading)' AS join_strategy,
    COUNT(*) AS total_guests,
    COUNT(user_id) AS matched,
    COUNT(*) - COUNT(user_id) AS not_matched,
    ROUND(COUNT(user_id) * 100.0 / COUNT(*), 2) AS match_rate_pct
FROM (
    SELECT 
        g.*,
        COALESCE(u_email.id, u_name.id) AS user_id
    FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist g
    LEFT JOIN instadata.eclipse.users u_email
        ON LOWER(TRIM(g.email)) = LOWER(TRIM(u_email.email))
    LEFT JOIN instadata.eclipse.users u_name
        ON LOWER(TRIM(g.first_name)) = LOWER(TRIM(u_name.first_name))
        AND LOWER(TRIM(g.last_name)) = LOWER(TRIM(u_name.last_name))
        AND u_email.id IS NULL  -- Only use name match if email didn't match
);

-- ============================================
-- OPTION 5: FULL UNION approach - try email first, then name
-- Best for maximizing matches with clear priority
-- ============================================
SELECT 
    'Union: Email priority, then Name' AS join_strategy,
    COUNT(*) AS total_guests,
    COUNT(user_id) AS matched,
    COUNT(*) - COUNT(user_id) AS not_matched,
    ROUND(COUNT(user_id) * 100.0 / COUNT(*), 2) AS match_rate_pct
FROM (
    SELECT 
        g.first_name,
        g.last_name,
        g.email,
        COALESCE(
            -- Priority 1: Email match
            (SELECT u.id FROM instadata.eclipse.users u 
             WHERE LOWER(TRIM(g.email)) = LOWER(TRIM(u.email)) LIMIT 1),
            -- Priority 2: First + Last name match  
            (SELECT u.id FROM instadata.eclipse.users u 
             WHERE LOWER(TRIM(g.first_name)) = LOWER(TRIM(u.first_name))
             AND LOWER(TRIM(g.last_name)) = LOWER(TRIM(u.last_name)) LIMIT 1)
        ) AS user_id
    FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist g
);

