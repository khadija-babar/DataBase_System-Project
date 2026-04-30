PRAGMA foreign_keys = ON;

-- Rebuild the academic demo database from a clean state.
DROP VIEW IF EXISTS v_passenger_recharge_summary;
DROP VIEW IF EXISTS v_open_complaints;
DROP VIEW IF EXISTS v_route_stations;
DROP VIEW IF EXISTS v_passenger_tickets;
DROP VIEW IF EXISTS v_active_schedules;

DROP TRIGGER IF EXISTS trg_complaint_updated;
DROP TRIGGER IF EXISTS trg_schedule_updated;
DROP TRIGGER IF EXISTS trg_route_updated;
DROP TRIGGER IF EXISTS trg_driver_updated;
DROP TRIGGER IF EXISTS trg_bus_updated;
DROP TRIGGER IF EXISTS trg_passenger_updated;

DROP TABLE IF EXISTS Notification;
DROP TABLE IF EXISTS Complaint;
DROP TABLE IF EXISTS Recharge;
DROP TABLE IF EXISTS Ticket;
DROP TABLE IF EXISTS Schedule;
DROP TABLE IF EXISTS Route_Station;
DROP TABLE IF EXISTS Station;
DROP TABLE IF EXISTS Route;
DROP TABLE IF EXISTS Driver;
DROP TABLE IF EXISTS Bus;
DROP TABLE IF EXISTS Admin;
DROP TABLE IF EXISTS Passenger;

