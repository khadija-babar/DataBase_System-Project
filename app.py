import os
import sqlite3
from functools import wraps

from flask import Flask, flash, jsonify, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash

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
            route_column_names = {column['name'] for column in route_columns}
            driver_columns = query_all('PRAGMA table_info(Driver)')
            driver_column_names = {column['name'] for column in driver_columns}
            required_route_columns = {'route_code', 'platform', 'headway_min', 'headway_max'}
            required_driver_columns = {'password'}
            route_count = query_one('SELECT COUNT(*) AS total FROM Route')
            needs_rebuild = (
                not required_route_columns.issubset(route_column_names)
                or not required_driver_columns.issubset(driver_column_names)
                or route_count['total'] == 0
            )
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


def verify_password(stored_password, submitted_password):
    if stored_password and stored_password.startswith(('scrypt:', 'pbkdf2:')):
        return check_password_hash(stored_password, submitted_password)
    return stored_password == submitted_password


def current_passenger():
    if session.get('role') != 'passenger':
        return None
    return query_one(
        'SELECT passenger_id, name, email, phone_number, card_balance FROM Passenger WHERE passenger_id = ?',
        (session.get('user_id'),)
    )


def current_driver():
    if session.get('role') != 'driver':
        return None
    return query_one(
        '''
        SELECT driver_id, name, phone_number, license_number, status
        FROM Driver
        WHERE driver_id = ?
        ''',
        (session.get('user_id'),)
    )


def current_admin():
    if session.get('role') != 'admin':
        return None
    return query_one(
        'SELECT admin_id, name, email FROM Admin WHERE admin_id = ?',
        (session.get('user_id'),)
    )


def role_required(role):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if session.get('role') != role or 'user_id' not in session:
                flash(f'Please login as {role} to continue', 'error')
                return redirect(url_for(f'{role}_login'))
            return f(*args, **kwargs)
        return decorated_function
    return decorator


def api_role_required(role):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if session.get('role') != role or 'user_id' not in session:
                return jsonify({'error': f'{role.title()} login required'}), 401
            return f(*args, **kwargs)
        return decorated_function
    return decorator


def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('Please login to access this page', 'error')
            return redirect(url_for('role_select'))
        return f(*args, **kwargs)
    return decorated_function


def set_session(role, user_id, name):
    session.clear()
    session['role'] = role
    session['user_id'] = user_id
    session['username'] = name

# Routes
@app.route('/')
def index():
    role = session.get('role')
    if role == 'admin':
        return redirect(url_for('admin_dashboard'))
    if role == 'driver':
        return redirect(url_for('driver_dashboard'))
    if role == 'passenger':
        return redirect(url_for('passenger_dashboard'))
    return redirect(url_for('role_select'))


@app.route('/select-role')
def role_select():
    return render_template('index.html')


@app.route('/login')
def legacy_login():
    return redirect(url_for('passenger_login'))


@app.route('/signup')
def legacy_signup():
    return redirect(url_for('signup'))


@app.route('/dashboard')
def legacy_dashboard():
    return redirect(url_for('passenger_dashboard'))


@app.route('/passenger/signup', methods=['GET', 'POST'])
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
            return render_template('passenger_signup.html')
        
        if password != confirm_password:
            flash('Passwords do not match', 'error')
            return render_template('passenger_signup.html')
        
        if len(password) < 6:
            flash('Password must be at least 6 characters', 'error')
            return render_template('passenger_signup.html')
        
        existing_user = query_one(
            'SELECT passenger_id FROM Passenger WHERE lower(name) = lower(?) OR lower(email) = lower(?)',
            (username, email)
        )
        
        if existing_user:
            flash('Username or email already exists', 'error')
            return render_template('passenger_signup.html')
        
        try:
            execute(
                '''
                INSERT INTO Passenger (name, email, phone_number, password, card_balance)
                VALUES (?, ?, ?, ?, 250.0)
                ''',
                (username, email, phone_number or None, generate_password_hash(password))
            )
            flash('Account created successfully! Please login.', 'success')
            return redirect(url_for('passenger_login'))
        except Exception as e:
            flash('Error creating account. Please try again.', 'error')
            return render_template('passenger_signup.html')
    
    return render_template('passenger_signup.html')

