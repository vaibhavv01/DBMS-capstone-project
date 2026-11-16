-- ============================================================
-- Window functions: RANK, running total, LAG, NTILE
-- (needs the views from 06_views.sql)
-- ============================================================
USE hotel_db;

-- 8.1 Rank room types by revenue within each month: RANK()
WITH monthly AS (
  SELECT DATE_FORMAT(n.stay_date, '%Y-%m') AS month,
         rt.type_name,
         SUM(n.nightly_rate) AS revenue
  FROM v_room_nights n
  JOIN room_types rt ON rt.type_id = n.type_id
  GROUP BY month, rt.type_name
)
SELECT month, type_name, revenue,
       RANK() OVER (PARTITION BY month ORDER BY revenue DESC) AS revenue_rank
FROM monthly
WHERE month BETWEEN '2026-09' AND '2026-12'
ORDER BY month, revenue_rank;

-- 8.2 Monthly and cumulative room revenue for 2026
WITH monthly AS (
  SELECT DATE_FORMAT(stay_date, '%Y-%m') AS month, SUM(nightly_rate) AS revenue
  FROM v_room_nights
  WHERE stay_date BETWEEN '2026-01-01' AND '2026-12-31'
  GROUP BY month
)
SELECT month, revenue,
       SUM(revenue) OVER (ORDER BY month) AS cumulative_revenue
FROM monthly
ORDER BY month;

-- 8.3 Gap between a guest's consecutive stays: LAG()
WITH stays AS (
  SELECT guest_id, check_in_date, check_out_date,
         LAG(check_out_date) OVER (PARTITION BY guest_id ORDER BY check_in_date) AS prev_checkout
  FROM reservations
  WHERE status <> 'Cancelled'
)
SELECT guest_id, check_in_date, check_out_date, prev_checkout,
       DATEDIFF(check_in_date, prev_checkout) AS gap_days
FROM stays
WHERE guest_id = 7
ORDER BY check_in_date;

-- Summary for every guest: the five who return the quickest
WITH stays AS (
  SELECT guest_id, check_in_date,
         LAG(check_out_date) OVER (PARTITION BY guest_id ORDER BY check_in_date) AS prev_checkout
  FROM reservations
  WHERE status <> 'Cancelled'
)
SELECT s.guest_id, CONCAT(g.first_name, ' ', g.last_name) AS guest,
       COUNT(s.prev_checkout)                         AS repeat_visits,
       ROUND(AVG(DATEDIFF(s.check_in_date, s.prev_checkout)), 1) AS avg_gap_days,
       MAX(DATEDIFF(s.check_in_date, s.prev_checkout))           AS longest_gap_days
FROM stays s JOIN guests g ON g.guest_id = s.guest_id
WHERE s.prev_checkout IS NOT NULL
GROUP BY s.guest_id, guest
ORDER BY avg_gap_days
LIMIT 5;

-- 8.4 Loyalty tiers by total spend: NTILE(4)
WITH spend AS (
  SELECT guest_id, guest_name, COUNT(*) AS stays, SUM(total_bill) AS total_spend
  FROM v_guest_billing
  GROUP BY guest_id, guest_name
)
SELECT guest_name, stays, total_spend,
       NTILE(4) OVER (ORDER BY total_spend DESC) AS tier_no,
       CASE NTILE(4) OVER (ORDER BY total_spend DESC)
            WHEN 1 THEN 'Platinum' WHEN 2 THEN 'Gold'
            WHEN 3 THEN 'Silver'   ELSE 'Bronze' END AS tier
FROM spend
ORDER BY total_spend DESC;
