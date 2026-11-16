-- ============================================================
-- Hotel Reservation System - Schema (MariaDB 10.11 / MySQL 8)
-- ============================================================
DROP DATABASE IF EXISTS hotel_db;
CREATE DATABASE hotel_db CHARACTER SET utf8mb4;
USE hotel_db;

CREATE TABLE guests (
  guest_id     INT AUTO_INCREMENT PRIMARY KEY,
  first_name   VARCHAR(50)  NOT NULL,
  last_name    VARCHAR(50)  NOT NULL,
  email        VARCHAR(100) NOT NULL,
  phone        VARCHAR(20),
  city         VARCHAR(50),
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE room_types (
  type_id        TINYINT AUTO_INCREMENT PRIMARY KEY,
  type_name      VARCHAR(30) NOT NULL UNIQUE,
  max_occupancy  TINYINT NOT NULL,
  description    VARCHAR(150)
) ENGINE=InnoDB;

CREATE TABLE rooms (
  room_id      INT AUTO_INCREMENT PRIMARY KEY,
  room_number  VARCHAR(10) NOT NULL UNIQUE,
  type_id      TINYINT NOT NULL,
  floor_no     TINYINT NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  FOREIGN KEY (type_id) REFERENCES room_types (type_id)
) ENGINE=InnoDB;

CREATE TABLE room_rates (
  rate_id       INT AUTO_INCREMENT PRIMARY KEY,
  type_id       TINYINT NOT NULL,
  season        VARCHAR(20) NOT NULL,
  valid_from    DATE NOT NULL,
  valid_to      DATE NOT NULL,
  nightly_rate  DECIMAL(10,2) NOT NULL,
  CHECK (nightly_rate > 0),
  CHECK (valid_to >= valid_from),
  FOREIGN KEY (type_id) REFERENCES room_types (type_id)
) ENGINE=InnoDB;

CREATE TABLE reservations (
  reservation_id  INT AUTO_INCREMENT PRIMARY KEY,
  guest_id        INT NOT NULL,
  room_id         INT NOT NULL,
  check_in_date   DATE NOT NULL,
  check_out_date  DATE NOT NULL,
  num_guests      TINYINT NOT NULL DEFAULT 1,
  status          ENUM('Booked','Checked-In','Checked-Out','Cancelled')
                  NOT NULL DEFAULT 'Booked',
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CHECK (check_out_date > check_in_date),
  FOREIGN KEY (guest_id) REFERENCES guests (guest_id),
  FOREIGN KEY (room_id)  REFERENCES rooms (room_id)
) ENGINE=InnoDB;

CREATE TABLE extra_charges (
  charge_id       INT AUTO_INCREMENT PRIMARY KEY,
  reservation_id  INT NOT NULL,
  description     VARCHAR(60) NOT NULL,
  amount          DECIMAL(10,2) NOT NULL CHECK (amount > 0),
  charged_on      DATE NOT NULL,
  FOREIGN KEY (reservation_id) REFERENCES reservations (reservation_id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- Helper table: one row per day (used to bill each night of a stay)
CREATE TABLE calendar_dates (
  cal_date DATE PRIMARY KEY
) ENGINE=InnoDB;

INSERT INTO calendar_dates
WITH RECURSIVE d AS (
  SELECT DATE '2026-01-01' AS dt
  UNION ALL
  SELECT dt + INTERVAL 1 DAY FROM d WHERE dt < '2027-12-31'
)
SELECT dt FROM d;

SHOW TABLES;
