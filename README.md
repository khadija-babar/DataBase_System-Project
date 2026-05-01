This project is a **Bus Management System** designed to efficiently manage transportation operations including passengers, ticketing, scheduling, and administration.

The system is built using a **relational database design** and implemented with **SQLite (DDL)**.
The system is built using a **relational database design** and implemented with **SQLite, Flask, HTML, CSS, and JavaScript**. The database is the main focus: the route planner, fare calculation, capacity cards, account balance, and tickets all read from or write to SQLite.

## 📊 ERD Diagram

The following diagram represents the database structure and relationships:

<img width="1601" height="976" alt="BRT_ERD_v3 drawio (2)" src="https://github.com/user-attachments/assets/f4799f1e-91f3-4069-b01a-da2a7e4b6ceb" />


---

## ⚙️ Technologies Used

* **Database:** SQLite
* **Language:** SQL (DDL)
* **Design:** ERD (Entity-Relationship Diagram)

---

## 🧱 Database Schema

The system consists of the following core entities:

* **Passenger** – Stores user details and account balance
* **Ticket** – Manages ticket booking and status
* **Bus** – Contains bus information and availability
* **Driver** – Stores driver details and status
* **Route** – Defines routes and directions
* **Schedule** – Links buses, drivers, and routes with timings
* **Station** – Stores station/location data
* **Route_Station** – Maps routes to stations
* **Recharge** – Handles balance top-ups
* **Complaint** – Tracks passenger complaints
* **Notification** – Sends system updates
* **Admin** – Manages system operations

---

## 🧾 DDL Script

The database schema is implemented in the following file:

```id="d9x5hg"
/database/group13.sql
```

This file includes:

* Table creation statements
* Primary and foreign key constraints
* Status fields and relationships

---

# BRT Role-Based Management System

## Overview

This is a complete Flask and SQLite web application built around the project ERD. It supports three separate roles:

1. Admin
2. Driver
3. Passenger/User

Each role has its own login page and dashboard. The frontend is designed for normal users and does not expose raw database tables, SQL queries, triggers, or internal schema details.

## Folder Structure

```text
.
├── app.py
├── group13.sql
├── index.html
├── passenger_login.html
├── passenger_signup.html
├── admin_login.html
├── driver_login.html
├── passenger_dashboard.html
├── admin_dashboard.html
├── driver_dashboard.html
├── requirements.txt
└── README.md
```

## Role Features

### Passenger/User

- Separate passenger login and signup
- Trip planner using stations and routes
- Fare calculation
- Ticket booking
- Balance and recent tickets
- Notifications
- Complaint submission

### Driver

- Separate driver login
- Assigned schedules
- Route and bus details
- Status update for schedules

### Admin

- Separate admin login
- System overview
- Route, bus, driver, passenger, ticket, recharge, complaint, and notification summaries
- Complaint response
- Bus status update
- Passenger notification sending

## Database

The database is implemented in `group13.sql` and follows the ERD entities:

- Passenger
- Admin
- Bus
- Driver
- Route
- Station
- Route_Station
- Schedule
- Ticket
- Recharge
- Complaint
- Notification

The app creates `database.db` automatically from `group13.sql` when needed.

## Run Locally

Install dependencies:

```bash
pip install -r requirements.txt
```

Run the app:

```bash
python app.py
```

On Windows you can use:

```powershell
py app.py
```

Open:

```text
http://127.0.0.1:5000
```

If you changed the SQL file and need fresh seed data, delete `database.db` and restart the app.

## Demo Logins

Passenger:

```text
Username: demo
Password: demo123
```

Admin:

```text
Email: admin@brt.local
Password: admin123
```

Driver:

```text
License Number: BRT-PWR-001
Password: driver123
```

## Notes

- Backend APIs perform all database operations.
- Passwords are stored as Werkzeug password hashes.
- Frontend screens show user-friendly transportation features, not raw database internals.
## 👥 Contributors

* khadija babar
* hifza akhunzada
* syed maaz ahmad

---

## 📌 Notes

* SQLite is used for simplicity and easy setup
* The schema follows relational database principles
* ENUM-like values are handled using constraints in SQLite

---

## 📄 License

This project is developed for academic purpose
