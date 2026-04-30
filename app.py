import os
import sqlite3
from flask import Flask, jsonify, render_template, request, redirect, url_for, flash, session
from werkzeug.security import generate_password_hash, check_password_hash
from functools import wraps

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
DATABASE_PATH = os.path.join(BASE_DIR, 'database.db')

app = Flask(__name__, template_folder=BASE_DIR)
app.config['SECRET_KEY'] = 'your-secret-key-change-this-in-production'

ERD_TABLES = [
    {
        'name': 'Passenger',
        'purpose': 'Passenger accounts, login details, phone number, and card balance.',
        'sample_sql': '''
            SELECT passenger_id, name, email, phone_number, card_balance, created_at
            FROM Passenger
            ORDER BY passenger_id
            LIMIT 5
        '''
    },
    {
        'name': 'Admin',
        'purpose': 'System administrators who can manage complaints and notifications.',
        'sample_sql': '''
            SELECT admin_id, name, email, created_at
            FROM Admin
            ORDER BY admin_id
            LIMIT 5
        '''
    },
    {
        'name': 'Bus',
        'purpose': 'Bus fleet records, type, status, capacity, and current passengers.',
        'sample_sql': '''
            SELECT bus_id, bus_number, bus_type, capacity, current_passengers, status
            FROM Bus
            ORDER BY bus_id
            LIMIT 5
        '''
    },
    {
        'name': 'Driver',
        'purpose': 'Driver information, phone number, license number, and work status.',
        'sample_sql': '''
            SELECT driver_id, name, phone_number, license_number, status
            FROM Driver
            ORDER BY driver_id
            LIMIT 5
        '''
    },
    {
        'name': 'Route',
        'purpose': 'BRT route master data including route code, platform, fare, and frequency.',
        'sample_sql': '''
            SELECT route_id, route_code, route_name, route_type, total_stops, platform, fare_per_stop
            FROM Route
            ORDER BY route_code
            LIMIT 5
        '''
    },
    {
        'name': 'Station',
        'purpose': 'Station names and location areas used by all routes.',
        'sample_sql': '''
            SELECT station_id, station_name, location_area
            FROM Station
            ORDER BY station_id
            LIMIT 5
        '''
    },
    {
        'name': 'Route_Station',
        'purpose': 'Junction table that connects each route to its stations in stop order.',
        'sample_sql': '''
            SELECT route_station_id, route_id, station_id, stop_order
            FROM Route_Station
            ORDER BY route_id, stop_order
            LIMIT 5
        '''
    },
    {
        'name': 'Schedule',
        'purpose': 'Schedules that assign buses and drivers to routes with departure times.',
        'sample_sql': '''
            SELECT schedule_id, bus_id, route_id, driver_id, departure_time, arrival_time, status
            FROM Schedule
            ORDER BY schedule_id
            LIMIT 5
        '''
    },
    {
        'name': 'Ticket',
        'purpose': 'Passenger tickets, fare paid, journey stations, and status.',
        'sample_sql': '''
            SELECT ticket_id, passenger_id, schedule_id, fixed_fare, start_station, end_station, status
            FROM Ticket
            ORDER BY ticket_id DESC
            LIMIT 5
        '''
    },
    {
        'name': 'Recharge',
        'purpose': 'Passenger card top-up transactions and payment status.',
        'sample_sql': '''
            SELECT recharge_id, passenger_id, amount, payment_method, status, recharge_time
            FROM Recharge
            ORDER BY recharge_id DESC
            LIMIT 5
        '''
    },
    {
        'name': 'Complaint',
        'purpose': 'Passenger complaints, assigned admin, response, and resolution status.',
        'sample_sql': '''
            SELECT complaint_id, passenger_id, admin_id, complaint_text, status, response_text
            FROM Complaint
            ORDER BY complaint_id DESC
            LIMIT 5
        '''
    },
    {
        'name': 'Notification',
        'purpose': 'Passenger notifications created by system actions such as ticket booking.',
        'sample_sql': '''
            SELECT notification_id, admin_id, passenger_id, message, type, is_read, created_at
            FROM Notification
            ORDER BY notification_id DESC
            LIMIT 5
        '''
    },
]


