-- ============================================================
-- Faraz Booking System - Useful SQL queries
-- Project by: Faraz
-- (run in the SQLite shell: sqlite3 hotel.db)
-- ============================================================

-- 1. Available rooms between two dates (core booking query)
SELECT r.room_number, rt.type_name, rt.price_per_night
FROM rooms r
JOIN room_types rt ON rt.type_id = r.type_id
WHERE r.is_active = 1
  AND r.room_id NOT IN (
      SELECT b.room_id FROM bookings b
      WHERE b.status = 'CONFIRMED'
        AND '2026-12-03' < b.check_out
        AND '2026-12-06' > b.check_in
  );

-- 2. All bookings with customer and room details
SELECT * FROM v_booking_details ORDER BY check_in;

-- 3. Total revenue (paid, not refunded)
SELECT SUM(amount) AS total_revenue FROM payments WHERE status = 'PAID';

-- 4. Revenue by room type
SELECT rt.type_name, COUNT(b.booking_id) AS bookings, SUM(b.total_amount) AS revenue
FROM bookings b
JOIN rooms r ON r.room_id = b.room_id
JOIN room_types rt ON rt.type_id = r.type_id
WHERE b.status = 'CONFIRMED'
GROUP BY rt.type_name
ORDER BY revenue DESC;

-- 5. Top customers by spending
SELECT c.full_name, COUNT(*) AS bookings, SUM(b.total_amount) AS spent
FROM customers c
JOIN bookings b ON b.customer_id = c.customer_id
WHERE b.status = 'CONFIRMED'
GROUP BY c.customer_id
ORDER BY spent DESC;

-- 6. Rooms that have never been booked
SELECT room_number FROM rooms
WHERE room_id NOT IN (SELECT room_id FROM bookings);

-- 7. Cancellation count per customer
SELECT c.full_name, COUNT(*) AS cancelled
FROM bookings b JOIN customers c ON c.customer_id = b.customer_id
WHERE b.status = 'CANCELLED'
GROUP BY c.customer_id;

-- 8. Test the overlap trigger (this should FAIL with an error)
-- INSERT INTO bookings (customer_id, room_id, check_in, check_out, guests, total_amount)
-- VALUES (2, 1, '2026-12-02', '2026-12-03', 1, 2500);
