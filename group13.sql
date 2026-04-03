

PRAGMA foreign_keys = ON;
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
    status      TEXT DEFAULT 'active' CHECK(status IN ('active', 'maintenance', 'inactive')),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    route_name  TEXT NOT NULL,
    route_type  TEXT NOT NULL CHECK(route_type IN ('standard', 'express')),
    total_stops INTEGER NOT NULL,
    direction   TEXT NOT NULL CHECK(direction IN ('Inbound', 'Outbound')),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- TABLE: Station
CREATE TABLE Station (
    station_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    station_name    TEXT NOT NULL,
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
    r.route_name,
    r.direction,
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
    r.route_name
FROM Passenger p
JOIN Ticket   t ON p.passenger_id  = t.passenger_id
LEFT JOIN Schedule s ON t.schedule_id  = s.schedule_id
LEFT JOIN Route    r ON s.route_id     = r.route_id;

-- Ordered stations per route
CREATE VIEW v_route_stations AS
SELECT
    r.route_id,
    r.route_name,
    r.route_type,
    r.direction,
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
