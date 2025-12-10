-- Create a new table that joins guestlist with eclipse.users to get user_id
-- Only for CHECKED IN guests, matching on EMAIL only (67.80% match rate)

CREATE OR REPLACE TABLE sandbox_db.sarthakchudgar.thirdeyeblind_guestlist_with_userid AS
SELECT 
    u.id AS user_id,
    g.*
FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist g
LEFT JOIN instadata.eclipse.users u
    ON LOWER(TRIM(g.email)) = LOWER(TRIM(u.email))
WHERE LOWER(g.status) = 'checked in';

-- Verify the results
SELECT user_id, first_name, last_name, email, status
FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist_with_userid 
LIMIT 10;

-- Check match statistics
SELECT 
    COUNT(*) AS total_checked_in_guests,
    COUNT(user_id) AS matched_with_userid,
    COUNT(*) - COUNT(user_id) AS not_matched,
    ROUND(COUNT(user_id) * 100.0 / COUNT(*), 2) AS match_rate_pct
FROM sandbox_db.sarthakchudgar.thirdeyeblind_guestlist_with_userid;
