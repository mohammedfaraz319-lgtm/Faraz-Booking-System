"""Faraz Booking System - Flask + SQLite.

Project by: Faraz
"""
import os
import sqlite3
from datetime import date

from flask import Flask, flash, g, redirect, render_template, request, url_for

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "hotel.db")

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "dev-secret-change-me")


# ---------- database helpers ----------
def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys = ON")
    return g.db


@app.teardown_appcontext
def close_db(_exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    """Create tables and load sample data."""
    conn = sqlite3.connect(DB_PATH)
    for name in ("schema.sql", "seed.sql"):
        with open(os.path.join(BASE_DIR, name), encoding="utf-8") as f:
            conn.executescript(f.read())
    conn.commit()
    conn.close()


# ---------- routes ----------
@app.route("/")
def index():
    types = get_db().execute("SELECT * FROM room_types ORDER BY price_per_night").fetchall()
    return render_template("index.html", types=types, today=date.today().isoformat())


@app.route("/search")
def search():
    check_in = request.args.get("check_in", "")
    check_out = request.args.get("check_out", "")
    guests = request.args.get("guests", "1")
    if not check_in or not check_out or check_out <= check_in:
        flash("Please choose valid dates (check-out must be after check-in).", "error")
        return redirect(url_for("index"))
    rooms = get_db().execute(
        """
        SELECT r.room_id, r.room_number, r.floor, rt.type_name, rt.description,
               rt.price_per_night, rt.capacity,
               CAST(julianday(:co) - julianday(:ci) AS INTEGER) AS nights,
               CAST(julianday(:co) - julianday(:ci) AS INTEGER) * rt.price_per_night AS total
        FROM rooms r
        JOIN room_types rt ON rt.type_id = r.type_id
        WHERE r.is_active = 1
          AND rt.capacity >= :g
          AND r.room_id NOT IN (
              SELECT b.room_id FROM bookings b
              WHERE b.status = 'CONFIRMED'
                AND :ci < b.check_out AND :co > b.check_in)
        ORDER BY rt.price_per_night, r.room_number
        """,
        {"ci": check_in, "co": check_out, "g": int(guests)},
    ).fetchall()
    return render_template("results.html", rooms=rooms, check_in=check_in,
                           check_out=check_out, guests=guests)


@app.route("/book/<int:room_id>", methods=["GET", "POST"])
def book(room_id):
    db = get_db()
    room = db.execute(
        "SELECT r.*, rt.type_name, rt.price_per_night, rt.capacity "
        "FROM rooms r JOIN room_types rt ON rt.type_id = r.type_id WHERE r.room_id = ?",
        (room_id,),
    ).fetchone()
    if room is None:
        return render_template("message.html", title="Not found", message="Room not found."), 404

    check_in = request.values.get("check_in", "")
    check_out = request.values.get("check_out", "")
    guests = request.values.get("guests", "1")

    if request.method == "POST":
        name = request.form["full_name"].strip()
        email = request.form["email"].strip().lower()
        phone = request.form.get("phone", "").strip()
        method = request.form.get("method", "CARD")
        if not name or not email or not check_in or not check_out:
            flash("Please fill in all required fields.", "error")
        elif int(guests) > room["capacity"]:
            flash(f"This room holds at most {room['capacity']} guests.", "error")
        else:
            try:
                with db:  # one transaction: customer + booking + payment
                    db.execute(
                        "INSERT INTO customers (full_name, email, phone) VALUES (?,?,?) "
                        "ON CONFLICT(email) DO UPDATE SET full_name=excluded.full_name, "
                        "phone=excluded.phone",
                        (name, email, phone),
                    )
                    cust = db.execute("SELECT customer_id FROM customers WHERE email=?",
                                      (email,)).fetchone()
                    cur = db.execute(
                        """
                        INSERT INTO bookings (customer_id, room_id, check_in, check_out,
                                              guests, total_amount)
                        VALUES (?,?,?,?,?,
                          CAST(julianday(?) - julianday(?) AS INTEGER) * ?)
                        """,
                        (cust["customer_id"], room_id, check_in, check_out, int(guests),
                         check_out, check_in, room["price_per_night"]),
                    )
                    booking_id = cur.lastrowid
                    total = db.execute("SELECT total_amount FROM bookings WHERE booking_id=?",
                                       (booking_id,)).fetchone()[0]
                    db.execute("INSERT INTO payments (booking_id, amount, method) VALUES (?,?,?)",
                               (booking_id, total, method))
                return redirect(url_for("confirmation", booking_id=booking_id))
            except sqlite3.IntegrityError as e:
                flash(str(e), "error")
            except sqlite3.DatabaseError as e:  # trigger errors (overlap / bad dates)
                flash(str(e), "error")

    try:
        nights = (date.fromisoformat(check_out) - date.fromisoformat(check_in)).days
    except ValueError:
        nights = 0
    return render_template("book.html", room=room, check_in=check_in, check_out=check_out,
                           guests=guests, nights=nights, total=nights * room["price_per_night"])


@app.route("/confirmation/<int:booking_id>")
def confirmation(booking_id):
    b = get_db().execute("SELECT * FROM v_booking_details WHERE booking_id=?",
                         (booking_id,)).fetchone()
    if b is None:
        return render_template("message.html", title="Not found", message="Booking not found."), 404
    return render_template("confirmation.html", b=b)


@app.route("/my-bookings", methods=["GET", "POST"])
def my_bookings():
    bookings, email = [], ""
    if request.method == "POST":
        email = request.form["email"].strip().lower()
        bookings = get_db().execute(
            "SELECT * FROM v_booking_details WHERE email=? ORDER BY check_in DESC", (email,)
        ).fetchall()
        if not bookings:
            flash("No bookings found for that email.", "error")
    return render_template("my_bookings.html", bookings=bookings, email=email)


@app.route("/cancel/<int:booking_id>", methods=["POST"])
def cancel(booking_id):
    db = get_db()
    with db:
        db.execute("UPDATE bookings SET status='CANCELLED' "
                   "WHERE booking_id=? AND status='CONFIRMED'", (booking_id,))
        db.execute("UPDATE payments SET status='REFUNDED' WHERE booking_id=?", (booking_id,))
    flash(f"Booking #{booking_id} cancelled and payment refunded.", "success")
    return redirect(request.referrer or url_for("index"))


@app.route("/admin")
def admin():
    db = get_db()
    bookings = db.execute("SELECT * FROM v_booking_details ORDER BY created_at DESC").fetchall()
    stats = db.execute(
        """
        SELECT (SELECT COUNT(*) FROM bookings WHERE status='CONFIRMED') AS confirmed,
               (SELECT COUNT(*) FROM bookings WHERE status='CANCELLED') AS cancelled,
               (SELECT COALESCE(SUM(amount),0) FROM payments WHERE status='PAID') AS revenue,
               (SELECT COUNT(*) FROM rooms WHERE is_active=1) AS rooms
        """
    ).fetchone()
    by_type = db.execute(
        """
        SELECT rt.type_name, COUNT(b.booking_id) AS bookings,
               COALESCE(SUM(b.total_amount),0) AS revenue
        FROM room_types rt
        LEFT JOIN rooms r ON r.type_id = rt.type_id
        LEFT JOIN bookings b ON b.room_id = r.room_id AND b.status='CONFIRMED'
        GROUP BY rt.type_id ORDER BY revenue DESC
        """
    ).fetchall()
    return render_template("admin.html", bookings=bookings, stats=stats, by_type=by_type)


if __name__ == "__main__":
    if not os.path.exists(DB_PATH):
        init_db()
        print("Database created with sample data.")
    app.run(debug=True)
