# FloodGuard AI - Functional Decomposition Diagram

## Hierarchical Flow Diagram

```
                                    ┌──────────────────┐
                                    │     START        │
                                    └────────┬─────────┘
                                             │
                                    ┌────────▼──────────────┐
                                    │   FloodGuard AI       │
                                    │   Mobile Application  │
                                    │   (Marikina Focus)    │
                                    └────────┬──────────────┘
                                             │
                                    ┌────────▼─────────────────┐
                                    │  Load Map & Initialize   │
                                    │  • Load GeoJSON          │
                                    │  • Fetch Flood Data API  │
                                    │  • Start GPS Tracking    │
                                    └────────┬─────────────────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
         ┌──────────▼──────────┐  ┌─────────▼────────┐  ┌────────────▼─────────┐
         │  MAP VISUALIZATION  │  │ USER MANAGEMENT  │  │  DATA & LOCATION     │
         │   & NAVIGATION      │  │  & PREFERENCES   │  │      SERVICES        │
         └──────────┬──────────┘  └─────────┬────────┘  └────────────┬─────────┘
                    │                        │                        │
        ┌───────────┴───────────┐    ┌──────┴──────┐         ┌───────┴────────┐
        │                       │    │             │         │                │
   ┌────▼──────────┐  ┌────────▼──┐ │        ┌────▼───┐  ┌──▼────┐  ┌───────▼───┐
   │ View Barangay │  │Navigation │ │        │ Toggle │  │ Fetch │  │ Location  │
   │ Polygons      │  │ Controls  │ │        │ Dark   │  │ Flood │  │ Tracking  │
   │ & Risk Levels │  │           │ │        │ Mode   │  │ Data  │  │ (GPS)     │
   └────┬──────────┘  └────┬──────┘ │        └────┬───┘  └──┬────┘  └───────┬───┘
        │                  │        │             │         │               │
        │              ┌───┴─┐      │        ┌────┴────┐    │        ┌──────┴─────┐
        │              │     │      │        │ Toggle  │    │        │            │
    ┌───▼────────┐  ┌─▼──┐ ┌─┴──┐  │        │Language │    │   ┌────▼────┐  ┌───▼────┐
    │ Color by   │  │Zoom│ │ Pan│  │        │(EN/TL) │    │   │ Check  │  │ Stream │
    │ Risk Level │  │    │ │    │  │        └────┬────┘    │   │ API    │  │Current │
    │            │  │    │ │    │  │             │         │   │Health  │  │Location
    │ Display    │  │Zoom│ │Pan │  │        ┌────▼─────────┴──┬─▼────┐  └───┴────┬───┘
    │ Barangay   │  │to  │ │    │  │        │                │      │           │
    │ Labels     │  │Bar-│ │Map │  │   ┌────▼────┐      ┌────▼──┐   │      ┌────▼──┐
    │ (Name+%)   │  │ ang│ │    │  │   │ Refresh │      │ Query │   │      │ Center│
    │            │  │ay  │ │    │  │   │ Data on │      │Specific│  │     │ on Me │
    │ Polygon    │  │    │ │    │  │   │ Demand  │      │Barangay│  │     │ Button│
    │ Tapping→   │  │Anim│ │Rste│  │   │ Trigger │      │ Data   │  │     │       │
    │ Details    │  │ate │ │ to │  │   │ API     │      │ Query  │  │     │       │
    │ Sheet      │  │Camer│ │Dflt│  │   │ Call    │      │        │  │     │       │
    │            │  │a    │ │Pos │  │   └────┬────┘      └────┬───┘  │     └────┬──┘
    │ Display:   │  │Move │ │    │  │        │                │      │          │
    │ • Risk     │  │     │ │    │  │   ┌────▼────────────────▼──────┴──────────▼───┐
    │ • Rainfall │  │Prev/│ │Nex │  │   │                                            │
    │ • Water    │  │ Nxt │ │Bar │  │   │        ┌──────────────────────┐            │
    │ • Max      │  │ Bar │ │Nav │  │   │        │  SHOW BARANGAY       │            │
    │            │  │ Nav │ │ Ctl│  │   │        │  DETAILS SHEET       │            │
    └────┬───────┘  └─────┘ └─┬──┘  │   │        │                      │            │
         │                   │      │   │        │  • Risk Level        │            │
         │              ┌────┴──┐   │   │        │  • Rainfall (mm/h)   │            │
         │              │       │   │   │        │  • Water Level (m)   │            │
    ┌────▼────┐    ┌────▼──┐  ┌┴──┐ │   │        │  • Max Water Level   │            │
    │ Legend  │    │Warn   │  │Rpt│ │   │        │  • Safety Recs       │            │
    │ Card    │    │Card   │  │Fld│ │   │        │  • Color-Coded Risk  │            │
    │         │    │(Alert)│  │Dlg│ │   │        │                      │            │
    │ 5-Level │    │       │  │   │ │   │        └──────────────────────┘            │
    │ Scaling │    │Expand/│  │If │ │   │                                           │
    │(Ankle→  │    │Collapse│  │User│ │   │    ┌────────────────────────────────┐   │
    │ Head)   │    │       │  │Wants│ │   │    │  REPORT FLOOD DIALOG           │   │
    │         │    │Auto-  │  │to  │ │   │    │                                │   │
    │Collapse │    │Hide   │  │Rpt │ │   │    │  • Show Current Location      │   │
    │Expand   │    │after  │  │Fd  │ │   │    │  • Show Flood Risk            │   │
    │Button   │    │5 sec  │  │   │ │   │    │  • "Is it raining?" → Yes/No │   │
    └──┬──────┘    └───┬───┘  └─┬──┘ │   │    │  • "Is it safe?" → Yes/No   │   │
       │               │        │    │   │    │  • Submit & Show Success      │   │
       │               │        │    │   │    │                                │   │
       │          ┌────┴────────┴────┴────┴────▼─────────────────┐              │
       │          │                                              │              │
       └──────────┤         MENU / APP DRAWER                  ├──────────────┘
                  │      (Opened from Top-Right Button)         │
                  │                                              │
                  │  • Profile/Auth Section                     │
                  │  • Dark Mode Toggle                         │
                  │  • Language Toggle (EN/TL)                  │
                  │  • Help & Support Links                     │
                  │  • About App                                │
                  │                                              │
                  └──────────────────────────────────────────────┘
```

