# FloodGuard Flutter Integration Guide (Methodology-Aligned)

> **Locked methodology:** OLS time-series lagged MLR → **predicted river water level**.
> Barangays are linked to an **associated river station**. That is **not** barangay flood probability.
> Do **not** document AHP, ML risk %, or invented flood probabilities.

## API

```text
GET https://floodguard-api-xyjx.onrender.com/api/status
```

Core fields used by the app:

- `live_sensors`
- `prediction.rivers.*.predicted_water_level`
- `prediction.rivers.*.status`
- `prediction.rivers.*.thresholds`
- `prediction.timeline` (interpolation path, not 24 OLS steps)
- `weather`

## Example (honest)

```dart
final floodDataMap = await FloodApiService.getAllBarangayFloodData();
final data = floodDataMap['Nangka'];
// data.waterLevel  → river stage (m) for associated station
// data.riskLevel   → INTERNAL status ordinal (NOT a flood probability %)
// Prefer showing SAFE / ALERT / WARNING / CRITICAL from station thresholds
```

## Setup

1. Point `FloodApiService.baseUrl` at the Express API (Render URL in production).
2. Ensure Firebase is configured if FCM alerts are required.
3. Run `flutter pub get` then `flutter analyze`.

## What not to build

- Barangay flood probability %
- AHP / vulnerability multipliers
- ML replacement for OLS
- Claiming the 24-hour chart is 24 separate hourly OLS predictions
