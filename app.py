import os
import sqlite3
from flask import Flask, jsonify, render_template, request, redirect, url_for, flash, session
from werkzeug.security import generate_password_hash, check_password_hash
from functools import wraps

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
DATABASE_PATH = os.path.join(BASE_DIR, 'database.db')

app = Flask(__name__, template_folder=BASE_DIR)
app.config['SECRET_KEY'] = 'your-secret-key-change-this-in-production'


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

@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out', 'info')
    return redirect(url_for('login'))

initialize_database()

if __name__ == '__main__':
    app.run(debug=True)