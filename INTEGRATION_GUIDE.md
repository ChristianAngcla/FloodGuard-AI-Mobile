# FloodGuard AI - Real-Time Data Integration Guide

## 🎯 How Your System Works

### Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  Real-Time Data Sources (PAGASA)                    │
│  • Water Levels: pasig-marikina-tullahanffws.pagasa │
│  • Rainfall Data: pasig-marikina-tullahanffws.pagasa│
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│  Python AI Backend (floodguardAI)                   │
│  • Fetches PAGASA data                              │
│  • Processes with ML model                          │
│  • Predicts flood risk (0-100%)                     │
│  • Flask API on http://192.168.1.57:5000/api       │
└──────────────────┬──────────────────────────────────┘
                   │
     ┌─────────────┴─────────────┐
     ▼                           ▼
┌──────────────┐         ┌──────────────┐
│  Web App     │         │  Flutter App │
│  (JSX/React)│         │  (Our App)   │
└──────────────┘         └──────────────┘
```

---

## 📊 Data Flow Explanation

### Step 1: PAGASA Real-Time Data Collection

Your AI system fetches live data from two PAGASA (Philippine weather service) endpoints:

**Water Level Data:**

```
https://pasig-marikina-tullahanffws.pagasa.dost.gov.ph/water/table.do
Returns: Current water levels for different monitoring stations
```

**Rainfall Data:**

```
https://pasig-marikina-tullahanffws.pagasa.dost.gov.ph/rainfall/table.do
Returns: Current rainfall rates in mm/hour
```

### Step 2: AI Processing (Python Backend)

Your teammate's AI system:

```python
# Pseudocode of what happens
1. Fetch PAGASA water levels → extract "Nangka", "Malanday", etc.
2. Fetch PAGASA rainfall → extract mm/hour for each location
3. Run ML Model:
   Input: [rainfall, water_level, elevation, historical_data, ...]
   Output: Risk percentage (0-100%)
4. Map risk to status: "safe" (0-30%) | "warning" (30-70%) | "danger" (70-100%)
5. Return JSON with all data
```

### Step 3: Your Flask API Serves the Processed Data

The API returns formatted data like:

```json
{
  "barangay": "Nangka",
  "risk_level": 74, // From ML model
  "rainfall": 61.0, // From PAGASA
  "water_level": 0.6, // From PAGASA
  "max_water_level": 19.9, // Reference level
  "status": "warning", // Calculated status
  "timestamp": "2026-01-18T10:30:00" // When data was processed
}
```

### Step 4: Flutter App Displays Real-Time Data

Your Flutter app now:

```dart
1. Calls: GET http://192.168.1.57:5000/api/flood-data
2. Receives: All barangays with their risk levels
3. Updates: Map markers, legend, warning cards with REAL data
4. Refreshes: Every 5-10 minutes (you set the interval)
```

---

## 🔧 API Endpoints Your App Uses

### Endpoint 1: Health Check

```
GET /api/status
Returns: { "status": "ok", "model_loaded": true }
Purpose: Verify API is running before fetching data
```

### Endpoint 2: Get All Flood Data

```
GET /api/flood-data
Returns: Array of all barangays with their data
[
  { "barangay": "Nangka", "risk_level": 74, ... },
  { "barangay": "Malanday", "risk_level": 45, ... },
  ...
]
Purpose: Populate entire map with real-time risk levels
```

### Endpoint 3: Get Specific Barangay Data

```
GET /api/flood-data?barangay=Nangka
Returns: Single barangay's detailed data
Purpose: Show detailed info when user taps a barangay
```

---

## 📱 What Your Flutter App Now Does

### 1. **Startup** (initState)

- ✅ Load barangay boundaries from GeoJSON
- ✅ Fetch real-time flood data from API
- ✅ Map barangay names to risk percentages
- ✅ Display on map with colors

### 2. **Map Display**

- 🟢 Green zone: 0-30% risk (Safe)
- 🟡 Yellow zone: 30-70% risk (Warning)
- 🔴 Red zone: 70-100% risk (Danger)

### 3. **User Interaction**

- User taps a barangay → Shows modal with real-time data
- Rainfall: 61 MM (from PAGASA)
- Water Level: 0.6 M (from PAGASA)
- Risk Level: 74% (from your ML model)

### 4. **Auto-Refresh**

- Fetches new data every 5 minutes
- Updates markers and colors
- Shows latest PAGASA readings

---

## 🚀 Implementation in Your Flutter App

### What We Did:

1. ✅ Added import for `FloodApiService`
2. ✅ Modified `loadMarikinaBarangays()` to:
   - Load GeoJSON boundaries
   - Call API to get real flood data
   - Match barangay names to risk levels
   - Update UI with real data

### Example: How Data Flows

```dart
// Step 1: Load boundaries
final data = await rootBundle.loadString('assets/geojson/marikina_geomap.json');