---

## Legend

| Color     | Component Type | Description                       |
| --------- | -------------- | --------------------------------- |
| 🟨 Yellow | System         | Main FloodGuard AI Application    |
| 🟧 Tan    | Main Modules   | Core functional areas (3 modules) |
| 🟦 Blue   | Sub-Modules    | Specific features/components      |
| 🟩 Cyan   | Module Actions | Detailed operations/functions     |

---

## Detailed Module Breakdown

### **1. MAP VISUALIZATION & NAVIGATION**

Interactive map display showing all Marikina barangays with real-time flood data

#### **View Barangay Polygons & Risk Levels**

- Color each barangay by flood risk (Green → Yellow → Orange → Red)
- Display centroid labels showing barangay name + risk percentage
- Enable polygon tap to open details sheet
- Show risk level, rainfall, water level, max water level
- Display recommendations based on risk tier

#### **Navigation Controls**

- **Zoom to Barangay** - Zoom in on selected barangay
- **Pan Map** - Move around the map
- **Animate Camera Movement** - Smooth 600ms animation to barangay
- **Reset Camera to Default** - Return to Marikina center
- **Previous/Next Barangay** - Navigate through barangays sequentially

#### **Additional Features**

- **Legend Card** - Expandable/collapsible (5-level flood scale)
- **Warning Card** - Alert banner (auto-hides after 5 seconds)
- **Report Flood Dialog** - User can report observed conditions

---

### **2. USER MANAGEMENT & PREFERENCES**

User settings and app configuration

#### **Toggle Dark Mode**

- Switch between Light and Dark themes
- Real-time UI update
- Persists across sessions

#### **Toggle Language**

- Switch between English and Tagalog (EN ↔ TL)
- Updates all visible text
- No page reload needed

#### **Refresh Data**

- Manually trigger API call
- Fetch latest barangay flood data
- Shows loading state

---

### **3. DATA & LOCATION SERVICES**

Backend API communication and GPS tracking

#### **Fetch Flood Data**

- Check API health status
- Query specific barangay flood data by name
- Fetch all barangays' data in one call
- Handle errors gracefully with fallback data

#### **Location Tracking (GPS)**

- Stream user's current location
- 5-meter distance filter
- "Center on Me" button to jump to user location
- Display user location with pulsing blue dot on map

---

## Additional Components

### **Barangay Details Sheet**

Displayed when user taps on a barangay polygon

- Barangay name
- Current risk level (0-100%)
- Current rainfall (mm/hour)
- Water level metrics
- Maximum water level
- Safety recommendations
- Color-coded risk visualization

### **Report Flood Dialog**

When user wants to report observed flooding

- Display current location
- Show current flood risk
- Two-question flow: "Is it raining?", "Is it safe?"
- Submit button with success notification

### **App Drawer / Menu**

Opened from top-right menu button

- Profile/Authentication section
- Dark mode toggle
- Language toggle (EN/TL)
- Help & support links
- About the app

---

## Data Flow

```
App Launch
    │
    ├─→ Load 16 Marikina barangay boundaries (GeoJSON)
    │
    ├─→ Fetch real-time flood data from Flask API
    │
    ├─→ Initialize GPS location tracking (with permission)
    │
    └─→ Display colored barangay polygons on map

User Taps Barangay
    │
    └─→ Show Barangay Details Sheet
        • Risk Level
        • Rainfall
        • Water Level
        • Recommendations

User Taps Menu Button
    │
    └─→ Show App Drawer
        • Toggle Dark Mode
        • Toggle Language
        • Refresh Data
        • Help/Support
        • Profile

User Taps "Report Flood"
    │
    └─→ Show Report Dialog
        • Ask: Is it raining?
        • Ask: Is it safe?
        • Submit & Confirm

User Taps "Center on Me"
    │
    └─→ Move map to user's GPS location
```

---

## Key Features Status

✅ **Active & Working**

- Interactive map with 16 barangays
- Real-time flood risk coloring
- Barangay polygon tap → details sheet
- Dark mode toggle
- Language support (English/Tagalog)
- GPS location tracking
- "Center on Me" button
- Flood data API integration
- Refresh data on demand
- Warning alerts
- Legend display
- Report flood dialog
- User authentication

❌ **Removed/Inactive**

- Multi-city navigation (Pasig, Manila, Quezon City)
- Pasig-specific features
- Advanced search functionality
- Flood segment visualization
- City navigation controls

---

## Technology Stack

- **Frontend:** Flutter (Dart)
- **Map Library:** flutter_map
- **Location:** geolocator
- **HTTP:** http package
- **Geospatial:** latlong2
- **Backend:** Python Flask (192.168.1.57:5000/api)
- **Languages:** English / Tagalog (TL)
- **Auth:** In-memory service (mock)
- **UI:** Material Design 3
