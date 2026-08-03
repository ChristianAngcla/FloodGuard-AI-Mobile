# FloodGuard Mobile — Real-Time Data (Methodology-Aligned)

> **Locked methodology:** FloodGuard predicts **river water level (meters)** using
> **time-series lagged multiple linear regression evaluated via OLS**.
> It does **not** use machine learning, AHP, or barangay flood probabilities.

## Live data sources (engineering inputs)

| Source | Role |
|--------|------|
| PAGASA FFWS water `map_list.do` | Live station water levels |
| PAGASA FFWS rainfall `map_list.do` | Upstream rain gauges |
| Open-Meteo | Temperature, humidity, wind, precip, heat index |

These feeds supply **observations** for the OLS engine. They are **not** a third-party flood algorithm.

## Prediction path

```text
Observations → lagged predictors → one-step OLS → predicted_water_level (m)
  → SAFE / ALERT / WARNING / CRITICAL (station thresholds)
  → Flutter UI (barangay → associated river station)
```

The **24-hour path** in the app is a **linear interpolation** from current WL to the
one-step OLS target — **not** 24 independent OLS forecasts.

## Flutter client

- Primary endpoint: `GET https://floodguard-api-xyjx.onrender.com/api/status`
- Service: `lib/services/flood_api_service.dart`
- Thresholds: `lib/utils/station_thresholds.dart` (API thresholds preferred)
- Auth: `lib/services/auth_service.dart` → `/api/auth/login|signup|…`
- Notifications: `lib/services/notification_service.dart` → FCM + `/api/user/subscribe`

## Status ordinals (internal)

Flutter may map station status to internal integers (e.g. 15 / 60 / 75 / 90) for UI gates.
These are **not** statistical flood probabilities.
