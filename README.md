# BRT Role-Based Management System

## Overview
## Group Number
**Group 13**

## Group Members

| Name | Roll Number |
|---|---|
| Khadija Babar | 23P-0509 |
| Hifza Akhunzada | 23P-0529 |
| Syed Maaz Ahmad | 24P-0757 |

## Project Title & Description

**BRT Role-Based Management System**

A full-stack web application for managing a Bus Rapid Transit (BRT) system. It supports three roles  Passenger, Driver, and Admin each with a dedicated login and dashboard. Passengers can plan trips, calculate fares, book tickets, recharge their card balance, and submit complaints. Drivers can view their assigned schedules and update status. Admins can monitor the entire system, respond to complaints, and send notifications.

## GitHub Repository URL

[https://github.com/khadija-babar/DataBase_System-Project](https://github.com/khadija-babar/DataBase_System-Project)

## Technologies Used

| Layer | Technology |
|---|---|
| Backend | Python 3, Flask |
| Database | SQLite3 |
| DB Access | sqlite3 (built-in), Werkzeug (password hashing) |
| Frontend | HTML, CSS, JavaScript |
| Schema & Seed Data | SQL (group13.sql) |
| Deployment | Vercel |

## Installation & Running the Application

### Prerequisites
- Python 3.8 or higher installed
- pip (Python package manager)

### Steps

**1. Clone the repository**
```bash
git clone https://github.com/khadija-babar/DataBase_System-Project.git
cd DataBase_System-Project
```

**2. Install dependencies**
```bash
pip install -r requirements.txt
```

**3. Run the application**
```bash
python app.py
```
On Windows you can also use:
```bash
py app.py
```

> The database (`database.db`) is created automatically from `group13.sql` on first run. If you need fresh seed data, delete `database.db` and restart the app.

### Demo Login Credentials

| Role | Field | Value |
|---|---|---|
| Passenger | Username | demo |
| Passenger | Password | demo123 |
| Admin | Email | admin@brt.local |
| Admin | Password | admin123 |
| Driver | License Number | BRT-PWR-001 |
| Driver | Password | driver123 |
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

- Separate passenger login and signup is there
- Trip planner using stations and routes
- Fare calculation
- Ticket booking
- Balance and recent tickets
- Notifications
- Complaint submission module

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