@app.route('/passenger/login', methods=['GET', 'POST'])
def passenger_login():
    if request.method == 'POST':
        username = (
            request.form.get('identifier')
            or request.form.get('username')
            or request.form.get('email')
            or ''
        ).strip()
        password = request.form.get('password', '')
        
        if not username or not password:
            flash('Please enter username and password', 'error')
            return render_template('passenger_login.html')
        
        passenger = query_one(
            'SELECT passenger_id, name, password FROM Passenger WHERE lower(name) = lower(?) OR lower(email) = lower(?)',
            (username, username)
        )
        
        if passenger and verify_password(passenger['password'], password):
            set_session('passenger', passenger['passenger_id'], passenger['name'])
            flash(f'Welcome back, {passenger["name"]}!', 'success')
            return redirect(url_for('passenger_dashboard'))
        else:
            flash('Invalid username or password', 'error')
            return render_template('passenger_login.html')
    
    return render_template('passenger_login.html')

@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        email = (
            request.form.get('email')
            or request.form.get('username')
            or request.form.get('identifier')
            or ''
        ).strip()
        password = request.form.get('password', '')
        admin = query_one(
            '''
            SELECT admin_id, name, email, password
            FROM Admin
            WHERE lower(email) = lower(?) OR lower(name) = lower(?)
            ''',
            (email, email)
        )
        if admin and verify_password(admin['password'], password):
            set_session('admin', admin['admin_id'], admin['name'])
            flash(f'Welcome, {admin["name"]}!', 'success')
            return redirect(url_for('admin_dashboard'))
        flash('Invalid admin email or password', 'error')
    return render_template('admin_login.html')


@app.route('/driver/login', methods=['GET', 'POST'])
def driver_login():
    if request.method == 'POST':
        license_number = (
            request.form.get('license_number')
            or request.form.get('username')
            or request.form.get('identifier')
            or ''
        ).strip()
        password = request.form.get('password') or request.form.get('phone_number') or ''
        driver = query_one(
            '''
            SELECT driver_id, name, phone_number, license_number, password, status
            FROM Driver
            WHERE upper(license_number) = upper(?) OR lower(name) = lower(?)
            ''',
            (license_number, license_number)
        )
        password_matches = driver and verify_password(driver['password'], password)
        phone_matches = driver and driver['phone_number'] and driver['phone_number'] == password
        if driver and driver['status'] == 'active' and (password_matches or phone_matches):
            set_session('driver', driver['driver_id'], driver['name'])
            flash(f'Welcome, {driver["name"]}!', 'success')
            return redirect(url_for('driver_dashboard'))
        flash('Invalid driver license or password', 'error')
    return render_template('driver_login.html')


@app.route('/passenger/dashboard')
@role_required('passenger')
def passenger_dashboard():
    return render_template('passenger_dashboard.html', username=session.get('username'))


@app.route('/admin/dashboard')
@role_required('admin')
def admin_dashboard():
    return render_template('admin_dashboard.html', username=session.get('username'))


@app.route('/admin/bus-occupancy/<int:bus_id>')
@role_required('admin')
def admin_bus_occupancy(bus_id):
    return render_template('bus_occupancy.html', username=session.get('username'), bus_id=bus_id)


@app.route('/driver/dashboard')
@role_required('driver')
def driver_dashboard():
    return render_template('driver_dashboard.html', username=session.get('username'))


@app.get('/api/stations')
@api_role_required('passenger')
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
@api_role_required('passenger')
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
@api_role_required('passenger')
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
@api_role_required('passenger')
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


@app.get('/api/passenger/bus-occupancy')
@api_role_required('passenger')
def api_passenger_bus_occupancy():
    return api_capacity()