def get_db():
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute('PRAGMA foreign_keys = ON')
    return conn


def query_all(sql, params=()):
    with get_db() as conn:
        rows = conn.execute(sql, params).fetchall()
    return [dict(row) for row in rows]


def query_one(sql, params=()):
    with get_db() as conn:
        row = conn.execute(sql, params).fetchone()
    return dict(row) if row else None


def execute(sql, params=()):
    with get_db() as conn:
        cursor = conn.execute(sql, params)
        conn.commit()
        return cursor.lastrowid


def initialize_database():
    needs_rebuild = not os.path.exists(DATABASE_PATH)
    if not needs_rebuild:
        try:
            route_columns = query_all('PRAGMA table_info(Route)')
            column_names = {column['name'] for column in route_columns}
            route_count = query_one('SELECT COUNT(*) AS total FROM Route')
            needs_rebuild = 'route_code' not in column_names or route_count['total'] == 0
        except sqlite3.Error:
            needs_rebuild = True
    if not needs_rebuild:
        return

    schema_path = os.path.join(BASE_DIR, 'group13.sql')
    with open(schema_path, 'r', encoding='utf-8') as schema_file:
        schema_sql = schema_file.read()
    with get_db() as conn:
        conn.executescript(schema_sql)
        conn.commit()


def current_passenger():
    if 'passenger_id' not in session:
        return None
    return query_one(
        'SELECT passenger_id, name, email, phone_number, card_balance FROM Passenger WHERE passenger_id = ?',
        (session['passenger_id'],)
    )

# Login required decorator
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'passenger_id' not in session:
            flash('Please login to access this page', 'error')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# Routes
@app.route('/')
def index():
    if 'passenger_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/signup', methods=['GET', 'POST'])
