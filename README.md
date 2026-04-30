# 🚌 Bus Management System

## 📌 Overview

This project is a **Bus Management System** designed to efficiently manage transportation operations including passengers, ticketing, scheduling, and administration.

The system is built using a **relational database design** and implemented with **SQLite, Flask, HTML, CSS, and JavaScript**. The database is the main focus: the route planner, fare calculation, capacity cards, account balance, and tickets all read from or write to SQLite.

---

## 📊 ERD Diagram

The following diagram represents the database structure and relationships:

<img width="1601" height="976" alt="BRT_ERD_v3 drawio (2)" src="https://github.com/user-attachments/assets/f4799f1e-91f3-4069-b01a-da2a7e4b6ceb" />


---

## ⚙️ Technologies Used

* **Database:** SQLite
* **Backend:** Flask
* **Frontend:** HTML, CSS, JavaScript
* **Language:** SQL (DDL, DML, DQL)
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

## 🧾 SQL Script

The database schema is implemented in the following file:

```text
group13.sql
```

This file includes:

* Table creation statements
* Primary and foreign key constraints
* Status fields and relationships
* DML seed data for buses, drivers, routes, stations, schedules, recharge, and a demo passenger
* DQL examples for route listing, direct-trip fare lookup, and live bus occupancy

---

## 📁 Project Structure

```text
.
├── app.py
├── dashboard.html
├── group13.sql
├── login.html
├── signup.html
├── requirements.txt
└── README.md
```

---

## 🚀 How to Run

### 1. Clone the Repository

```bash id="a6z6tb"
git clone https://github.com/your-username/your-repo-name.git
cd your-repo-name
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Run the Flask App

```bash
python3 app.py
```

Open:

```text
http://127.0.0.1:5000
```

Demo login:

```text
Username: demo
Password: demo123
```

### 4. Execute the SQL File Manually

Run the DDL script using SQLite:

```bash
sqlite3 database.db < group13.sql
```

The app also initializes this database automatically when `database.db` is missing or does not contain the current route schema.

---

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

This project is developed for academic purposes.
