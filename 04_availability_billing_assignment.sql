-- ============================================================
-- Availability, total charges and room assignment
-- ============================================================
USE hotel_db;

-- 5.1 Rooms free for 24-28 Dec 2026, with the nightly rate on arrival
SELECT r.room_id, r.room_number, rt.type_name, rt.max_occupancy,
       rr.nightly_rate AS rate_per_night
FROM rooms r
JOIN room_types rt ON rt.type_id = r.type_id
JOIN room_rates rr ON rr.type_id = r.type_id
                  AND '2026-12-24' BETWEEN rr.valid_from AND rr.valid_to
WHERE r.is_active = TRUE
  AND NOT EXISTS (
    SELECT 1 FROM reservations x
    WHERE x.room_id = r.room_id
      AND x.status <> 'Cancelled'
      AND x.check_in_date  < '2026-12-28'
      AND x.check_out_date > '2026-12-24')
ORDER BY r.room_number;

-- The reverse check: reservations that block the other rooms
SELECT x.reservation_id, rm.room_number, x.check_in_date, x.check_out_date, x.status
FROM reservations x JOIN rooms rm ON rm.room_id = x.room_id
WHERE x.status <> 'Cancelled'
  AND x.check_in_date  < '2026-12-28'
  AND x.check_out_date > '2026-12-24'
ORDER BY rm.room_number;

-- 5.2 Season-by-season room charges for one reservation (night by night)
SET @res = 531;

SELECT COALESCE(rr.season, 'TOTAL') AS season,
       COUNT(*)                     AS nights,
       SUM(rr.nightly_rate)         AS room_charges
FROM reservations res
JOIN rooms rm         ON rm.room_id = res.room_id
JOIN calendar_dates c ON c.cal_date >= res.check_in_date
                     AND c.cal_date <  res.check_out_date
JOIN room_rates rr    ON rr.type_id = rm.type_id
                     AND c.cal_date BETWEEN rr.valid_from AND rr.valid_to
WHERE res.reservation_id = @res
GROUP BY rr.season WITH ROLLUP;

-- Total bill = room charges + extra charges
SELECT rc.room_charges,
       COALESCE(ec.extra_total, 0) AS extra_charges,
       rc.room_charges + COALESCE(ec.extra_total, 0) AS total_bill
FROM (SELECT SUM(rr.nightly_rate) AS room_charges
      FROM reservations res
      JOIN rooms rm         ON rm.room_id = res.room_id
      JOIN calendar_dates c ON c.cal_date >= res.check_in_date AND c.cal_date < res.check_out_date
      JOIN room_rates rr    ON rr.type_id = rm.type_id AND c.cal_date BETWEEN rr.valid_from AND rr.valid_to
      WHERE res.reservation_id = @res) rc
CROSS JOIN (SELECT SUM(amount) AS extra_total FROM extra_charges WHERE reservation_id = @res) ec;

-- 5.3 Room assignment board for today (2026-11-09)
SELECT rm.room_number, rt.type_name,
       COALESCE(CONCAT(g.first_name, ' ', g.last_name), '-- vacant --') AS occupant,
       r.check_out_date
FROM rooms rm
JOIN room_types rt ON rt.type_id = rm.type_id
LEFT JOIN reservations r ON r.room_id = rm.room_id
                        AND r.status IN ('Booked','Checked-In')
                        AND '2026-11-09' >= r.check_in_date
                        AND '2026-11-09' <  r.check_out_date
LEFT JOIN guests g ON g.guest_id = r.guest_id
WHERE rm.is_active = TRUE
ORDER BY rm.room_number;

-- Move reservation 587 to another free room of the same type.
-- Step 1: look at the booking
SELECT r.reservation_id, rm.room_number, rm.type_id, r.check_in_date, r.check_out_date
FROM reservations r JOIN rooms rm ON rm.room_id = r.room_id
WHERE r.reservation_id = 587;

-- Step 2: free rooms of the same type for those dates
SELECT rm.room_id, rm.room_number
FROM rooms rm
JOIN reservations cur ON cur.reservation_id = 587
WHERE rm.type_id = (SELECT type_id FROM rooms WHERE room_id = cur.room_id)
  AND rm.room_id <> cur.room_id
  AND rm.is_active = TRUE
  AND NOT EXISTS (
    SELECT 1 FROM reservations x
    WHERE x.room_id = rm.room_id AND x.status <> 'Cancelled'
      AND x.check_in_date  < cur.check_out_date
      AND x.check_out_date > cur.check_in_date);

-- Step 3: move it (overlap check repeated inside the UPDATE so two
-- receptionists cannot grab the same room). Here: move to room_id 1 (101).
UPDATE reservations
SET room_id = 1
WHERE reservation_id = 587
  AND NOT EXISTS (
    SELECT 1 FROM (SELECT * FROM reservations) x
    WHERE x.room_id = 1 AND x.status <> 'Cancelled'
      AND x.check_in_date  < reservations.check_out_date
      AND x.check_out_date > reservations.check_in_date);