-- TABLE: Passenger
CREATE TABLE Passenger (
    passenger_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT    NOT NULL,
    email           TEXT    UNIQUE NOT NULL,
    phone_number    TEXT,
    password        TEXT    NOT NULL,
    card_balance    REAL    DEFAULT 0.0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- TABLE: Admin
CREATE TABLE Admin (
    admin_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    email       TEXT UNIQUE NOT NULL,
    password    TEXT NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- TABLE: Bus
CREATE TABLE Bus (
    bus_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    bus_number  TEXT UNIQUE NOT NULL,
    bus_type    TEXT NOT NULL CHECK(bus_type IN ('standard', 'express')),
    capacity    INTEGER NOT NULL DEFAULT 80 CHECK(capacity > 0),
    current_passengers INTEGER NOT NULL DEFAULT 0 CHECK(current_passengers >= 0),
    status      TEXT DEFAULT 'active' CHECK(status IN ('active', 'maintenance', 'inactive')),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK(current_passengers <= capacity)
);
-- TABLE: Driver
CREATE TABLE Driver (
    driver_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,
    phone_number    TEXT,
    license_number  TEXT UNIQUE NOT NULL,
    status          TEXT DEFAULT 'active' CHECK(status IN ('active', 'inactive', 'on_leave')),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- TABLE: Route
CREATE TABLE Route (
    route_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    route_code  TEXT UNIQUE NOT NULL,
    route_name  TEXT NOT NULL,
    route_type  TEXT NOT NULL CHECK(route_type IN ('standard', 'express')),
    total_stops INTEGER NOT NULL,
    direction   TEXT NOT NULL CHECK(direction IN ('Inbound', 'Outbound')),
    platform    TEXT NOT NULL,
    headway_min INTEGER NOT NULL CHECK(headway_min > 0),
    headway_max INTEGER NOT NULL CHECK(headway_max >= headway_min),
    fare_per_stop REAL NOT NULL DEFAULT 10 CHECK(fare_per_stop > 0),
    distance_per_stop_km REAL NOT NULL DEFAULT 1.5 CHECK(distance_per_stop_km > 0),
    minutes_per_stop INTEGER NOT NULL DEFAULT 2 CHECK(minutes_per_stop > 0),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- TABLE: Station
CREATE TABLE Station (
    station_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    station_name    TEXT UNIQUE NOT NULL,
    location_area   TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- TABLE: Route_Station
-- (Junction table: Route <-> Station)
-- route_station_id added as surrogate PK (was missing in ERD v1)
CREATE TABLE Route_Station (
    route_station_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    route_id            INTEGER NOT NULL,
    station_id          INTEGER NOT NULL,
    stop_order          INTEGER NOT NULL,
    UNIQUE(route_id, station_id),
    FOREIGN KEY (route_id)   REFERENCES Route(route_id)     ON DELETE CASCADE,
    FOREIGN KEY (station_id) REFERENCES Station(station_id) ON DELETE CASCADE
);
-- TABLE: Schedule
-- NOTE: ticket_id has been REMOVED to break the circular FK
-- with Ticket. Relationship is now: Ticket.schedule_id -> Schedule

CREATE TABLE Schedule (
    schedule_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    bus_id              INTEGER NOT NULL,
    route_id            INTEGER NOT NULL,
    driver_id           INTEGER NOT NULL,
    departure_time      TEXT NOT NULL,
    arrival_time        TEXT NOT NULL,
    actual_arrival_time TEXT,
    operating_days      TEXT,
    status              TEXT DEFAULT 'scheduled'
                             CHECK(status IN ('scheduled', 'active', 'delayed', 'cancelled')),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bus_id)    REFERENCES Bus(bus_id)       ON DELETE RESTRICT,
    FOREIGN KEY (route_id)  REFERENCES Route(route_id)   ON DELETE RESTRICT,
    FOREIGN KEY (driver_id) REFERENCES Driver(driver_id) ON DELETE RESTRICT
);
-- TABLE: Ticket
-- schedule_id FK added here (one Schedule -> many Tickets)
-- This replaces the removed ticket_id on Schedule
CREATE TABLE Ticket (
    ticket_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    passenger_id    INTEGER NOT NULL,
    schedule_id     INTEGER,
    purchase_time   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status          TEXT DEFAULT 'active' CHECK(status IN ('active', 'used', 'cancelled')),
    fixed_fare      REAL NOT NULL,
    start_station   TEXT,
    end_station     TEXT,
    FOREIGN KEY (passenger_id) REFERENCES Passenger(passenger_id) ON DELETE CASCADE,
    FOREIGN KEY (schedule_id)  REFERENCES Schedule(schedule_id)   ON DELETE SET NULL
);

-- TABLE: Recharge

CREATE TABLE Recharge (
    recharge_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    passenger_id    INTEGER NOT NULL,
    amount          REAL NOT NULL CHECK(amount > 0),
    payment_method  TEXT NOT NULL CHECK(payment_method IN ('EasyPaisa', 'JazzCash', 'card', 'cash')),
    recharge_time   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status          TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'success', 'failed')),
    FOREIGN KEY (passenger_id) REFERENCES Passenger(passenger_id) ON DELETE CASCADE
);

-- TABLE: Complaint

CREATE TABLE Complaint (
    complaint_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    passenger_id    INTEGER NOT NULL,
    admin_id        INTEGER,
    complaint_text  TEXT NOT NULL,
    status          TEXT DEFAULT 'open' CHECK(status IN ('open', 'in_progress', 'resolved')),
    response_text   TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (passenger_id) REFERENCES Passenger(passenger_id) ON DELETE CASCADE,
    FOREIGN KEY (admin_id)     REFERENCES Admin(admin_id)         ON DELETE SET NULL
);
-- TABLE: Notification
-- is_read column added (was missing in ERD v1)
CREATE TABLE Notification (
    notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
    admin_id        INTEGER,
    passenger_id    INTEGER NOT NULL,
    message         TEXT NOT NULL,
    type            TEXT,
    is_read         INTEGER DEFAULT 0 CHECK(is_read IN (0, 1)),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (admin_id)     REFERENCES Admin(admin_id)         ON DELETE SET NULL,
    FOREIGN KEY (passenger_id) REFERENCES Passenger(passenger_id) ON DELETE CASCADE
);
-- INDEXES
CREATE INDEX idx_passenger_email       ON Passenger(email);
CREATE INDEX idx_bus_status            ON Bus(status);
CREATE INDEX idx_driver_status         ON Driver(status);
CREATE INDEX idx_route_type            ON Route(route_type);
CREATE INDEX idx_route_station_route   ON Route_Station(route_id);
CREATE INDEX idx_route_station_station ON Route_Station(station_id);
CREATE INDEX idx_schedule_route        ON Schedule(route_id);
CREATE INDEX idx_schedule_bus          ON Schedule(bus_id);
CREATE INDEX idx_schedule_driver       ON Schedule(driver_id);
CREATE INDEX idx_schedule_departure    ON Schedule(departure_time);
CREATE INDEX idx_schedule_status       ON Schedule(status);
CREATE INDEX idx_ticket_passenger      ON Ticket(passenger_id);
CREATE INDEX idx_ticket_schedule       ON Ticket(schedule_id);
CREATE INDEX idx_ticket_status         ON Ticket(status);
CREATE INDEX idx_recharge_passenger    ON Recharge(passenger_id);
CREATE INDEX idx_recharge_status       ON Recharge(status);
CREATE INDEX idx_complaint_passenger   ON Complaint(passenger_id);
CREATE INDEX idx_complaint_status      ON Complaint(status);
CREATE INDEX idx_notification_passenger ON Notification(passenger_id);
CREATE INDEX idx_notification_created  ON Notification(created_at);

-- TRIGGERS — keep updated_at in sync
CREATE TRIGGER trg_passenger_updated
AFTER UPDATE ON Passenger
BEGIN
    UPDATE Passenger SET updated_at = CURRENT_TIMESTAMP
    WHERE passenger_id = NEW.passenger_id;
END;

CREATE TRIGGER trg_bus_updated
AFTER UPDATE ON Bus
BEGIN
    UPDATE Bus SET updated_at = CURRENT_TIMESTAMP
    WHERE bus_id = NEW.bus_id;
END;

CREATE TRIGGER trg_driver_updated
AFTER UPDATE ON Driver
BEGIN
    UPDATE Driver SET updated_at = CURRENT_TIMESTAMP
    WHERE driver_id = NEW.driver_id;
END;

CREATE TRIGGER trg_route_updated
AFTER UPDATE ON Route
BEGIN
    UPDATE Route SET updated_at = CURRENT_TIMESTAMP
    WHERE route_id = NEW.route_id;
END;

CREATE TRIGGER trg_schedule_updated
AFTER UPDATE ON Schedule
BEGIN
    UPDATE Schedule SET updated_at = CURRENT_TIMESTAMP
    WHERE schedule_id = NEW.schedule_id;
END;

CREATE TRIGGER trg_complaint_updated
AFTER UPDATE ON Complaint
BEGIN
    UPDATE Complaint SET updated_at = CURRENT_TIMESTAMP
    WHERE complaint_id = NEW.complaint_id;
END;
-- VIEWS
-- Active schedules with full join details
CREATE VIEW v_active_schedules AS
SELECT
    s.schedule_id,
    s.departure_time,
    s.arrival_time,
    s.actual_arrival_time,
    s.operating_days,
    s.status,
    b.bus_number,
    b.bus_type,
    r.route_code,
    r.route_name,
    r.direction,
    r.platform,
    r.headway_min,
    r.headway_max,
    d.name AS driver_name
FROM Schedule s
JOIN Bus    b ON s.bus_id    = b.bus_id
JOIN Route  r ON s.route_id  = r.route_id
JOIN Driver d ON s.driver_id = d.driver_id
WHERE s.status IN ('scheduled', 'active');

-- Full ticket history per passenger
CREATE VIEW v_passenger_tickets AS
SELECT
    p.passenger_id,
    p.name          AS passenger_name,
    t.ticket_id,
    t.purchase_time,
    t.status        AS ticket_status,
    t.fixed_fare,
    s.schedule_id,
    s.departure_time,
    s.arrival_time,
    r.route_code,
    r.route_name,
    t.start_station,
    t.end_station
FROM Passenger p
JOIN Ticket   t ON p.passenger_id  = t.passenger_id
LEFT JOIN Schedule s ON t.schedule_id  = s.schedule_id
LEFT JOIN Route    r ON s.route_id     = r.route_id;

-- Ordered stations per route
CREATE VIEW v_route_stations AS
SELECT
    r.route_id,
    r.route_code,
    r.route_name,
    r.route_type,
    r.direction,
    r.platform,
    r.headway_min,
    r.headway_max,
    r.fare_per_stop,
    st.station_name,
    st.location_area,
    rs.stop_order
FROM Route         r
JOIN Route_Station rs ON r.route_id    = rs.route_id
JOIN Station       st ON rs.station_id = st.station_id
ORDER BY r.route_id, rs.stop_order;

-- Unresolved complaints with assigned admin
CREATE VIEW v_open_complaints AS
SELECT
    c.complaint_id,
    c.status,
    c.complaint_text,
    c.created_at,
    p.name  AS passenger_name,
    p.email AS passenger_email,
    a.name  AS assigned_admin
FROM Complaint c
JOIN Passenger p ON c.passenger_id = p.passenger_id
LEFT JOIN Admin a ON c.admin_id    = a.admin_id
WHERE c.status IN ('open', 'in_progress');

-- Recharge summary per passenger
CREATE VIEW v_passenger_recharge_summary AS
SELECT
    p.passenger_id,
    p.name,
    p.card_balance,
    COUNT(r.recharge_id)                            AS total_recharges,
    COALESCE(SUM(CASE WHEN r.status = 'success'
                      THEN r.amount END), 0)        AS total_recharged
FROM Passenger p
LEFT JOIN Recharge r ON p.passenger_id = r.passenger_id
GROUP BY p.passenger_id, p.name, p.card_balance;

-- DML SEED DATA
-- Demo users and operational records make the frontend usable immediately.
INSERT INTO Admin (name, email, password) VALUES
('BRT Admin', 'admin@brt.local', 'admin123');

INSERT INTO Passenger (name, email, phone_number, password, card_balance) VALUES
('demo', 'demo@brt.local', '03000000000', 'scrypt:32768:8:1$G0z0FIxqsFIuC5Tw$eb21c0ca7d6527160b8da010966f0ed432709c3bef9ac702f83774a3eb1a4228c9edb846dd48ae49072c31bde7d4ceae5e781952bd0d8c7a7400a12723f02ca6', 500.0);

INSERT INTO Driver (name, phone_number, license_number, status) VALUES
('Aftab Khan', '03001110001', 'BRT-PWR-001', 'active'),
('Bilal Ahmad', '03001110002', 'BRT-PWR-002', 'active'),
('Haris Khan', '03001110003', 'BRT-PWR-003', 'active'),
('Imran Ali', '03001110004', 'BRT-PWR-004', 'active'),
('Kamran Shah', '03001110005', 'BRT-PWR-005', 'active'),
('Noman Yousaf', '03001110006', 'BRT-PWR-006', 'active'),
('Sajid Iqbal', '03001110007', 'BRT-PWR-007', 'active'),
('Tariq Mehmood', '03001110008', 'BRT-PWR-008', 'active'),
('Usman Gul', '03001110009', 'BRT-PWR-009', 'active'),
('Zahid Afridi', '03001110010', 'BRT-PWR-010', 'active');

INSERT INTO Bus (bus_number, bus_type, capacity, current_passengers, status) VALUES
('B-001', 'express', 80, 36, 'active'),
('B-002', 'standard', 80, 62, 'active'),
('B-003', 'standard', 80, 26, 'active'),
('B-004', 'standard', 80, 73, 'active'),
('B-005', 'standard', 80, 45, 'active'),
('B-006', 'standard', 80, 18, 'active'),
('B-007', 'standard', 80, 54, 'active'),
('B-008', 'standard', 80, 70, 'active'),
('B-009', 'express', 80, 27, 'active'),
('B-010', 'express', 80, 58, 'active');

INSERT INTO Route (route_code, route_name, route_type, total_stops, direction, platform, headway_min, headway_max, fare_per_stop) VALUES
('ER01', 'ER-01: Chamkani to Kharkhano', 'express', 11, 'Outbound', '3', 4, 6, 10),
('SR02', 'SR-02: Chamkani to Kharkhano (Full)', 'standard', 30, 'Outbound', '1', 5, 6, 10),
('DR03A', 'DR-03A: Dabgari Gardens to Kohat Adda', 'standard', 10, 'Outbound', '3', 5, 10, 10),
('DR03B', 'DR-03B: Malik Saad Shaheed to Shah Alam Pul', 'standard', 23, 'Outbound', '4', 7, 10, 10),
('DR05', 'DR-05: Mall of Hayatabad to Phase 6', 'standard', 9, 'Outbound', '3', 10, 15, 10),
('DR06', 'DR-06: Mall of Hayatabad to Phase 7', 'standard', 16, 'Outbound', '2', 8, 15, 10),
('DR07', 'DR-07: Karkhano Market to Phase 7', 'standard', 14, 'Outbound', '2', 15, 15, 10),
('SR08', 'SR-08: Gulbahar Chowk to Mall of Hayatabad', 'standard', 18, 'Outbound', '2', 4, 6, 10),
('ER09', 'ER-09: Gulbahar Chowk to Phase 6', 'express', 14, 'Outbound', '2', 5, 6, 10),
('ER10', 'ER-10: Hospital Chowk to Kohat Adda', 'express', 10, 'Outbound', '2', 4, 6, 10);

INSERT INTO Schedule (bus_id, route_id, driver_id, departure_time, arrival_time, operating_days, status)
SELECT b.bus_id, r.route_id, d.driver_id,
       printf('%02d:00', 6 + r.route_id),
       printf('%02d:45', 6 + r.route_id),
       'Daily',
       CASE WHEN r.route_id IN (1, 2, 8) THEN 'active' ELSE 'scheduled' END
FROM Route r
JOIN Bus b ON b.bus_number = printf('B-%03d', r.route_id)
JOIN Driver d ON d.license_number = printf('BRT-PWR-%03d', r.route_id);

-- Insert route stations from the rough frontend data and keep the stop order accurate.
INSERT OR IGNORE INTO Station (station_name)
WITH route_stop(route_code, stop_order, station_name) AS (
    VALUES
    ('ER01', 1, 'Chamkani'), ('ER01', 2, 'Sardar Garhi'), ('ER01', 3, 'Lahore Adda'), ('ER01', 4, 'Hashtnagri'), ('ER01', 5, 'Malik Saad Shaheed'), ('ER01', 6, 'Khyber Bazar'), ('ER01', 7, 'Dabgari Gardens'), ('ER01', 8, 'Saddar Bazar'), ('ER01', 9, 'University of Peshawar'), ('ER01', 10, 'Mall of Hayatabad'), ('ER01', 11, 'Karkhano Market'),
    ('SR02', 1, 'Chamkani'), ('SR02', 2, 'Sardar Garhi'), ('SR02', 3, 'Chughal Pura'), ('SR02', 4, 'Faisal Colony'), ('SR02', 5, 'Old Haji Camp'), ('SR02', 6, 'Lahore Adda'), ('SR02', 7, 'Gulbahar Chowk'), ('SR02', 8, 'Hashtnagri'), ('SR02', 9, 'Malik Saad Shaheed'), ('SR02', 10, 'Khyber Bazar'), ('SR02', 11, 'Shoba Bazar'), ('SR02', 12, 'Dabgari Gardens'), ('SR02', 13, 'Railway Station'), ('SR02', 14, 'FC Chowk'), ('SR02', 15, 'Saddar Bazar'), ('SR02', 16, 'Mall Road'), ('SR02', 17, 'Tehkal Payyan'), ('SR02', 18, 'Tehkal Bala'), ('SR02', 19, 'Abdara Road'), ('SR02', 20, 'University Town'), ('SR02', 21, 'University of Peshawar'), ('SR02', 22, 'Islamia College'), ('SR02', 23, 'Board Bazar'), ('SR02', 24, 'Mall of Hayatabad'), ('SR02', 25, 'Bab-e-Peshawar'), ('SR02', 26, 'Hayatabad Phase 3'), ('SR02', 27, 'Tatara Park'), ('SR02', 28, 'PDA'), ('SR02', 29, 'Hospital Chowk'), ('SR02', 30, 'Karkhano Market'),
    ('DR03A', 1, 'Dabgari Gardens'), ('DR03A', 2, 'Shaheed Saqib Ghani School'), ('DR03A', 3, 'Civil Quarters'), ('DR03A', 4, 'Bhana Marri'), ('DR03A', 5, 'Civil Colony'), ('DR03A', 6, 'Technical College'), ('DR03A', 7, 'Landi Arbab'), ('DR03A', 8, 'Ghari Qamar Din'), ('DR03A', 9, 'Gulshan Rehman Colony'), ('DR03A', 10, 'Kohat Adda'),
    ('DR03B', 1, 'Malik Saad Shaheed'), ('DR03B', 2, 'Bacha Khan Chowk'), ('DR03B', 3, 'Shahi Bagh'), ('DR03B', 4, 'Eid Gah'), ('DR03B', 5, 'Charsadda Adda'), ('DR03B', 6, 'Shaheed Tehseen Chowk'), ('DR03B', 7, 'Budhni Pul'), ('DR03B', 8, 'Nishat Mill'), ('DR03B', 9, 'Landey Sarrak'), ('DR03B', 10, 'Shero Jhangi'), ('DR03B', 11, 'Habib Abad'), ('DR03B', 12, 'Ibrahim Abad'), ('DR03B', 13, 'Bakhshu Pul'), ('DR03B', 14, 'Muslim Abad'), ('DR03B', 15, 'Nasapa'), ('DR03B', 16, 'Nasapa Bala'), ('DR03B', 17, 'Sugar Mill'), ('DR03B', 18, 'Sewan'), ('DR03B', 19, 'Faqeer Abad'), ('DR03B', 20, 'Khazana'), ('DR03B', 21, 'Tauda'), ('DR03B', 22, 'Wahid Ghari'), ('DR03B', 23, 'Shah Alam Pul'),
    ('DR05', 1, 'Mall of Hayatabad'), ('DR05', 2, 'Bakht Khan Market'), ('DR05', 3, 'Basharat Market'), ('DR05', 4, 'Yousafzai Market'), ('DR05', 5, 'Ring Road Bridge'), ('DR05', 6, 'Itwar Bazar'), ('DR05', 7, 'Achini'), ('DR05', 8, 'Shalman Park'), ('DR05', 9, 'Phase 6 Terminal'),
    ('DR06', 1, 'Mall of Hayatabad'), ('DR06', 2, 'Bab-e-Peshawar'), ('DR06', 3, 'Hayatabad Phase 3'), ('DR06', 4, 'Bagh-e-Naran'), ('DR06', 5, 'Iqra University'), ('DR06', 6, 'Itwar Bazar'), ('DR06', 7, 'Zarghuni Masjid'), ('DR06', 8, 'Lalazar'), ('DR06', 9, 'Malik Saad Market'), ('DR06', 10, 'Rehman Baba Market'), ('DR06', 11, 'Haji Camp'), ('DR06', 12, 'Judicial Complex'), ('DR06', 13, 'Madrassa'), ('DR06', 14, 'Football Ground'), ('DR06', 15, 'IMSciences'), ('DR06', 16, 'Phase 7 Terminal'),
    ('DR07', 1, 'Karkhano Market'), ('DR07', 2, 'Karkhano Chowk'), ('DR07', 3, 'TEVTA'), ('DR07', 4, 'Fort'), ('DR07', 5, 'Industrial Estate'), ('DR07', 6, 'Fast University'), ('DR07', 7, 'Shamali Market'), ('DR07', 8, 'Lalazar'), ('DR07', 9, 'Zarghuni Masjid'), ('DR07', 10, 'Deans Heights'), ('DR07', 11, 'Phase 7 Chowk'), ('DR07', 12, 'Gol Chowk'), ('DR07', 13, 'Bangash Market'), ('DR07', 14, 'Phase 7 Terminal'),
    ('SR08', 1, 'Gulbahar Chowk'), ('SR08', 2, 'Hashtnagri'), ('SR08', 3, 'Malik Saad Shaheed'), ('SR08', 4, 'Khyber Bazar'), ('SR08', 5, 'Shoba Bazar'), ('SR08', 6, 'Dabgari Gardens'), ('SR08', 7, 'Railway Station'), ('SR08', 8, 'FC Chowk'), ('SR08', 9, 'Saddar Bazar'), ('SR08', 10, 'Mall Road'), ('SR08', 11, 'Tehkal Payyan'), ('SR08', 12, 'Tehkal Bala'), ('SR08', 13, 'Abdara Road'), ('SR08', 14, 'University Town'), ('SR08', 15, 'University of Peshawar'), ('SR08', 16, 'Islamia College'), ('SR08', 17, 'Board Bazar'), ('SR08', 18, 'Mall of Hayatabad'),
    ('ER09', 1, 'Gulbahar Chowk'), ('ER09', 2, 'Malik Saad Shaheed'), ('ER09', 3, 'Dabgari Gardens'), ('ER09', 4, 'Saddar Bazar'), ('ER09', 5, 'Abdara Road'), ('ER09', 6, 'University of Peshawar'), ('ER09', 7, 'Board Bazar'), ('ER09', 8, 'Basharat Market'), ('ER09', 9, 'Yousafzai Market'), ('ER09', 10, 'Ring Road Bridge'), ('ER09', 11, 'Zarghuni Masjid'), ('ER09', 12, 'Gol Chowk'), ('ER09', 13, 'Nawab Market'), ('ER09', 14, 'Phase 6 Terminal'),
    ('ER10', 1, 'Hospital Chowk'), ('ER10', 2, 'Hayatabad Phase 3'), ('ER10', 3, 'Mall of Hayatabad'), ('ER10', 4, 'University of Peshawar'), ('ER10', 5, 'Tehkal Payyan'), ('ER10', 6, 'Saddar Bazar'), ('ER10', 7, 'Bhana Marri'), ('ER10', 8, 'Technical College'), ('ER10', 9, 'Ghari Qamar Din'), ('ER10', 10, 'Kohat Adda')
)
SELECT DISTINCT station_name FROM route_stop;

INSERT INTO Route_Station (route_id, station_id, stop_order)
WITH route_stop(route_code, stop_order, station_name) AS (
    VALUES
    ('ER01', 1, 'Chamkani'), ('ER01', 2, 'Sardar Garhi'), ('ER01', 3, 'Lahore Adda'), ('ER01', 4, 'Hashtnagri'), ('ER01', 5, 'Malik Saad Shaheed'), ('ER01', 6, 'Khyber Bazar'), ('ER01', 7, 'Dabgari Gardens'), ('ER01', 8, 'Saddar Bazar'), ('ER01', 9, 'University of Peshawar'), ('ER01', 10, 'Mall of Hayatabad'), ('ER01', 11, 'Karkhano Market'),
    ('SR02', 1, 'Chamkani'), ('SR02', 2, 'Sardar Garhi'), ('SR02', 3, 'Chughal Pura'), ('SR02', 4, 'Faisal Colony'), ('SR02', 5, 'Old Haji Camp'), ('SR02', 6, 'Lahore Adda'), ('SR02', 7, 'Gulbahar Chowk'), ('SR02', 8, 'Hashtnagri'), ('SR02', 9, 'Malik Saad Shaheed'), ('SR02', 10, 'Khyber Bazar'), ('SR02', 11, 'Shoba Bazar'), ('SR02', 12, 'Dabgari Gardens'), ('SR02', 13, 'Railway Station'), ('SR02', 14, 'FC Chowk'), ('SR02', 15, 'Saddar Bazar'), ('SR02', 16, 'Mall Road'), ('SR02', 17, 'Tehkal Payyan'), ('SR02', 18, 'Tehkal Bala'), ('SR02', 19, 'Abdara Road'), ('SR02', 20, 'University Town'), ('SR02', 21, 'University of Peshawar'), ('SR02', 22, 'Islamia College'), ('SR02', 23, 'Board Bazar'), ('SR02', 24, 'Mall of Hayatabad'), ('SR02', 25, 'Bab-e-Peshawar'), ('SR02', 26, 'Hayatabad Phase 3'), ('SR02', 27, 'Tatara Park'), ('SR02', 28, 'PDA'), ('SR02', 29, 'Hospital Chowk'), ('SR02', 30, 'Karkhano Market'),
    ('DR03A', 1, 'Dabgari Gardens'), ('DR03A', 2, 'Shaheed Saqib Ghani School'), ('DR03A', 3, 'Civil Quarters'), ('DR03A', 4, 'Bhana Marri'), ('DR03A', 5, 'Civil Colony'), ('DR03A', 6, 'Technical College'), ('DR03A', 7, 'Landi Arbab'), ('DR03A', 8, 'Ghari Qamar Din'), ('DR03A', 9, 'Gulshan Rehman Colony'), ('DR03A', 10, 'Kohat Adda'),
    ('DR03B', 1, 'Malik Saad Shaheed'), ('DR03B', 2, 'Bacha Khan Chowk'), ('DR03B', 3, 'Shahi Bagh'), ('DR03B', 4, 'Eid Gah'), ('DR03B', 5, 'Charsadda Adda'), ('DR03B', 6, 'Shaheed Tehseen Chowk'), ('DR03B', 7, 'Budhni Pul'), ('DR03B', 8, 'Nishat Mill'), ('DR03B', 9, 'Landey Sarrak'), ('DR03B', 10, 'Shero Jhangi'), ('DR03B', 11, 'Habib Abad'), ('DR03B', 12, 'Ibrahim Abad'), ('DR03B', 13, 'Bakhshu Pul'), ('DR03B', 14, 'Muslim Abad'), ('DR03B', 15, 'Nasapa'), ('DR03B', 16, 'Nasapa Bala'), ('DR03B', 17, 'Sugar Mill'), ('DR03B', 18, 'Sewan'), ('DR03B', 19, 'Faqeer Abad'), ('DR03B', 20, 'Khazana'), ('DR03B', 21, 'Tauda'), ('DR03B', 22, 'Wahid Ghari'), ('DR03B', 23, 'Shah Alam Pul'),
    ('DR05', 1, 'Mall of Hayatabad'), ('DR05', 2, 'Bakht Khan Market'), ('DR05', 3, 'Basharat Market'), ('DR05', 4, 'Yousafzai Market'), ('DR05', 5, 'Ring Road Bridge'), ('DR05', 6, 'Itwar Bazar'), ('DR05', 7, 'Achini'), ('DR05', 8, 'Shalman Park'), ('DR05', 9, 'Phase 6 Terminal'),
    ('DR06', 1, 'Mall of Hayatabad'), ('DR06', 2, 'Bab-e-Peshawar'), ('DR06', 3, 'Hayatabad Phase 3'), ('DR06', 4, 'Bagh-e-Naran'), ('DR06', 5, 'Iqra University'), ('DR06', 6, 'Itwar Bazar'), ('DR06', 7, 'Zarghuni Masjid'), ('DR06', 8, 'Lalazar'), ('DR06', 9, 'Malik Saad Market'), ('DR06', 10, 'Rehman Baba Market'), ('DR06', 11, 'Haji Camp'), ('DR06', 12, 'Judicial Complex'), ('DR06', 13, 'Madrassa'), ('DR06', 14, 'Football Ground'), ('DR06', 15, 'IMSciences'), ('DR06', 16, 'Phase 7 Terminal'),
    ('DR07', 1, 'Karkhano Market'), ('DR07', 2, 'Karkhano Chowk'), ('DR07', 3, 'TEVTA'), ('DR07', 4, 'Fort'), ('DR07', 5, 'Industrial Estate'), ('DR07', 6, 'Fast University'), ('DR07', 7, 'Shamali Market'), ('DR07', 8, 'Lalazar'), ('DR07', 9, 'Zarghuni Masjid'), ('DR07', 10, 'Deans Heights'), ('DR07', 11, 'Phase 7 Chowk'), ('DR07', 12, 'Gol Chowk'), ('DR07', 13, 'Bangash Market'), ('DR07', 14, 'Phase 7 Terminal'),
    ('SR08', 1, 'Gulbahar Chowk'), ('SR08', 2, 'Hashtnagri'), ('SR08', 3, 'Malik Saad Shaheed'), ('SR08', 4, 'Khyber Bazar'), ('SR08', 5, 'Shoba Bazar'), ('SR08', 6, 'Dabgari Gardens'), ('SR08', 7, 'Railway Station'), ('SR08', 8, 'FC Chowk'), ('SR08', 9, 'Saddar Bazar'), ('SR08', 10, 'Mall Road'), ('SR08', 11, 'Tehkal Payyan'), ('SR08', 12, 'Tehkal Bala'), ('SR08', 13, 'Abdara Road'), ('SR08', 14, 'University Town'), ('SR08', 15, 'University of Peshawar'), ('SR08', 16, 'Islamia College'), ('SR08', 17, 'Board Bazar'), ('SR08', 18, 'Mall of Hayatabad'),
    ('ER09', 1, 'Gulbahar Chowk'), ('ER09', 2, 'Malik Saad Shaheed'), ('ER09', 3, 'Dabgari Gardens'), ('ER09', 4, 'Saddar Bazar'), ('ER09', 5, 'Abdara Road'), ('ER09', 6, 'University of Peshawar'), ('ER09', 7, 'Board Bazar'), ('ER09', 8, 'Basharat Market'), ('ER09', 9, 'Yousafzai Market'), ('ER09', 10, 'Ring Road Bridge'), ('ER09', 11, 'Zarghuni Masjid'), ('ER09', 12, 'Gol Chowk'), ('ER09', 13, 'Nawab Market'), ('ER09', 14, 'Phase 6 Terminal'),
    ('ER10', 1, 'Hospital Chowk'), ('ER10', 2, 'Hayatabad Phase 3'), ('ER10', 3, 'Mall of Hayatabad'), ('ER10', 4, 'University of Peshawar'), ('ER10', 5, 'Tehkal Payyan'), ('ER10', 6, 'Saddar Bazar'), ('ER10', 7, 'Bhana Marri'), ('ER10', 8, 'Technical College'), ('ER10', 9, 'Ghari Qamar Din'), ('ER10', 10, 'Kohat Adda')
)
SELECT r.route_id, s.station_id, rs.stop_order
FROM route_stop rs
JOIN Route r ON r.route_code = rs.route_code
JOIN Station s ON s.station_name = rs.station_name;

INSERT INTO Recharge (passenger_id, amount, payment_method, status)
SELECT passenger_id, 500, 'EasyPaisa', 'success'
FROM Passenger
WHERE email = 'demo@brt.local';

-- DQL EXAMPLES
-- 1. List every route with its platform, fare rule, and frequency.
SELECT route_code, route_name, platform, fare_per_stop, headway_min || '-' || headway_max || ' min' AS frequency
FROM Route
ORDER BY route_code;

-- 2. Find all direct routes between two stations and calculate fare.
SELECT r.route_code, r.route_name, r.platform,
       ABS(destination.stop_order - origin.stop_order) AS stops,
       ABS(destination.stop_order - origin.stop_order) * r.fare_per_stop AS fare
FROM Route r
JOIN Route_Station origin ON origin.route_id = r.route_id
JOIN Station origin_station ON origin_station.station_id = origin.station_id
JOIN Route_Station destination ON destination.route_id = r.route_id
JOIN Station destination_station ON destination_station.station_id = destination.station_id
WHERE origin_station.station_name = 'Chamkani'
  AND destination_station.station_name = 'Karkhano Market'
  AND origin.stop_order <> destination.stop_order
ORDER BY stops;

-- 3. Show live bus occupancy from schedule, bus, and route tables.
SELECT b.bus_number, r.route_code, r.route_name, r.platform,
       ROUND((b.current_passengers * 100.0) / b.capacity, 0) AS occupancy_percent
FROM Bus b
JOIN Schedule s ON s.bus_id = b.bus_id
JOIN Route r ON r.route_id = s.route_id
WHERE b.status = 'active';
