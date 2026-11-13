# Faraz Booking System (SQL Based Online Booking)

> Developed by **Faraz**

An online booking system built around a **relational SQL database** (SQLite) with a
Python **Flask** web interface. Guests can search available rooms by date, book and pay
(simulated), view and cancel bookings. An admin page shows revenue reports computed
with SQL.

## Features
- Date-range room availability search (SQL `NOT IN` + overlap logic)
- Booking in a single **transaction** (customer + booking + payment)
- **Triggers** prevent double-booking and invalid dates
- **View** (`v_booking_details`) joining 4 tables
- Cancel booking with automatic payment refund
- Admin dashboard with aggregate queries (`COUNT`, `SUM`, `GROUP BY`, `LEFT JOIN`)

## Database design

```
room_types (1) ---< rooms (1) ---< bookings >--- (1) customers
                                       |
                                       1
                                       |
                                       <  payments
```

| Table | Purpose |
|-------|---------|
| `room_types` | Standard / Deluxe / Suite, price and capacity |
| `rooms` | Physical rooms, linked to a type |
| `customers` | Guests (unique email) |
| `bookings` | Stay dates, status, total amount |
| `payments` | Payment per booking (PAID / REFUNDED) |

Constraints used: `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `NOT NULL`, `CHECK`, indexes,
triggers (`trg_valid_dates`, `trg_no_overlap`) and a view.

## How to run

```bash
git clone <your-repo-url>
cd faraz-booking-system
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

Open http://127.0.0.1:5000. The database `hotel.db` is created automatically from
`schema.sql` and `seed.sql` on first run.

To explore the SQL directly:

```bash
sqlite3 hotel.db < queries.sql
```

## Project structure

```
faraz-booking-system/
├── app.py            # Flask application (routes + SQL queries)
├── schema.sql        # Tables, indexes, triggers, view
├── seed.sql          # Sample data
├── queries.sql       # Example SQL queries for reports
├── requirements.txt
├── templates/        # HTML pages (Jinja2)
└── static/style.css
```

## Author
**Faraz**

Class / Roll No.: _BE (1AH22CS064)__________