@app.get('/api/me')
@api_role_required('passenger')
def api_me():
    return jsonify(current_passenger())


@app.get('/api/passenger/dashboard')
@api_role_required('passenger')
def api_passenger_dashboard():
    passenger_id = session['user_id']
    return jsonify({
        'passenger': current_passenger(),
        'tickets': query_all(
            '''
            SELECT ticket_id, purchase_time, ticket_status, fixed_fare, route_name,
                   start_station, end_station
            FROM v_passenger_tickets
            WHERE passenger_id = ?
            ORDER BY purchase_time DESC
            LIMIT 8
            ''',
            (passenger_id,)
        ),
        'notifications': query_all(
            '''
            SELECT notification_id, message, type, is_read, created_at
            FROM Notification
            WHERE passenger_id = ?
            ORDER BY created_at DESC
            LIMIT 8
            ''',
            (passenger_id,)
        ),
        'complaints': query_all(
            '''
            SELECT complaint_id, complaint_text, status, response_text, created_at
            FROM Complaint
            WHERE passenger_id = ?
            ORDER BY created_at DESC
            LIMIT 8
            ''',
            (passenger_id,)
        )
    })


@app.post('/api/tickets')
@api_role_required('passenger')
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
            (fare, session['user_id'])
        )
        cursor = conn.execute(
            '''
            INSERT INTO Ticket (passenger_id, schedule_id, fixed_fare, start_station, end_station)
            VALUES (?, ?, ?, ?, ?)
            ''',
            (session['user_id'], schedule['schedule_id'], fare, start, end)
        )
        conn.execute(
            '''
            INSERT INTO Notification (passenger_id, message, type)
            VALUES (?, ?, 'ticket')
            ''',
            (session['user_id'], f'Ticket booked from {start} to {end} for PKR {fare:.0f}')
        )
        conn.commit()

    passenger = current_passenger()
    return jsonify({'ticket_id': cursor.lastrowid, 'card_balance': passenger['card_balance']})


@app.post('/api/passenger/tickets')
@api_role_required('passenger')
def api_passenger_create_ticket():
    return api_create_ticket()


@app.get('/api/tickets')
@api_role_required('passenger')
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
        (session['user_id'],)
    )
    return jsonify(tickets)


@app.get('/api/passenger/trips')
@api_role_required('passenger')
def api_passenger_trips():
    return api_trips()


@app.post('/api/recharge')
@api_role_required('passenger')
def api_recharge():
    data = request.get_json(silent=True) or {}
    amount = float(data.get('amount') or 0)
    payment_method = data.get('payment_method') or 'EasyPaisa'
    allowed_methods = {'EasyPaisa', 'JazzCash', 'card', 'cash'}
    if amount <= 0 or payment_method not in allowed_methods:
        return jsonify({'error': 'Valid amount and payment method are required'}), 400
    with get_db() as conn:
        conn.execute(
            '''
            INSERT INTO Recharge (passenger_id, amount, payment_method, status)
            VALUES (?, ?, ?, 'success')
            ''',
            (session['user_id'], amount, payment_method)
        )
        conn.execute(
            'UPDATE Passenger SET card_balance = card_balance + ? WHERE passenger_id = ?',
            (amount, session['user_id'])
        )
        conn.commit()
    return jsonify(current_passenger())


@app.post('/api/passenger/recharge')
@api_role_required('passenger')
def api_passenger_recharge():
    return api_recharge()


@app.post('/api/complaints')
@api_role_required('passenger')
def api_create_complaint():
    data = request.get_json(silent=True) or {}
    complaint_text = (data.get('complaint_text') or '').strip()
    if len(complaint_text) < 10:
        return jsonify({'error': 'Complaint must be at least 10 characters'}), 400
    complaint_id = execute(
        'INSERT INTO Complaint (passenger_id, complaint_text, status) VALUES (?, ?, "open")',
        (session['user_id'], complaint_text)
    )
    return jsonify({'complaint_id': complaint_id, 'status': 'open'})


