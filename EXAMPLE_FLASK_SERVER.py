"""
🌊 EXAMPLE FLASK API SERVER - Ready to Use

This is a complete, working example of the Flask backend your Flutter app expects.
Copy this to your floodguardAI/main.py and update with your actual ML model.

Key Points:
- Handles all endpoints the Flutter app calls
- Returns JSON in the exact format Flutter expects
- Includes CORS support for network requests
- Falls back to mock data if model not loaded
- Includes detailed comments explaining each part
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
from pymongo import MongoClient
import numpy as np
import certifi
import socket
from datetime import datetime, timezone
import requests
import joblib
import logging

# ============================================================================
# SETUP
# ============================================================================

app = Flask(__name__)
CORS(app)  # Enable CORS so Flutter can call from different network

# ============================================================================
# MONGODB SETUP
# ============================================================================
try:
    # ⚠️ REPLACE THIS STRING with your actual MongoDB connection string!
    # 🚨 CRITICAL: You MUST replace 'supermegapassword' with the real password
    # you created for your 'christianangcla4_db_user' in MongoDB Atlas.
    MONGO_URI = "mongodb://christianangcla4_db_user:LwWkr5RteURCPawc@ac-axood3e-shard-00-00.mbhocdx.mongodb.net:27017,ac-axood3e-shard-00-01.mbhocdx.mongodb.net:27017,ac-axood3e-shard-00-02.mbhocdx.mongodb.net:27017/?ssl=true&replicaSet=atlas-xsi95w-shard-0&authSource=admin&appName=FloodGuardCluster"
    client = MongoClient(MONGO_URI, tlsCAFile=certifi.where())
    
    db = client['floodguard_db']
    users_collection = db['users']
    reports_collection = db['reports']
    
    print("✅ Successfully connected to MongoDB!")
except Exception as e:
    print(f"❌ Failed to connect to MongoDB: {e}")

# Logging for debugging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Your trained ML model (load when server starts)
model = None
try:
    model = joblib.load('trained_flood_model.joblib')
    logger.info("✅ ML model loaded successfully")
except Exception as e:
    logger.warning(f"⚠️ Could not load ML model: {e}")
    logger.warning("⚠️ Using fallback predictions instead")

# ============================================================================
# DATA: BARANGAYS IN MARIKINA
# ============================================================================

BARANGAYS = [
    "Barangka",
    "Calumpang",
    "Concepcion Dos",
    "Concepcion Uno",
    "Fortune",
    "Industrial Valley",
    "Jesus De",
    "Marikina Heights",
    "Nangka",
    "Parang",
    "San Roque",
    "Santa Elena",
    "Santo Niño",
    "Tañong",

# ============================================================================
# ENDPOINT 1: HEALTH CHECK
# ============================================================================
# Flutter calls this first to verify API is alive
# http://192.168.1.57:5000/api/status

@app.route('/api/status', methods=['GET'])
def api_status():
    """
    Health check endpoint
    
    Returns: { "status": "ok" }
    Used by: Flutter app to verify connection
    """
    return jsonify({
        'status': 'ok',
        'message': 'FloodGuard AI API is running',
        'timestamp': datetime.now().isoformat(),
        'model_loaded': model is not None
    }), 200

# ============================================================================
# ENDPOINT 2: GET FLOOD DATA (ALL or SPECIFIC)
# ============================================================================
# Flutter calls this to get risk predictions
# http://192.168.1.57:5000/api/flood-data              (all barangays)
# http://192.168.1.57:5000/api/flood-data?barangay=Nangka  (specific)

@app.route('/api/flood-data', methods=['GET'])
def flood_data():
    """
    Get flood prediction data for barangays
    
    Query Parameters:
    - barangay: (optional) specific barangay name
    
    Returns:
    - If barangay specified: Single prediction object
    - If not specified: Array of all predictions
    
    Used by: HomeMapScreen to get flood risk for all barangays
    Used by: ReportFloodSheet to get detailed data for one barangay
    """
    try:
        barangay_name = request.args.get('barangay')
        
        # Case 1: Get specific barangay
        if barangay_name:
            prediction = get_prediction_for_barangay(barangay_name)
            if prediction:
                return jsonify(prediction), 200
            else:
                return jsonify({'error': f'Barangay "{barangay_name}" not found'}), 404
        
        # Case 2: Get all barangays
        all_predictions = []
        for barangay in BARANGAYS:
            prediction = get_prediction_for_barangay(barangay)
            if prediction:
                all_predictions.append(prediction)
        
        return jsonify(all_predictions), 200
        
    except Exception as e:
        logger.error(f"Error in flood_data endpoint: {e}")
        return jsonify({'error': str(e)}), 500

# ============================================================================
# ENDPOINT 3: PREDICT FOR COORDINATES
# ============================================================================
# Flutter calls this when user provides latitude/longitude
# POST http://192.168.1.57:5000/api/predict
# Body: { "latitude": 14.67, "longitude": 121.1 }

@app.route('/api/predict', methods=['POST'])
def predict():
    """
    Get flood prediction for specific coordinates
    
    Request Body:
    {
        "latitude": 14.67,
        "longitude": 121.1
    }
    
    Returns: Prediction object for that location
    Used by: ReportFloodSheet when user enters coordinates
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        
        # Validate coordinates
        if latitude is None or longitude is None:
            return jsonify({'error': 'latitude and longitude required'}), 400
        
        if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
            return jsonify({'error': 'Invalid coordinates'}), 400
        
        # Find which barangay these coordinates are in
        barangay = find_barangay_from_coords(latitude, longitude)
        
        # Get prediction for that barangay
        prediction = get_prediction_for_barangay(barangay)
        
        if prediction:
            return jsonify(prediction), 200
        else:
            return jsonify({'error': 'Could not get prediction'}), 500
            
    except Exception as e:
        logger.error(f"Error in predict endpoint: {e}")
        return jsonify({'error': str(e)}), 500