def signup():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        email = request.form.get('email', '').strip()
        phone_number = request.form.get('phone_number', '').strip()
        password = request.form.get('password', '')
        confirm_password = request.form.get('confirm_password', '')
        
        # Validation
        if not username or not email or not password:
            flash('All fields are required', 'error')
            return render_template('signup.html')
        
        if password != confirm_password:
            flash('Passwords do not match', 'error')
            return render_template('signup.html')
        
        if len(password) < 6:
            flash('Password must be at least 6 characters', 'error')
            return render_template('signup.html')
        
        existing_user = query_one(
            'SELECT passenger_id FROM Passenger WHERE lower(name) = lower(?) OR lower(email) = lower(?)',
            (username, email)
        )
        
        if existing_user:
            flash('Username or email already exists', 'error')
            return render_template('signup.html')
        
        try:
            execute(
                '''
                INSERT INTO Passenger (name, email, phone_number, password, card_balance)
                VALUES (?, ?, ?, ?, 250.0)
                ''',
                (username, email, phone_number or None, generate_password_hash(password))
            )
            flash('Account created successfully! Please login.', 'success')
            return redirect(url_for('login'))
        except Exception as e:
            flash('Error creating account. Please try again.', 'error')
            return render_template('signup.html')
    
    return render_template('signup.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        
        if not username or not password:
            flash('Please enter username and password', 'error')
            return render_template('login.html')
        
        passenger = query_one(
            'SELECT passenger_id, name, password FROM Passenger WHERE lower(name) = lower(?) OR lower(email) = lower(?)',
            (username, username)
        )
        
        if passenger and check_password_hash(passenger['password'], password):
            session['passenger_id'] = passenger['passenger_id']
            session['username'] = passenger['name']
            flash(f'Welcome back, {passenger["name"]}!', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('Invalid username or password', 'error')
            return render_template('login.html')
    
    return render_template('login.html')

@app.route('/dashboard')
@login_required
def dashboard():
    return render_template('dashboard.html', username=session.get('username'))


@app.get('/api/stations')
@login_required
def api_stations():
    stations = query_all(
        '''
        SELECT station_id, station_name, location_area
        FROM Station
        ORDER BY station_name
        '''
    )
    return jsonify(stations)


@app.get('/api/routes')
@login_required
def api_routes():
    routes = query_all(
        '''
        SELECT
            route_id,
            route_code,
            route_name,
            route_type,
            direction,
            platform,
            headway_min,
            headway_max,
            fare_per_stop,
            total_stops
        FROM Route
        ORDER BY route_code
        '''
    )
    return jsonify(routes)


@app.get('/api/trips')
@login_required
def api_trips():
    start = request.args.get('start', '').strip()
    end = request.args.get('end', '').strip()
    if not start or not end:
        return jsonify({'error': 'Start and destination stations are required'}), 400
    if start == end:
        return jsonify({'error': 'Start and destination cannot be the same'}), 400

    routes = query_all(
        '''
        SELECT
            r.route_id,
            r.route_code,
            r.route_name,
            r.route_type,
            r.platform,
            r.headway_min,
            r.headway_max,
            r.fare_per_stop,
            r.distance_per_stop_km,
            r.minutes_per_stop,
            start_rs.stop_order AS start_order,
            end_rs.stop_order AS end_order,
            ABS(end_rs.stop_order - start_rs.stop_order) AS stop_count,
            ROUND(ABS(end_rs.stop_order - start_rs.stop_order) * r.fare_per_stop, 2) AS fare,
            ROUND(ABS(end_rs.stop_order - start_rs.stop_order) * r.distance_per_stop_km, 1) AS distance_km,
            ABS(end_rs.stop_order - start_rs.stop_order) * r.minutes_per_stop AS travel_minutes
        FROM Route r
        JOIN Route_Station start_rs ON start_rs.route_id = r.route_id
        JOIN Station start_station ON start_station.station_id = start_rs.station_id
        JOIN Route_Station end_rs ON end_rs.route_id = r.route_id
        JOIN Station end_station ON end_station.station_id = end_rs.station_id
        WHERE start_station.station_name = ?
          AND end_station.station_name = ?
          AND start_rs.stop_order <> end_rs.stop_order
        ORDER BY stop_count, r.route_code
        ''',
        (start, end)
    )

    for route in routes:
        lower_order = min(route['start_order'], route['end_order'])
        upper_order = max(route['start_order'], route['end_order'])
        stations = query_all(
            '''
            SELECT st.station_name, rs.stop_order
            FROM Route_Station rs
            JOIN Station st ON st.station_id = rs.station_id
            WHERE rs.route_id = ?
              AND rs.stop_order BETWEEN ? AND ?
            ORDER BY rs.stop_order
            ''',
            (route['route_id'], lower_order, upper_order)
        )
        if route['end_order'] < route['start_order']:
            stations.reverse()
        route['stations'] = [station['station_name'] for station in stations]

    return jsonify(routes)


@app.get('/api/capacity')
@login_required
def api_capacity():
    buses = query_all(
        '''
        SELECT
            b.bus_id,
            b.bus_number,
            b.capacity,
            b.current_passengers,
            b.status,
            r.route_code,
            r.route_name,
            r.platform,
            r.headway_min,
            r.headway_max,
            ROUND((b.current_passengers * 100.0) / b.capacity, 0) AS occupancy
        FROM Bus b
        JOIN Schedule s ON s.bus_id = b.bus_id
        JOIN Route r ON r.route_id = s.route_id
        WHERE b.status = 'active'
          AND s.status IN ('scheduled', 'active')
        GROUP BY b.bus_id
        ORDER BY r.route_code, b.bus_number
        '''
    )
    return jsonify(buses)


@app.get('/api/me')
@login_required
def api_me():
    return jsonify(current_passenger())


@app.post('/api/tickets')
@login_required
def api_create_ticket():
    data = request.get_json(silent=True) or {}
    route_id = data.get('route_id')
    start = data.get('start')
    end = data.get('end')
    fare = float(data.get('fare') or 0)
    if not route_id or not start or not end or fare <= 0:
        return jsonify({'error': 'Route, stations, and fare are required'}), 400

    passenger = current_passenger()
    if passenger['card_balance'] < fare:
        return jsonify({'error': 'Insufficient card balance. Please recharge first.'}), 400

    schedule = query_one(
        '''
        SELECT schedule_id
        FROM Schedule
        WHERE route_id = ? AND status IN ('scheduled', 'active')
        ORDER BY departure_time
        LIMIT 1
        ''',
        (route_id,)
    )
    if not schedule:
        return jsonify({'error': 'No active schedule is available for this route'}), 404

    with get_db() as conn:
        conn.execute(
            'UPDATE Passenger SET card_balance = card_balance - ? WHERE passenger_id = ?',
            (fare, session['passenger_id'])
        )
        cursor = conn.execute(
            '''
            INSERT INTO Ticket (passenger_id, schedule_id, fixed_fare, start_station, end_station)
            VALUES (?, ?, ?, ?, ?)
            ''',
            (session['passenger_id'], schedule['schedule_id'], fare, start, end)
        )
        conn.execute(
            '''
            INSERT INTO Notification (passenger_id, message, type)
            VALUES (?, ?, 'ticket')
            ''',
            (session['passenger_id'], f'Ticket booked from {start} to {end} for PKR {fare:.0f}')
        )
        conn.commit()

    passenger = current_passenger()
    return jsonify({'ticket_id': cursor.lastrowid, 'card_balance': passenger['card_balance']})


@app.get('/api/tickets')
@login_required
def api_tickets():
    tickets = query_all(
        '''
        SELECT ticket_id, purchase_time, ticket_status, fixed_fare, route_name,
               start_station, end_station, departure_time, arrival_time
        FROM v_passenger_tickets
        WHERE passenger_id = ?
        ORDER BY purchase_time DESC
        LIMIT 10
        ''',
        (session['passenger_id'],)
    )
    return jsonify(tickets)


DATABASE_TABLES = [
    {
        'name': 'Passenger',
        'description': 'Passengers who use the BRT system, including login, phone, and card balance.',
        'columns': ['passenger_id', 'name', 'email', 'phone_number', 'card_balance', 'created_at'],
        'sample_query': '''
            SELECT passenger_id, name, email, phone_number, card_balance, created_at
            FROM Passenger
            ORDER BY passenger_id
            LIMIT 8
        '''
    },
    {
        'name': 'Admin',
        'description': 'System administrators who can manage complaints and notifications.',
        'columns': ['admin_id', 'name', 'email', 'created_at'],
        'sample_query': '''
            SELECT admin_id, name, email, created_at
            FROM Admin
            ORDER BY admin_id
            LIMIT 8
        '''
    },
    {
        'name': 'Bus',
        'description': 'Buses with type, status, capacity, and current passenger load.',
        'columns': ['bus_id', 'bus_number', 'bus_type', 'capacity', 'current_passengers', 'status'],
        'sample_query': '''
            SELECT bus_id, bus_number, bus_type, capacity, current_passengers, status
            FROM Bus
            ORDER BY bus_id
            LIMIT 8
        '''
    },
    {
        'name': 'Driver',
        'description': 'Drivers assigned to schedules.',
        'columns': ['driver_id', 'name', 'phone_number', 'license_number', 'status'],
        'sample_query': '''
            SELECT driver_id, name, phone_number, license_number, status
            FROM Driver
            ORDER BY driver_id
            LIMIT 8
        '''
    },
    {
        'name': 'Route',
        'description': 'Routes from the real station data, including platform, headway, and fare rule.',
        'columns': ['route_id', 'route_code', 'route_name', 'route_type', 'total_stops', 'platform', 'fare_per_stop'],
        'sample_query': '''
            SELECT route_id, route_code, route_name, route_type, total_stops, platform, fare_per_stop
            FROM Route
            ORDER BY route_code
            LIMIT 8
        '''
    },
    {
        'name': 'Station',
        'description': 'Unique BRT station names used by all routes.',
        'columns': ['station_id', 'station_name', 'location_area', 'created_at'],
        'sample_query': '''
            SELECT station_id, station_name, location_area, created_at
            FROM Station
            ORDER BY station_name
            LIMIT 8
        '''
    },
    {
        'name': 'Route_Station',
        'description': 'Junction table that stores route-to-station relationships and stop order.',
        'columns': ['route_station_id', 'route_code', 'station_name', 'stop_order'],
        'sample_query': '''
            SELECT rs.route_station_id, r.route_code, st.station_name, rs.stop_order
            FROM Route_Station rs
            JOIN Route r ON r.route_id = rs.route_id
            JOIN Station st ON st.station_id = rs.station_id
            ORDER BY r.route_code, rs.stop_order
            LIMIT 8
        '''
    },
    {
        'name': 'Schedule',
        'description': 'Schedules connect a bus, driver, and route with timing and operating days.',
        'columns': ['schedule_id', 'bus_number', 'route_code', 'driver_name', 'departure_time', 'arrival_time', 'status'],
        'sample_query': '''
            SELECT s.schedule_id, b.bus_number, r.route_code, d.name AS driver_name,
                   s.departure_time, s.arrival_time, s.status
            FROM Schedule s
            JOIN Bus b ON b.bus_id = s.bus_id
            JOIN Route r ON r.route_id = s.route_id
            JOIN Driver d ON d.driver_id = s.driver_id
            ORDER BY s.schedule_id
            LIMIT 8
        '''
    },
    {
        'name': 'Ticket',
        'description': 'Tickets bought by passengers for a scheduled route.',
        'columns': ['ticket_id', 'passenger_name', 'route_code', 'fixed_fare', 'start_station', 'end_station', 'status'],
        'sample_query': '''
            SELECT t.ticket_id, p.name AS passenger_name, r.route_code, t.fixed_fare,
                   t.start_station, t.end_station, t.status
            FROM Ticket t
            JOIN Passenger p ON p.passenger_id = t.passenger_id
            LEFT JOIN Schedule s ON s.schedule_id = t.schedule_id
            LEFT JOIN Route r ON r.route_id = s.route_id
            ORDER BY t.ticket_id DESC
            LIMIT 8
        '''
    },
    {
        'name': 'Recharge',
        'description': 'Passenger card top-up transactions.',
        'columns': ['recharge_id', 'passenger_name', 'amount', 'payment_method', 'status', 'recharge_time'],
        'sample_query': '''
            SELECT r.recharge_id, p.name AS passenger_name, r.amount, r.payment_method,
                   r.status, r.recharge_time
            FROM Recharge r
            JOIN Passenger p ON p.passenger_id = r.passenger_id
            ORDER BY r.recharge_id DESC
            LIMIT 8
        '''
    },
    {
        'name': 'Complaint',
        'description': 'Passenger complaints and admin responses.',
        'columns': ['complaint_id', 'passenger_name', 'assigned_admin', 'complaint_text', 'status'],
        'sample_query': '''
            SELECT c.complaint_id, p.name AS passenger_name, a.name AS assigned_admin,
                   c.complaint_text, c.status
            FROM Complaint c
            JOIN Passenger p ON p.passenger_id = c.passenger_id
            LEFT JOIN Admin a ON a.admin_id = c.admin_id
            ORDER BY c.complaint_id DESC
            LIMIT 8
        '''
    },
    {
        'name': 'Notification',
        'description': 'Messages sent to passengers by the system or admin.',
        'columns': ['notification_id', 'passenger_name', 'message', 'type', 'is_read', 'created_at'],
        'sample_query': '''
            SELECT n.notification_id, p.name AS passenger_name, n.message,
                   n.type, n.is_read, n.created_at
            FROM Notification n
            JOIN Passenger p ON p.passenger_id = n.passenger_id
            ORDER BY n.notification_id DESC
            LIMIT 8
        '''
    }
]


@app.get('/api/database')
@login_required
def api_database():
    tables = []
    for table in DATABASE_TABLES:
        count_row = query_one(f'SELECT COUNT(*) AS total FROM {table["name"]}')
        rows = query_all(table['sample_query'])
        tables.append({
            'name': table['name'],
            'description': table['description'],
            'columns': table['columns'],
            'row_count': count_row['total'],
            'rows': rows,
        })
    return jsonify({'tables': tables})

@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out', 'info')
    return redirect(url_for('login'))

initialize_database()

if __name__ == '__main__':
    app.run(debug=True)