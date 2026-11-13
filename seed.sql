-- Faraz Booking System - Sample data for demo / testing
-- Project by: Faraz

INSERT INTO room_types (type_name, description, price_per_night, capacity) VALUES
 ('Standard', 'Comfortable room with a queen bed and city view', 2500, 2),
 ('Deluxe',   'Spacious room with king bed, balcony and minibar', 4200, 3),
 ('Suite',    'Luxury suite with living area and bathtub',        7500, 4);

INSERT INTO rooms (room_number, floor, type_id) VALUES
 ('101', 1, 1), ('102', 1, 1), ('103', 1, 1),
 ('201', 2, 2), ('202', 2, 2), ('203', 2, 2),
 ('301', 3, 3), ('302', 3, 3);

INSERT INTO customers (full_name, email, phone) VALUES
 ('Aarav Sharma', 'aarav@example.com', '9876543210'),
 ('Priya Nair',   'priya@example.com', '9123456780'),
 ('Rahul Verma',  'rahul@example.com', '9988776655');

INSERT INTO bookings (customer_id, room_id, check_in, check_out, guests, status, total_amount) VALUES
 (1, 1, '2026-12-01', '2026-12-04', 2, 'CONFIRMED', 7500),
 (2, 4, '2026-12-02', '2026-12-05', 2, 'CONFIRMED', 12600),
 (3, 7, '2026-12-10', '2026-12-12', 3, 'CONFIRMED', 15000),
 (1, 2, '2026-11-20', '2026-11-22', 1, 'CANCELLED', 5000);

INSERT INTO payments (booking_id, amount, method, status) VALUES
 (1, 7500,  'UPI',  'PAID'),
 (2, 12600, 'CARD', 'PAID'),
 (3, 15000, 'CARD', 'PAID'),
 (4, 5000,  'CASH', 'REFUNDED');
