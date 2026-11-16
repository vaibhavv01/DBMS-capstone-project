-- ============================================================
-- CRUD operations: one guest (Ananya Verma) through her life cycle
-- ============================================================
USE hotel_db;

-- ---------- CREATE ----------
INSERT INTO guests (first_name, last_name, email, phone, city)
VALUES ('Ananya', 'Verma', 'ananya.verma@mail.com', '9876543210', 'Delhi');

-- Book room 2 (102) for 10-14 Feb 2027, only if no active booking overlaps.
-- Two stays overlap when: existing.check_in < new.check_out AND existing.check_out > new.check_in
INSERT INTO reservations (guest_id, room_id, check_in_date, check_out_date, num_guests)
SELECT (SELECT guest_id FROM guests WHERE email = 'ananya.verma@mail.com'),
       2, '2027-02-10', '2027-02-14', 2
FROM DUAL
WHERE NOT EXISTS (
  SELECT 1 FROM reservations r
  WHERE r.room_id = 2 AND r.status <> 'Cancelled'
    AND r.check_in_date  < '2027-02-14'
    AND r.check_out_date > '2027-02-10');

SELECT ROW_COUNT() AS rows_inserted;   -- 0 means the room was not available

SELECT reservation_id, guest_id, room_id, check_in_date, check_out_date, status
FROM reservations ORDER BY reservation_id DESC LIMIT 1;

-- Remember her reservation id for the steps below
SET @rid = (SELECT r.reservation_id FROM reservations r
            JOIN guests g ON g.guest_id = r.guest_id
            WHERE g.email = 'ananya.verma@mail.com'
            ORDER BY r.reservation_id DESC LIMIT 1);

-- Extra charge on her booking
INSERT INTO extra_charges (reservation_id, description, amount, charged_on)
VALUES (@rid, 'Airport pickup', 1800.00, '2027-02-10');

-- ---------- READ ----------
SELECT r.reservation_id,
       CONCAT(g.first_name, ' ', g.last_name) AS guest,
       rm.room_number, rt.type_name,
       r.check_in_date, r.check_out_date, r.status
FROM reservations r
JOIN guests g      ON g.guest_id  = r.guest_id
JOIN rooms rm      ON rm.room_id  = r.room_id
JOIN room_types rt ON rt.type_id  = rm.type_id
WHERE g.email = 'ananya.verma@mail.com';

-- A guest's latest five stays
SELECT reservation_id, room_id, check_in_date, check_out_date, status
FROM reservations WHERE guest_id = 7
ORDER BY check_in_date DESC LIMIT 5;

-- Who is in the hotel right now? ("today" = 2026-11-09)
SELECT rm.room_number, CONCAT(g.first_name,' ',g.last_name) AS guest,
       r.check_in_date, r.check_out_date
FROM reservations r
JOIN guests g ON g.guest_id = r.guest_id
JOIN rooms rm ON rm.room_id = r.room_id
WHERE r.status = 'Checked-In'
ORDER BY rm.room_number;

-- ---------- UPDATE ----------
UPDATE guests
SET phone = '9123456789', city = 'Gurugram'
WHERE email = 'ananya.verma@mail.com';

-- Extend the stay to 16 Feb, only if nobody else holds the room.
-- (MariaDB/MySQL do not allow a subquery on the table being updated,
--  so the check reads a derived copy of the table.)
UPDATE reservations
SET check_out_date = '2027-02-16'
WHERE reservation_id = @rid
  AND NOT EXISTS (
    SELECT 1 FROM (SELECT * FROM reservations) x
    WHERE x.room_id = reservations.room_id
      AND x.reservation_id <> reservations.reservation_id
      AND x.status <> 'Cancelled'
      AND x.check_in_date  < '2027-02-16'
      AND x.check_out_date > reservations.check_in_date);

-- Check-in (a booking that arrives today)
UPDATE reservations SET status = 'Checked-In'
WHERE reservation_id = 577 AND status = 'Booked';

-- Cancel instead of delete (keeps history)
UPDATE reservations SET status = 'Cancelled'
WHERE reservation_id = 578 AND status = 'Booked';

-- ---------- DELETE ----------
-- Hard delete: the extra charge goes with it (ON DELETE CASCADE)
DELETE FROM reservations WHERE reservation_id = @rid;
SELECT COUNT(*) AS leftover_charges FROM extra_charges WHERE reservation_id = @rid;  -- 0

-- A guest with history cannot be deleted (foreign key blocks it) ...
-- DELETE FROM guests WHERE guest_id = 7;     -- ERROR 1451

-- ... a guest with no reservations can
DELETE FROM guests WHERE email = 'ananya.verma@mail.com';
