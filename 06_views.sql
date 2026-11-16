-- ============================================================
-- Views: availability, guest billing, restricted front-desk view
-- ============================================================
USE hotel_db;

-- 7.1 Helper view: every night of every active reservation, with that night's rate
CREATE OR REPLACE VIEW v_room_nights AS
SELECT res.reservation_id, res.guest_id, res.room_id, rm.type_id,
       c.cal_date AS stay_date, rr.season, rr.nightly_rate
FROM reservations res
JOIN rooms rm         ON rm.room_id = res.room_id
JOIN calendar_dates c ON c.cal_date >= res.check_in_date
                     AND c.cal_date <  res.check_out_date
JOIN room_rates rr    ON rr.type_id = rm.type_id
                     AND c.cal_date BETWEEN rr.valid_from AND rr.valid_to
WHERE res.status <> 'Cancelled';

-- Room calendar: one row per room per date, Available or Occupied
CREATE OR REPLACE VIEW v_room_availability AS
SELECT r.room_id, r.room_number, rt.type_name, c.cal_date AS stay_date,
       CASE WHEN EXISTS (
              SELECT 1 FROM reservations x
              WHERE x.room_id = r.room_id AND x.status <> 'Cancelled'
                AND c.cal_date >= x.check_in_date
                AND c.cal_date <  x.check_out_date)
            THEN 'Occupied' ELSE 'Available' END AS availability
FROM rooms r
JOIN room_types rt ON rt.type_id = r.type_id
CROSS JOIN calendar_dates c
WHERE r.is_active = TRUE;

-- Day-by-day grid for 24-27 Dec (A = available, O = occupied)
SELECT room_number, type_name,
       MAX(CASE WHEN stay_date = '2026-12-24' THEN LEFT(availability,1) END) AS d24,
       MAX(CASE WHEN stay_date = '2026-12-25' THEN LEFT(availability,1) END) AS d25,
       MAX(CASE WHEN stay_date = '2026-12-26' THEN LEFT(availability,1) END) AS d26,
       MAX(CASE WHEN stay_date = '2026-12-27' THEN LEFT(availability,1) END) AS d27
FROM v_room_availability
WHERE stay_date BETWEEN '2026-12-24' AND '2026-12-27'
GROUP BY room_number, type_name
ORDER BY room_number;

-- Rooms free on ALL nights from 24 to 27 Dec (same answer as query 5.1)
SELECT room_number, type_name
FROM v_room_availability
WHERE stay_date BETWEEN '2026-12-24' AND '2026-12-27'
GROUP BY room_number, type_name
HAVING SUM(availability = 'Occupied') = 0
ORDER BY room_number;

-- 7.2 Guest billing summary.
-- Room and extra charges are summed in separate derived tables first;
-- joining extra_charges to the nightly rows directly would repeat each
-- extra charge once per night and inflate the total.
CREATE OR REPLACE VIEW v_guest_billing AS
SELECT res.reservation_id, g.guest_id,
       CONCAT(g.first_name, ' ', g.last_name) AS guest_name,
       rm.room_number, res.check_in_date, res.check_out_date,
       DATEDIFF(res.check_out_date, res.check_in_date)  AS nights_stayed,
       COALESCE(rc.room_charges, 0)                     AS room_charges,
       COALESCE(ec.extra_charges, 0)                    AS extra_charges,
       COALESCE(rc.room_charges, 0) + COALESCE(ec.extra_charges, 0) AS total_bill
FROM reservations res
JOIN guests g ON g.guest_id = res.guest_id
JOIN rooms rm ON rm.room_id = res.room_id
LEFT JOIN (SELECT reservation_id, SUM(nightly_rate) AS room_charges
           FROM v_room_nights GROUP BY reservation_id) rc
       ON rc.reservation_id = res.reservation_id
LEFT JOIN (SELECT reservation_id, SUM(amount) AS extra_charges
           FROM extra_charges GROUP BY reservation_id) ec
       ON ec.reservation_id = res.reservation_id
WHERE res.status <> 'Cancelled';

-- One bill
SELECT * FROM v_guest_billing WHERE reservation_id = 531;

-- Spend summary per guest
SELECT guest_id, guest_name, COUNT(*) AS stays,
       SUM(nights_stayed) AS nights, SUM(total_bill) AS total_spend
FROM v_guest_billing
WHERE guest_id IN (5, 7, 10)
GROUP BY guest_id, guest_name
ORDER BY total_spend DESC;

-- 7.3 Restricted front-desk view with WITH CHECK OPTION.
-- Only current/upcoming bookings, no prices, no history, no cancelled rows.
CREATE OR REPLACE VIEW v_frontdesk_reservations AS
SELECT reservation_id, guest_id, room_id, check_in_date, check_out_date, num_guests, status
FROM reservations
WHERE status IN ('Booked', 'Checked-In')
WITH CHECK OPTION;

-- !! Change this password before using it anywhere real !!
CREATE USER IF NOT EXISTS 'frontdesk'@'localhost' IDENTIFIED BY 'ChangeMe_123';
GRANT SELECT, INSERT, UPDATE ON hotel_db.v_frontdesk_reservations TO 'frontdesk'@'localhost';
SHOW GRANTS FOR 'frontdesk'@'localhost';

-- ---- Run the following while logged in as `frontdesk` ----
--   mysql -u frontdesk -p hotel_db
--
-- SELECT * FROM reservations;                      -- ERROR 1142: denied on base table
-- SELECT status, COUNT(*) FROM v_frontdesk_reservations GROUP BY status;
--
-- INSERT INTO v_frontdesk_reservations (guest_id, room_id, check_in_date, check_out_date, num_guests, status)
-- VALUES (3, 4, '2027-03-01', '2027-03-03', 2, 'Booked');       -- OK
-- INSERT INTO v_frontdesk_reservations (guest_id, room_id, check_in_date, check_out_date, num_guests, status)
-- VALUES (3, 4, '2027-03-05', '2027-03-07', 2, 'Cancelled');    -- ERROR 1369 (CHECK OPTION failed)
--
-- UPDATE v_frontdesk_reservations SET status = 'Checked-In'
-- WHERE reservation_id = <new id>;                              -- OK
-- UPDATE v_frontdesk_reservations SET status = 'Cancelled'
-- WHERE reservation_id = <new id>;                              -- ERROR 1369
