-- ============================================================
-- Indexing: composite index, email index, UNIQUE vs plain index
-- ============================================================
USE hotel_db;

-- 6.1 Composite index for the overlap check ------------------
SHOW INDEX FROM reservations;

EXPLAIN SELECT reservation_id FROM reservations
WHERE room_id = 5 AND status <> 'Cancelled'
  AND check_in_date  < '2026-09-20'
  AND check_out_date > '2026-09-10';

-- Equality column first, then the two range columns
CREATE INDEX idx_room_dates ON reservations (room_id, check_in_date, check_out_date);

EXPLAIN SELECT reservation_id FROM reservations
WHERE room_id = 5 AND status <> 'Cancelled'
  AND check_in_date  < '2026-09-20'
  AND check_out_date > '2026-09-10';

SHOW INDEX FROM reservations;

-- Same test on a big table: 300,000 random reservations, 500 rooms
SET max_recursive_iterations = 1000000;      -- MariaDB (MySQL: SET cte_max_recursion_depth = 1000000)

DROP TABLE IF EXISTS perf_reservations;
CREATE TABLE perf_reservations (
  reservation_id INT AUTO_INCREMENT PRIMARY KEY,
  room_id        INT  NOT NULL,
  check_in_date  DATE NOT NULL,
  check_out_date DATE NOT NULL
) ENGINE=InnoDB;

INSERT INTO perf_reservations (room_id, check_in_date, check_out_date)
WITH RECURSIVE n AS (
  SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 300000
)
SELECT 1 + FLOOR(RAND()*500),
       d, d + INTERVAL (1 + FLOOR(RAND()*5)) DAY
FROM (SELECT DATE '2026-01-01' + INTERVAL FLOOR(RAND()*360) DAY AS d FROM n) t;

-- Without index: type = ALL (full scan)
EXPLAIN SELECT reservation_id FROM perf_reservations
WHERE room_id = 250 AND check_in_date < '2026-09-20' AND check_out_date > '2026-09-10';

CREATE INDEX idx_perf_room_dates ON perf_reservations (room_id, check_in_date, check_out_date);

-- With index: type = range, Using index
EXPLAIN SELECT reservation_id FROM perf_reservations
WHERE room_id = 250 AND check_in_date < '2026-09-20' AND check_out_date > '2026-09-10';

-- 6.2 Index on guest email ------------------------------------
DROP TABLE IF EXISTS perf_guests;
CREATE TABLE perf_guests (
  guest_id INT AUTO_INCREMENT PRIMARY KEY,
  email    VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

INSERT INTO perf_guests (email)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 200000)
SELECT CONCAT('user', i, '@mail.com') FROM n;

EXPLAIN SELECT * FROM perf_guests WHERE email = 'user150000@mail.com';   -- type = ALL
CREATE INDEX idx_perf_email ON perf_guests (email);
EXPLAIN SELECT * FROM perf_guests WHERE email = 'user150000@mail.com';   -- type = ref, rows = 1

-- Same index on the real guests table
CREATE INDEX idx_guests_email ON guests (email);

-- 6.3 UNIQUE constraint vs plain index ------------------------
DROP TABLE IF EXISTS t_plain;
DROP TABLE IF EXISTS t_unique;
CREATE TABLE t_plain  (id INT AUTO_INCREMENT PRIMARY KEY, email VARCHAR(100), INDEX idx_email (email));
CREATE TABLE t_unique (id INT AUTO_INCREMENT PRIMARY KEY, email VARCHAR(100), UNIQUE INDEX uq_email (email));

INSERT INTO t_plain (email) VALUES ('a@mail.com'), ('b@mail.com'), ('a@mail.com');   -- accepted
-- This one FAILS on purpose (ERROR 1062: duplicate entry) and the whole INSERT is rolled back.
-- It is commented out so the script keeps running; paste it into the client to see the error.
-- INSERT INTO t_unique (email) VALUES ('a@mail.com'), ('b@mail.com'), ('a@mail.com');
SELECT 't_plain' AS tbl, COUNT(*) AS cnt FROM t_plain
UNION ALL SELECT 't_unique', COUNT(*) FROM t_unique;

-- On the real table: replace the plain index with a UNIQUE one
DROP INDEX idx_guests_email ON guests;
CREATE UNIQUE INDEX uq_guests_email ON guests (email);
EXPLAIN SELECT * FROM guests WHERE email = 'aarav.sharma@mail.com';       -- type = const

-- Clean up test tables
DROP TABLE perf_reservations, perf_guests, t_plain, t_unique;
