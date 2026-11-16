-- ============================================================
-- Sample (synthetic) data. "Today" in this dataset = 2026-11-09.
-- Reservations are randomly generated, so exact counts and
-- revenue figures will differ a little on every run.
-- ============================================================
USE hotel_db;

-- Room types
INSERT INTO room_types (type_name, max_occupancy, description) VALUES
 ('Standard', 2, 'Queen bed, city view, work desk'),
 ('Deluxe',   3, 'King bed, balcony, sit-out area'),
 ('Family',   5, 'Two bedrooms with a shared living area'),
 ('Suite',    4, 'Top-floor suite with lounge and bathtub');

-- 12 rooms: 101-104 Standard, 201-204 Deluxe, 301-302 Family, 401-402 Suite
INSERT INTO rooms (room_number, type_id, floor_no) VALUES
 ('101',1,1),('102',1,1),('103',1,1),('104',1,1),
 ('201',2,2),('202',2,2),('203',2,2),('204',2,2),
 ('301',3,3),('302',3,3),
 ('401',4,4),('402',4,4);

-- Seasonal rates: peak = regular x 1.30
-- Regular:     Standard 3200, Deluxe 4800, Family 6200, Suite 9800
INSERT INTO room_rates (type_id, season, valid_from, valid_to, nightly_rate)
SELECT t.type_id, s.season, s.valid_from, s.valid_to,
       ROUND(t.base_rate * s.factor, 2)
FROM (SELECT 1 AS type_id, 3200 AS base_rate UNION ALL
      SELECT 2, 4800 UNION ALL SELECT 3, 6200 UNION ALL SELECT 4, 9800) t
CROSS JOIN (
  SELECT 'Regular'       AS season, DATE '2026-01-01' AS valid_from, DATE '2026-03-31' AS valid_to, 1.0 AS factor UNION ALL
  SELECT 'Summer Peak',  '2026-04-01', '2026-06-30', 1.3 UNION ALL
  SELECT 'Regular',      '2026-07-01', '2026-10-14', 1.0 UNION ALL
  SELECT 'Festive Peak', '2026-10-15', '2026-11-15', 1.3 UNION ALL
  SELECT 'Regular',      '2026-11-16', '2026-12-19', 1.0 UNION ALL
  SELECT 'Year-End Peak','2026-12-20', '2027-01-05', 1.3 UNION ALL
  SELECT 'Regular',      '2027-01-06', '2027-12-31', 1.0
) s
ORDER BY t.type_id, s.valid_from;

-- 20 guests
INSERT INTO guests (first_name, last_name, email, phone, city) VALUES
 ('Aarav','Sharma','aarav.sharma@mail.com','9810000001','Delhi'),
 ('Meera','Iyer','meera.iyer@mail.com','9810000002','Chennai'),
 ('Priya','Singh','priya.singh@mail.com','9810000003','Lucknow'),
 ('Rohan','Mehta','rohan.mehta@mail.com','9810000004','Mumbai'),
 ('Vikram','Rathore','vikram.rathore@mail.com','9810000005','Jaipur'),
 ('Sneha','Patel','sneha.patel@mail.com','9810000006','Ahmedabad'),
 ('Arjun','Verma','arjun.verma@mail.com','9810000007','Gurugram'),
 ('Kavya','Reddy','kavya.reddy@mail.com','9810000008','Hyderabad'),
 ('Rahul','Gupta','rahul.gupta@mail.com','9810000009','Kanpur'),
 ('Ishita','Nair','ishita.nair@mail.com','9810000010','Kochi'),
 ('Aditya','Joshi','aditya.joshi@mail.com','9810000011','Pune'),
 ('Neha','Kapoor','neha.kapoor@mail.com','9810000012','Chandigarh'),
 ('Karan','Malhotra','karan.malhotra@mail.com','9810000013','Amritsar'),
 ('Pooja','Desai','pooja.desai@mail.com','9810000014','Surat'),
 ('Siddharth','Rao','siddharth.rao@mail.com','9810000015','Bengaluru'),
 ('Divya','Menon','divya.menon@mail.com','9810000016','Thiruvananthapuram'),
 ('Amit','Chaudhary','amit.chaudhary@mail.com','9810000017','Meerut'),
 ('Riya','Bansal','riya.bansal@mail.com','9810000018','Faridabad'),
 ('Manish','Yadav','manish.yadav@mail.com','9810000019','Patna'),
 ('Tanvi','Kulkarni','tanvi.kulkarni@mail.com','9810000020','Nagpur');

-- Reservations: for every room, walk through 2026 laying down back-to-back
-- stays (1-5 nights, 1-6 day gaps) so rooms never double-book.
-- Guest choice is skewed so some guests are "regulars".
DROP PROCEDURE IF EXISTS gen_reservations;
DELIMITER //
CREATE PROCEDURE gen_reservations()
BEGIN
  DECLARE v_room INT DEFAULT 1;
  DECLARE v_day DATE;
  DECLARE v_nights INT;
  DECLARE v_out DATE;
  DECLARE v_status VARCHAR(20);
  DECLARE v_today DATE DEFAULT '2026-11-09';

  WHILE v_room <= 12 DO
    SET v_day = DATE '2026-01-01' + INTERVAL FLOOR(RAND()*5) DAY;
    WHILE v_day < DATE '2026-12-31' DO
      SET v_nights = 1 + FLOOR(RAND()*5);
      SET v_out = v_day + INTERVAL v_nights DAY;

      IF RAND() < 0.06 THEN
        SET v_status = 'Cancelled';
      ELSEIF v_out <= v_today THEN
        SET v_status = 'Checked-Out';
      ELSEIF v_day <= v_today THEN
        SET v_status = 'Checked-In';
      ELSE
        SET v_status = 'Booked';
      END IF;

      INSERT INTO reservations (guest_id, room_id, check_in_date, check_out_date, num_guests, status)
      VALUES (1 + FLOOR(POW(RAND(), 1.8) * 20), v_room, v_day, v_out,
              1 + FLOOR(RAND() * (SELECT max_occupancy FROM room_types rt
                                  JOIN rooms r ON r.type_id = rt.type_id
                                  WHERE r.room_id = v_room)),
              v_status);

      SET v_day = v_out + INTERVAL (1 + FLOOR(RAND()*6)) DAY;
    END WHILE;
    SET v_room = v_room + 1;
  END WHILE;
END //
DELIMITER ;

CALL gen_reservations();
DROP PROCEDURE gen_reservations;

-- Extra charges: ~35% of non-cancelled stays that have started
INSERT INTO extra_charges (reservation_id, description, amount, charged_on)
SELECT r.reservation_id,
       ELT(1 + FLOOR(RAND()*5), 'Room service','Laundry','Spa','Airport pickup','Minibar'),
       ELT(1 + FLOOR(RAND()*5), 600, 850, 1500, 2200, 3200),
       r.check_in_date + INTERVAL 1 DAY
FROM reservations r
WHERE r.status IN ('Checked-In','Checked-Out')
  AND RAND() < 0.35;

-- Quick sanity check
SELECT 'guests' AS tbl, COUNT(*) AS cnt FROM guests
UNION ALL SELECT 'room_types', COUNT(*) FROM room_types
UNION ALL SELECT 'rooms', COUNT(*) FROM rooms
UNION ALL SELECT 'room_rates', COUNT(*) FROM room_rates
UNION ALL SELECT 'reservations', COUNT(*) FROM reservations
UNION ALL SELECT 'extra_charges', COUNT(*) FROM extra_charges;