@app.post('/api/passenger/complaints')
@api_role_required('passenger')
def api_passenger_create_complaint():
    return api_create_complaint()


@app.get('/api/passenger/notifications')
@api_role_required('passenger')
def api_passenger_notifications():
    notifications = query_all(
        '''
        SELECT notification_id, message, type, is_read, created_at
        FROM Notification
        WHERE passenger_id = ?
        ORDER BY created_at DESC
        LIMIT 8
        ''',
        (session['user_id'],)
    )
    return jsonify(notifications)


@app.get('/api/driver/overview')
@api_role_required('driver')
def api_driver_overview():
    schedules = api_driver_schedules().get_json()
    return jsonify({
        'driver': current_driver(),
        'assignment_count': len(schedules),
        'schedules': schedules
    })


@app.get('/api/driver/schedules')
@api_role_required('driver')
def api_driver_schedules():
    schedules = query_all(
        '''
        SELECT s.schedule_id, b.bus_number, r.route_code, r.route_name, r.platform,
               s.departure_time, s.arrival_time, s.operating_days, s.status
        FROM Schedule s
        JOIN Bus b ON b.bus_id = s.bus_id
        JOIN Route r ON r.route_id = s.route_id
        WHERE s.driver_id = ?
        ORDER BY s.departure_time
        ''',
        (session['user_id'],)
    )
    return jsonify(schedules)


@app.get('/api/driver/assignments')
@api_role_required('driver')
def api_driver_assignments():
    return api_driver_schedules()


@app.get('/api/driver/route/<int:route_id>/stops')
@api_role_required('driver')
def api_driver_route_stops(route_id):
    stops = query_all(
        '''
        SELECT st.station_name, rs.stop_order
        FROM Route_Station rs
        JOIN Station st ON st.station_id = rs.station_id
        JOIN Schedule s ON s.route_id = rs.route_id
        WHERE rs.route_id = ?
          AND s.driver_id = ?
        ORDER BY rs.stop_order
        ''',
        (route_id, session['user_id'])
    )
    return jsonify(stops)


@app.post('/api/driver/schedules/<int:schedule_id>/status')
@api_role_required('driver')
def api_update_schedule_status(schedule_id):
    data = request.get_json(silent=True) or {}
    status = data.get('status')
    allowed_statuses = {'scheduled', 'active', 'delayed', 'cancelled'}
    if status not in allowed_statuses:
        return jsonify({'error': 'Invalid schedule status'}), 400
    updated = execute(
        '''
        UPDATE Schedule
        SET status = ?
        WHERE schedule_id = ? AND driver_id = ?
        ''',
        (status, schedule_id, session['user_id'])
    )
    return jsonify({'schedule_id': schedule_id, 'status': status, 'updated': updated})


@app.get('/api/admin/overview')
@api_role_required('admin')
def api_admin_overview():
    stats = {
        'passengers': query_one('SELECT COUNT(*) AS total FROM Passenger')['total'],
        'drivers': query_one('SELECT COUNT(*) AS total FROM Driver')['total'],
        'buses': query_one('SELECT COUNT(*) AS total FROM Bus')['total'],
        'active_buses': query_one("SELECT COUNT(*) AS total FROM Bus WHERE status = 'active'")['total'],
        'routes': query_one('SELECT COUNT(*) AS total FROM Route')['total'],
        'open_complaints': query_one("SELECT COUNT(*) AS total FROM Complaint WHERE status IN ('open', 'in_progress')")['total'],
        'tickets': query_one('SELECT COUNT(*) AS total FROM Ticket')['total'],
    }
    schedules = query_all(
        '''
        SELECT s.schedule_id, b.bus_number, r.route_code, r.route_name,
               d.name AS driver_name, s.departure_time, s.arrival_time, s.status
        FROM Schedule s
        JOIN Bus b ON b.bus_id = s.bus_id
        JOIN Route r ON r.route_id = s.route_id
        JOIN Driver d ON d.driver_id = s.driver_id
        ORDER BY s.departure_time
        LIMIT 12
        '''
    )
    complaints = query_all(
        '''
        SELECT c.complaint_id, p.name AS passenger_name, c.complaint_text,
               c.status, c.created_at
        FROM Complaint c
        JOIN Passenger p ON p.passenger_id = c.passenger_id
        WHERE c.status IN ('open', 'in_progress')
        ORDER BY c.created_at DESC
        LIMIT 12
        '''
    )
    return jsonify({'stats': stats, 'schedules': schedules, 'complaints': complaints})