// Step 2: Fetch real API data
final floodDataMap = await FloodApiService.getAllBarangayFloodData();

// Step 3: Match and store
if (floodDataMap.containsKey("Nangka")) {
  risks["Nangka"] = floodDataMap["Nangka"].riskLevel;  // e.g., 74
}

// Step 4: Update UI
setState(() {
  _barangayRisk = risks;  // Map now has real data
});

// Step 5: Display
// Marker shows "Nangka" with "74% Risk" (RED color)
```

---

## 🔄 How to Set Up Your Python Server

### What Your Server Should Have:

1. Flask app running on port 5000
2. API endpoints as described above
3. Connection to PAGASA data sources
4. ML model that predicts risk
5. CORS enabled (done in EXAMPLE_FLASK_SERVER.py)

### Quick Setup:

```bash
# 1. Install dependencies
pip install flask flask-cors numpy requests joblib

# 2. Copy EXAMPLE_FLASK_SERVER.py to your floodguardAI/main.py
# 3. Update with your actual ML model path
# 4. Run:
python main.py

# Server starts at: http://192.168.1.57:5000/api
```

---

## 📈 What's Happening Right Now

### When App Launches:

1. Loads 16+ barangays from GeoJSON
2. API returns: `[{barangay: "Nangka", risk_level: 74, ...}, ...]`
3. App matches names and stores risk levels
4. Map displays all barangays with their actual risk colors

### When User Taps a Barangay:

1. Opens modal with real-time data:
   - Rainfall: 61.0 MM (from PAGASA)
   - Water Level: 0.6 M (from PAGASA)
   - Risk Level: 74% (from AI model)
   - Status: Warning ⚠️

### Every 5 Minutes:

1. App fetches new data from API
2. Barangay colors update (if risk changed)
3. Latest PAGASA readings displayed

---

## ✨ Next Steps

1. **Start your Flask server** with the AI model
2. **Run the Flutter app** - it will automatically fetch data
3. **Check console** for debug logs:
   - `🔗 Fetching flood data from API...`
   - `✅ Received 16 barangay flood data from API`
   - `🔴 Nangka Risk: 74% (from API)`

4. **Test the API** manually:
   ```
   http://192.168.1.57:5000/api/status
   http://192.168.1.57:5000/api/flood-data
   http://192.168.1.57:5000/api/flood-data?barangay=Nangka
   ```

---

## 🎓 Summary

| Component        | Purpose                  | Real-Time? |
| ---------------- | ------------------------ | ---------- |
| PAGASA Endpoints | Live water/rainfall data | Yes ✅     |
| Python AI Model  | Processes data → Risk %  | Yes ✅     |
| Flask API        | Serves formatted data    | Yes ✅     |
| Flutter App      | Displays on map          | Yes ✅     |

Your app now shows **real predictions based on ACTUAL weather data** instead of random mock data! 🎉