# ============================================================================
# ENDPOINT 4: WEATHER DATA
# ============================================================================
# Optional: Flutter can call this for weather conditions
# GET http://192.168.1.57:5000/api/weather

@app.route('/api/weather', methods=['GET'])
def weather():
    """
    Get current weather conditions
    
    Returns: Weather data (temperature, rainfall, etc.)
    Used by: Optional - for additional UI information
    """
    try:
        # In production, get this from weather API or sensors
        return jsonify({
            'temperature': 28.5,
            'humidity': 75,
            'rainfall': 65.2,
            'wind_speed': 15,
            'timestamp': datetime.now().isoformat()
        }), 200
    except Exception as e:
        logger.error(f"Error in weather endpoint: {e}")
        return jsonify({'error': str(e)}), 500

# ============================================================================
# ENDPOINT 5: SAVE USER PROFILE (MONGODB)
# ============================================================================
@app.route('/api/users', methods=['POST'])
def create_user():
    try:
        data = request.json
        user_doc = {
            "uid": data.get("uid"), 
            "email": data.get("email"),
            "first_name": data.get("firstName", ""),
            "last_name": data.get("lastName", ""),
            "phone": data.get("phone", ""),
            "house_no": data.get("house_no", ""),
            "street_name": data.get("street_name", ""),
            "barangay": data.get("barangay", ""),
            "city": data.get("city", "Marikina City"),
            "province": data.get("province", "Metro Manila"),
            "zip_code": data.get("zip_code", "1800"),
            "country": data.get("country", "Philippines")
        }
        
        # Check if user already exists
        existing_user = users_collection.find_one({"uid": data.get("uid")})
        if existing_user:
            users_collection.update_one({"uid": data.get("uid")}, {"$set": user_doc})
        else:
            user_doc["created_at"] = datetime.now(timezone.utc)
            users_collection.insert_one(user_doc)
            
        return jsonify({"status": "success", "message": "User profile saved/updated in MongoDB!"}), 201
    except Exception as e:
        logger.error(f"Error saving user: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/api/users/<string:uid>', methods=['GET'])
def get_user(uid):
    """
    Fetches a specific user's profile by their Firebase UID.
    """
    try:
        user = users_collection.find_one({"uid": uid})
        if user:
            user['_id'] = str(user['_id'])  # Convert ObjectId for JSON
            return jsonify(user), 200
        else:
            return jsonify({"error": "User not found"}), 404
    except Exception as e:
        logger.error(f"Error fetching user {uid}: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

# ============================================================================
# ENDPOINT 6: SAVE FLOOD REPORT (MONGODB)
# ============================================================================
@app.route('/api/reports', methods=['POST'])
def submit_report():
    try:
        data = request.json
        new_report = {
            "location": data.get("location"),
            "is_raining": data.get("isRaining"),
            "is_safe": data.get("isSafe"),
            "flood_depth": data.get("floodDepth"),
            "reported_by_uid": data.get("uid"),
            "timestamp": datetime.now(timezone.utc)
        }
        reports_collection.insert_one(new_report)
        return jsonify({"status": "success", "message": "Report saved successfully"}), 201
    except Exception as e:
        logger.error(f"Error saving report: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/api/reports', methods=['GET'])
def get_reports():
    """
    Fetches all user-submitted flood reports from MongoDB.
    
    Returns: A list of report objects.
    Used by: HomeMapScreen to display crowd-sourced data.
    """
    try:
        # Fetch latest 50 reports, sorted by most recent first
        reports_cursor = reports_collection.find().sort("timestamp", -1).limit(50)
        
        reports_list = []
        for report in reports_cursor:
            # Convert MongoDB's ObjectId to a string for JSON compatibility
            report['_id'] = str(report['_id'])
            reports_list.append(report)
            
        return jsonify(reports_list), 200
    except Exception as e:
        logger.error(f"Error fetching reports: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
# ============================================================================
# HELPER FUNCTION 1: GET PREDICTION FOR BARANGAY
# ============================================================================

def get_prediction_for_barangay(barangay_name):
    """
    This is where your ML magic happens!
    
    Process:
    1. Get current data (rainfall, water level, etc.)
    2. Prepare features for ML model
    3. Run prediction
    4. Format response for Flutter
    
    Returns:
    {
        "barangay": "Nangka",
        "risk_level": 45,           # 0-100, from ML model
        "rainfall": 60.5,           # mm, from sensors
        "water_level": 1.5,         # meters
        "max_water_level": 20.0,    # reference level
        "status": "warning",        # safe/warning/danger
        "timestamp": "2026-01-17T12:00:00"
    }
    """
    try:
        # Step 1: Get current data for this barangay
        rainfall = get_real_weather_data()
        water_level = estimate_water_level(rainfall)
        elevation = get_elevation_for_barangay(barangay_name)
        
        # Step 2: Prepare features for ML model
        # Your model likely expects: [rainfall, water_level, elevation, ...]
        features = prepare_features(
            barangay_name,
            rainfall,
            water_level,
            elevation
        )
        
        # Step 3: Run prediction with ML model
        if model:
            # Use trained model
            risk_level = predict_with_model(model, features)
        else:
            # Fall back to rule-based prediction if model not available
            risk_level = predict_with_rules(barangay_name, rainfall, water_level, elevation)
        
        # Ensure risk is 0-100
        risk_level = max(0, min(100, int(risk_level)))
        
        # Step 4: Determine status based on risk
        status = get_status_from_risk(risk_level)
        
        # Step 5: Return formatted response
        return {
            'barangay': barangay_name,
            'risk_level': risk_level,
            'rainfall': round(rainfall, 1),
            'water_level': round(water_level, 2),
            'max_water_level': 20.0,
            'status': status,
            'timestamp': datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error predicting for {barangay_name}: {e}")
        return None

# ============================================================================
# HELPER FUNCTION 2: PREPARE FEATURES
# ============================================================================

def prepare_features(barangay, rainfall, water_level, elevation):
    """
    Convert raw sensor data into features for ML model
    
    Your ML model probably expects something like:
    [rainfall, water_level, elevation, distance_to_river, slope, ...]
    
    Make sure this matches what your model was trained on!
    """
    return [
        rainfall,      # Index 0: Current rainfall (mm)
        water_level,   # Index 1: Current water level (m)
        elevation,     # Index 2: Ground elevation (m)
        # Add more features here based on your model...
    ]

# ============================================================================
# HELPER FUNCTION 3: PREDICT WITH MODEL
# ============================================================================

def predict_with_model(model, features):
    """
    Run ML model prediction
    
    Input: features (list of numbers)
    Output: risk percentage (0-100)
    """
    try:
        # Most sklearn models work like this:
        # prediction = model.predict([features])[0]
        
        # For probability predictions:
        # probability = model.predict_proba([features])[0][1]
        # return probability * 100
        
        # Placeholder - replace with your actual model call
        prediction = model.predict([features])[0]
        return prediction
    except Exception as e:
        logger.error(f"Error in model prediction: {e}")
        return 50  # Default to medium risk if error

# ============================================================================
# HELPER FUNCTION 4: PREDICT WITH RULES (NO ML MODEL)
# ============================================================================

def predict_with_rules(barangay_name, rainfall, water_level, elevation):
    """
    Simple rule-based prediction if ML model not available
    
    Rules:
    - High rainfall + high water level = high risk
    - Low elevation = higher risk (more flood-prone)
    - etc.
    
    This is your fallback when model.joblib is not loaded
    """
    risk = 0
    
    # Rule 1: Rainfall impact
    if rainfall > 80:
        risk += 30
    elif rainfall > 50:
        risk += 20
    elif rainfall > 30:
        risk += 10
    
    # Rule 2: Water level impact
    if water_level > 2:
        risk += 30
    elif water_level > 1:
        risk += 20
    elif water_level > 0.5:
        risk += 10
    
    # Rule 3: Elevation impact (lower = more risky)
    if elevation < 30:
        risk += 20
    elif elevation < 50:
        risk += 10
    
    # Rule 4: Historical high-risk areas
    high_risk_areas = ['Tumana', 'Malanday', 'Barangka']
    if barangay_name in high_risk_areas:
        risk += 5
    
    return min(100, max(0, risk))

# ============================================================================
# HELPER FUNCTION 5: GET STATUS
# ============================================================================

def get_status_from_risk(risk_level):
    """
    Convert risk percentage to human-readable status
    
    0-30%:   safe
    30-70%:  warning
    70-100%: danger
    """
    if risk_level < 30:
        return 'safe'
    elif risk_level < 70:
        return 'warning'
    else:
        return 'danger'

# ============================================================================
# HELPER FUNCTION 6: GET SENSOR DATA
# ============================================================================

def get_real_weather_data():
    """
    Get REAL rainfall data from Open-Meteo API (Free, No Key Required)
    Coordinates set to Marikina City
    """
    try:
        # Marikina Coordinates: 14.6507° N, 121.1029° E
        url = "https://api.open-meteo.com/v1/forecast"
        params = {
            "latitude": 14.6507,
            "longitude": 121.1029,
            "current": "rain,showers",
            "timezone": "Asia/Singapore"
        }
        
        response = requests.get(url, params=params, timeout=5)
        if response.status_code == 200:
            data = response.json()
            current = data.get('current', {})
            # Combine rain + showers for total precipitation
            return current.get('rain', 0.0) + current.get('showers', 0.0)
            
    except Exception as e:
        logger.error(f"Weather API Error: {e}")
    
    return 0.0  # Default to 0 if API fails

def estimate_water_level(rainfall):
    """
    Estimate water level based on rainfall (Simulation)
    Base level of Marikina River is approx 12-13m
    """
    base_level = 13.0
    # Simple correlation: more rain = higher water
    # Add some small noise for realism
    level = base_level + (rainfall * 0.1) + np.random.normal(0, 0.05)
    return round(level, 2)

def get_elevation_for_barangay(barangay):
    """
    Get ground elevation for barangay
    
    Can be extracted from GeoJSON or DEM (Digital Elevation Model)
    Lower elevation = more prone to flooding
    """
    # Dummy elevations for Marikina barangays (meters above sea level)
    elevations = {
        'Barangka': 45,
        'Calumpang': 42,
        'Concepcion Dos': 50,
        'Concepcion Uno': 48,
        'Fortune': 55,
        'Industrial Valley': 40,
        'Jesus De La Pena': 52,
        'Malanday': 38,
        'Marikina Heights': 60,
        'Nangka': 45,
        'Parang': 43,
        'San Roque': 47,
        'Santa Elena': 44,
        'Santo Nino': 46,
        'Tanong': 49,
        'Tumana': 39,
    }
    return elevations.get(barangay, 45)  # Default 45m

# ============================================================================
# HELPER FUNCTION 7: FIND BARANGAY FROM COORDINATES
# ============================================================================

def find_barangay_from_coords(latitude, longitude):
    """
    Given lat/lng, determine which barangay it's in
    
    You can:
    1. Load GeoJSON and use point-in-polygon
    2. Use a simple grid/bounding box approach
    3. Use online reverse geocoding API
    
    For now, return closest barangay
    """
    # Approximate centers of Marikina barangays
    barangay_coords = {
        'Barangka': (14.6349, 121.0866),
        'Calumpang': (14.6263, 121.0878),
        'Concepcion Dos': (14.6429, 121.1163),
        'Concepcion Uno': (14.6347, 121.1049),
        'Fortune': (14.6547, 121.1067),
        'Industrial Valley': (14.6265, 121.1062),
        'Jesus Dela Peña': (14.6514, 121.0936),
        'Malanday': (14.6759, 121.0958),
        'Marikina Heights': (14.6581, 121.0916),
        'Nangka': (14.6446, 121.1159),
        'San Roque': (14.6314, 121.1156),
        'Santa Elena': (14.6197, 121.1086),
        'Santo Niño': (14.6404, 121.0876),
        'Tañong': (14.6541, 121.0848),
        'Tumana': (14.6651, 121.0966),
    }a
    min_distance = float('inf')
    closest_barangay = 'Nangka'
    
    for barangay, (lat, lng) in barangay_coords.items():
        distance = ((latitude - lat)**2 + (longitude - lng)**2)**0.5
        if distance < min_distance:
            min_distance = distance
            closest_barangay = barangay
    
    return closest_barangay

# ============================================================================
# RUN SERVER
# ============================================================================

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

if __name__ == '__main__':
    local_ip = get_local_ip()
    print("""
    ╔═══════════════════════════════════════════════════════════╗
    ║           🌊 FloodGuard AI - API Server 🌊               ║
    ╚═══════════════════════════════════════════════════════════╝
    """)
    
    print("✅ Server starting...")
    print(f"📍 URL: http://{local_ip}:5000")
    print("\n   👉 COPY THIS EXACT URL INTO YOUR FLUTTER APP:")
    print(f"      static const String baseUrl = 'http://{local_ip}:5000/api';\n")
    print("   - GET  /api/status       (health check)")
    print("   - GET  /api/flood-data   (all barangays)")
    print("   - GET  /api/flood-data?barangay=NAME (specific)")
    print("   - POST /api/predict      (for coordinates)")
    print("   - GET  /api/weather      (weather data)")
    print("   - GET / POST /api/reports (user reports)")
    print("   - POST /api/users         (create new user)")
    print("   - GET /api/users/<uid>    (get user profile)")
    print("\n🚀 Server is running! Flutter app can now connect!\n")
    
    # Start Flask server
    # debug=True reloads on file changes (development only!)
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True,
        use_reloader=False  # Set to True for auto-reload on code changes
    )