@app.get('/api/admin/routes')
@api_role_required('admin')
def api_admin_routes():
    routes = query_all(
        '''
        SELECT route_code, route_name, route_type, total_stops, platform,
               headway_min, headway_max, fare_per_stop
        FROM Route
        ORDER BY route_code
        '''
    )
    return jsonify(routes)


@app.get('/api/admin/buses')
@api_role_required('admin')
def api_admin_buses():
    buses = query_all(
        '''
        SELECT
            b.bus_id,
            b.bus_number,
            b.bus_type,
            b.capacity,
            b.current_passengers,
            b.status,
            ROUND((b.current_passengers * 100.0) / b.capacity, 0) AS occupancy,
            r.route_code,
            r.route_name,
            r.platform,
            s.departure_time,
            s.arrival_time
        FROM Bus b
        LEFT JOIN Schedule s ON s.bus_id = b.bus_id
        LEFT JOIN Route r ON r.route_id = s.route_id
        GROUP BY b.bus_id
        ORDER BY b.bus_number
        '''
    )
    return jsonify(buses)


@app.get('/api/admin/buses/<int:bus_id>/occupancy')
@api_role_required('admin')
def api_admin_bus_occupancy(bus_id):
    bus = query_one(
        '''
        SELECT
            b.bus_id,
            b.bus_number,
            b.bus_type,
            b.capacity,
            b.current_passengers,
            b.status,
            ROUND((b.current_passengers * 100.0) / b.capacity, 0) AS occupancy,
            r.route_id,
            r.route_code,
            r.route_name,
            r.platform,
            s.schedule_id,
            s.departure_time,
            s.arrival_time,
            s.status AS schedule_status,
            d.name AS driver_name
        FROM Bus b
        LEFT JOIN Schedule s ON s.bus_id = b.bus_id
        LEFT JOIN Route r ON r.route_id = s.route_id
        LEFT JOIN Driver d ON d.driver_id = s.driver_id
        WHERE b.bus_id = ?
        GROUP BY b.bus_id
        ''',
        (bus_id,)
    )
    if not bus:
        return jsonify({'error': 'Bus not found'}), 404

    route_stops = []
    if bus.get('route_id'):
        route_stops = query_all(
            '''
            SELECT st.station_name, rs.stop_order
            FROM Route_Station rs
            JOIN Station st ON st.station_id = rs.station_id
            WHERE rs.route_id = ?
            ORDER BY rs.stop_order
            ''',
            (bus['route_id'],)
        )

    tickets = query_all(
        '''
        SELECT COUNT(*) AS total
        FROM Ticket t
        JOIN Schedule s ON s.schedule_id = t.schedule_id
        WHERE s.bus_id = ? AND t.status = 'active'
        ''',
        (bus_id,)
    )[0]['total']

    return jsonify({'bus': bus, 'route_stops': route_stops, 'active_tickets': tickets})


@app.post('/api/admin/notifications/change')
@api_role_required('admin')
def api_admin_send_change_notification():
    data = request.get_json(silent=True) or {}
    message = (data.get('message') or '').strip()
    if len(message) < 8:
        return jsonify({'error': 'Please write a clear notification message'}), 400

    with get_db() as conn:
        passengers = conn.execute('SELECT passenger_id FROM Passenger').fetchall()
        for passenger in passengers:
            conn.execute(
                '''
                INSERT INTO Notification (admin_id, passenger_id, message, type)
                VALUES (?, ?, ?, 'service_change')
                ''',
                (session['user_id'], passenger['passenger_id'], message)
            )
        conn.commit()

    return jsonify({'sent': len(passengers), 'message': message})


