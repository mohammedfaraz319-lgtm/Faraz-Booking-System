-- ============================================================
-- Faraz Booking System - Database Schema (SQLite)
-- Project by: Faraz
-- ============================================================

PRAGMA foreign_keys = ON;

DROP VIEW    IF EXISTS v_booking_details;
DROP TRIGGER IF EXISTS trg_no_overlap;
DROP TRIGGER IF EXISTS trg_valid_dates;
DROP TABLE   IF EXISTS payments;
DROP TABLE   IF EXISTS bookings;
DROP TABLE   IF EXISTS customers;
DROP TABLE   IF EXISTS rooms;
DROP TABLE   IF EXISTS room_types;

-- Room categories (Standard, Deluxe, Suite ...)
CREATE TABLE room_types (
    type_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name       TEXT    NOT NULL UNIQUE,
    description     TEXT,
    price_per_night REAL    NOT NULL CHECK (price_per_night > 0),
    capacity        INTEGER NOT NULL CHECK (capacity > 0)
);

-- Physical rooms
CREATE TABLE rooms (
    room_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    room_number TEXT    NOT NULL UNIQUE,
    floor       INTEGER NOT NULL,
    type_id     INTEGER NOT NULL,
    is_active   INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    FOREIGN KEY (type_id) REFERENCES room_types(type_id)
);

-- People who make bookings
CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name   TEXT NOT NULL,
    email       TEXT NOT NULL UNIQUE,
    phone       TEXT,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Bookings (check_out is exclusive: the guest leaves that morning)
CREATE TABLE bookings (
    booking_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id  INTEGER NOT NULL,
    room_id      INTEGER NOT NULL,
    check_in     TEXT    NOT NULL,           -- YYYY-MM-DD
    check_out    TEXT    NOT NULL,           -- YYYY-MM-DD
    guests       INTEGER NOT NULL DEFAULT 1 CHECK (guests > 0),
    status       TEXT    NOT NULL DEFAULT 'CONFIRMED'
                 CHECK (status IN ('CONFIRMED','CANCELLED')),
    total_amount REAL    NOT NULL CHECK (total_amount >= 0),
    created_at   TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (room_id)     REFERENCES rooms(room_id)
);

-- Payments (simulated)
CREATE TABLE payments (
    payment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    booking_id INTEGER NOT NULL,
    amount     REAL    NOT NULL CHECK (amount >= 0),
    method     TEXT    NOT NULL CHECK (method IN ('CARD','UPI','CASH')),
    status     TEXT    NOT NULL DEFAULT 'PAID' CHECK (status IN ('PAID','REFUNDED')),
    paid_at    TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
);

-- Indexes for common lookups
CREATE INDEX idx_bookings_room_dates ON bookings(room_id, check_in, check_out);
CREATE INDEX idx_bookings_customer   ON bookings(customer_id);
CREATE INDEX idx_rooms_type          ON rooms(type_id);

-- Rule 1: check-out must be after check-in
CREATE TRIGGER trg_valid_dates
BEFORE INSERT ON bookings
WHEN NEW.check_out <= NEW.check_in
BEGIN
    SELECT RAISE(ABORT, 'Check-out date must be after check-in date');
END;

-- Rule 2: a room cannot be double-booked (overlap prevention)
CREATE TRIGGER trg_no_overlap
BEFORE INSERT ON bookings
WHEN EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.room_id = NEW.room_id
      AND b.status  = 'CONFIRMED'
      AND NEW.check_in  < b.check_out
      AND NEW.check_out > b.check_in
)
BEGIN
    SELECT RAISE(ABORT, 'Room is already booked for the selected dates');
END;

-- Convenient view joining everything
CREATE VIEW v_booking_details AS
SELECT b.booking_id,
       c.full_name, c.email,
       r.room_number, rt.type_name,
       b.check_in, b.check_out,
       CAST(julianday(b.check_out) - julianday(b.check_in) AS INTEGER) AS nights,
       b.guests, b.status, b.total_amount, b.created_at
FROM bookings b
JOIN customers  c  ON c.customer_id = b.customer_id
JOIN rooms      r  ON r.room_id     = b.room_id
JOIN room_types rt ON rt.type_id    = r.type_id;