@app.delete('/api/admin/buses/<int:bus_id>')
@api_role_required('admin')
def api_admin_delete_bus(bus_id):
    data = request.get_json(silent=True) or {}
    custom_message = (data.get('message') or '').strip()

    with get_db() as conn:
        bus = conn.execute(
            '''
            SELECT b.bus_id, b.bus_number, r.route_code, r.route_name
            FROM Bus b
            LEFT JOIN Schedule s ON s.bus_id = b.bus_id
            LEFT JOIN Route r ON r.route_id = s.route_id
            WHERE b.bus_id = ?
            GROUP BY b.bus_id
            ''',
            (bus_id,)
        ).fetchone()
        if not bus:
            return jsonify({'error': 'Bus not found'}), 404

        schedule_ids = [
            row['schedule_id']
            for row in conn.execute('SELECT schedule_id FROM Schedule WHERE bus_id = ?', (bus_id,)).fetchall()
        ]
        for schedule_id in schedule_ids:
            conn.execute('UPDATE Ticket SET schedule_id = NULL WHERE schedule_id = ?', (schedule_id,))
        conn.execute('DELETE FROM Schedule WHERE bus_id = ?', (bus_id,))
        conn.execute('DELETE FROM Bus WHERE bus_id = ?', (bus_id,))

        route_text = f" on {bus['route_code']}" if bus['route_code'] else ''
        message = custom_message or f"Bus {bus['bus_number']}{route_text} has been removed from service. Please check available buses before travelling."
        passengers = conn.execute('SELECT passenger_id FROM Passenger').fetchall()
        for passenger in passengers:
            conn.execute(
                '''
                INSERT INTO Notification (admin_id, passenger_id, message, type)
                VALUES (?, ?, ?, 'bus_change')
                ''',
                (session['user_id'], passenger['passenger_id'], message)
            )
        conn.commit()

    return jsonify({'deleted_bus_id': bus_id, 'notified_passengers': len(passengers), 'message': message})


@app.get('/api/admin/complaints')
@api_role_required('admin')
def api_admin_complaints():
    complaints = query_all(
        '''
        SELECT c.complaint_id, p.name AS passenger_name, c.complaint_text,
               c.status, c.response_text, c.created_at
        FROM Complaint c
        JOIN Passenger p ON p.passenger_id = c.passenger_id
        ORDER BY c.created_at DESC
        LIMIT 25
        '''
    )
    return jsonify(complaints)


@app.post('/api/admin/complaints/<int:complaint_id>/respond')
@api_role_required('admin')
def api_admin_respond_complaint(complaint_id):
    data = request.get_json(silent=True) or {}
    response_text = (data.get('response_text') or '').strip()
    status = data.get('status') or 'resolved'
    if not response_text or status not in {'in_progress', 'resolved'}:
        return jsonify({'error': 'Response and valid status are required'}), 400
    with get_db() as conn:
        complaint = conn.execute(
            'SELECT passenger_id FROM Complaint WHERE complaint_id = ?',
            (complaint_id,)
        ).fetchone()
        if not complaint:
            return jsonify({'error': 'Complaint not found'}), 404
        conn.execute(
            '''
            UPDATE Complaint
            SET admin_id = ?, response_text = ?, status = ?
            WHERE complaint_id = ?
            ''',
            (session['user_id'], response_text, status, complaint_id)
        )
        conn.execute(
            '''
            INSERT INTO Notification (admin_id, passenger_id, message, type)
            VALUES (?, ?, ?, 'complaint')
            ''',
            (session['user_id'], complaint['passenger_id'], response_text)
        )
        conn.commit()
    return jsonify({'complaint_id': complaint_id, 'status': status})

@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out', 'info')
    return redirect(url_for('index'))

initialize_database()

if __name__ == '__main__':
    app.run(debug=True)