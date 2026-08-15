# FloodGuard Mobile: True Android 15 (API 35) Final QA Signoff Report

```
================================================================================
FLOODGUARD TRUE ANDROID 15 API 35 QA = PASSED
================================================================================
```

---

## 1. Executive QA & Certification Summary

| Parameter / Metric | Live Target Measurement |
| :--- | :--- |
| **Target OS / API Level** | **Android 15 (VanillaIceCream) / API Level 35** |
| **Kernel Memory Architecture** | **`PAGE_SIZE = 16384 bytes` (16 KB native alignment)** |
| **Device Model** | `sdk_gphone16k_x86_64` |
| **Total Cold Launches** | **10 / 10 Passed** (Average startup: `1,823 ms`) |
| **Total Background / Resume Cycles** | **10 / 10 Passed** (100% Memory State Preserved) |
| **Total Multi-Screen Navigation Loops** | **10 / 10 Passed** (Zero Crashes / Zero ANRs) |
| **Automated Test Suite (`flutter test`)** | **32 / 32 Passed (100%)** |
| **Static Code Analysis (`flutter analyze`)** | **0 Errors, 0 Warnings** |
| **Release Binaries** | APK: `app-release.apk` (54.3 MB), AAB: `app-release.aab` (54.1 MB) |
| **Crash / ANR Count** | **0 Spontaneous Crashes, 0 ANRs, 0 SIGSEGV** |

---

## 2. 10 Consecutive Cold Launches Log (Release AOT Build)

| Iteration | Cold Launch Command | Startup Time | Process ID (PID) | Logcat Errors | Status |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **Launch 1** | `am start -n com.example.floodguard_ai/MainActivity` | `1,538 ms` | `13121` | `0` | **PASSED (Healthy)** |
| **Launch 2** | `am start -n com.example.floodguard_ai/MainActivity` | `1,520 ms` | `13197` | `0` | **PASSED (Healthy)** |
| **Launch 3** | `am start -n com.example.floodguard_ai/MainActivity` | `2,149 ms` | `13274` | `0` | **PASSED (Healthy)** |
| **Launch 4** | `am start -n com.example.floodguard_ai/MainActivity` | `1,870 ms` | `13346` | `0` | **PASSED (Healthy)** |
| **Launch 5** | `am start -n com.example.floodguard_ai/MainActivity` | `2,412 ms` | `13426` | `0` | **PASSED (Healthy)** |
| **Launch 6** | `am start -n com.example.floodguard_ai/MainActivity` | `1,504 ms` | `13493` | `0` | **PASSED (Healthy)** |
| **Launch 7** | `am start -n com.example.floodguard_ai/MainActivity` | `1,724 ms` | `13548` | `0` | **PASSED (Healthy)** |
| **Launch 8** | `am start -n com.example.floodguard_ai/MainActivity` | `1,332 ms` | `13609` | `0` | **PASSED (Healthy)** |
| **Launch 9** | `am start -n com.example.floodguard_ai/MainActivity` | `2,492 ms` | `13668` | `0` | **PASSED (Healthy)** |
| **Launch 10** | `am start -n com.example.floodguard_ai/MainActivity` | `1,695 ms` | `13731` | `0` | **PASSED (Healthy)** |

- **Average Startup Latency**: `1,823 ms`
- **Reliability Rate**: **100% (10/10)**

---

## 3. 10 Background / Resume Cycles Log

| Iteration | Action | Initial PID | Resume PID | Memory State Preserved | Status |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **Cycle 1** | `KEYCODE_HOME` -> `am start` | `13731` | `13731` | YES (Active) | **PASSED** |
| **Cycle 2** | `KEYCODE_HOME` -> `am start` | `13731` | `13731` | YES (Active) | **PASSED** |
| **Cycle 3** | `KEYCODE_HOME` -> `am start` | `13731` | `13731` | YES (Active) | **PASSED** |
| **Cycle 4** | `KEYCODE_HOME` -> `am start` | `13731` | `13731` | YES (Active) | **PASSED** |
| **Cycle 5** | `KEYCODE_HOME` -> `am start` | `13731` | `13731` | YES (Active) | **PASSED** |
| **Cycle 6** | `KEYCODE_HOME` -> `am start` | `13731` | `13731` | YES (Active) | **PASSED** |
| **Cycle 7** | `KEYCODE_HOME` -> `am start` | `13731` | `13731` | YES (Active) | **PASSED** |
| **Cycle 8** | `KEYCODE_HOME` -> `am start` | `13731` | `13731` | YES (Active) | **PASSED** |
| **Cycle 9** | `KEYCODE_HOME` -> `am start` | `13731` | `13731` | YES (Active) | **PASSED** |
| **Cycle 10** | `KEYCODE_HOME` -> `am start` | `13731` | `13731` | YES (Active) | **PASSED** |

- **State Retention Rate**: **100% (10/10)**

---

## 4. 10 Rapid Screen Navigation Cycles Log

| Iteration | Screen Sequence Tested | Cycle Elapsed | Active PID | Status |
| :---: | :--- | :---: | :---: | :---: |
| **Nav 1** | Home -> Map -> Alerts -> Profile -> Login -> Signup -> Map | `29,526 ms` | `13731` | **PASSED (Clean)** |
| **Nav 2** | Home -> Map -> Alerts -> Profile -> Login -> Signup -> Map | `14,585 ms` | `13731` | **PASSED (Clean)** |
| **Nav 3** | Home -> Map -> Alerts -> Profile -> Login -> Signup -> Map | `18,121 ms` | `13731` | **PASSED (Clean)** |
| **Nav 4** | Home -> Map -> Alerts -> Profile -> Login -> Signup -> Map | `18,909 ms` | `13731` | **PASSED (Clean)** |
| **Nav 5** | Home -> Map -> Alerts -> Profile -> Login -> Signup -> Map | `18,406 ms` | `13731` | **PASSED (Clean)** |
| **Nav 6** | Home -> Map -> Alerts -> Profile -> Login -> Signup -> Map | `14,861 ms` | `13731` | **PASSED (Clean)** |
| **Nav 7** | Home -> Map -> Alerts -> Profile -> Login -> Signup -> Map | `19,712 ms` | `13731` | **PASSED (Clean)** |
| **Nav 8** | Home -> Map -> Alerts -> Profile -> Login -> Signup -> Map | `17,881 ms` | `13731` | **PASSED (Clean)** |
| **Nav 9** | Home -> Map -> Alerts -> Profile -> Login -> Signup -> Map | `17,127 ms` | `13731` | **PASSED (Clean)** |
| **Nav 10** | Home -> Map -> Alerts -> Profile -> Login -> Signup -> Map | `17,779 ms` | `13731` | **PASSED (Clean)** |

- **Navigation Stress Reliability**: **100% (10/10)**

---

## 5. Profile Phone Number Validation Verification

| Scenario | Input Tested | Expected Behavior | Actual Behavior | Status |
| :--- | :--- | :--- | :--- | :---: |
| **Alphanumeric Rejection** | `0917ABC4567` | Digits-only keeps `09174567` | Letters filtered out immediately | **PASSED** |
| **Length Limitation** | `09171234567899` | Truncated to 11 digits | Fixed at `09171234567` | **PASSED** |
| **Underlength Number** | `0917123456` (10 digits) | Save blocked, error displayed | Error: `"Enter a valid 11-digit mobile number starting with 09."` | **PASSED** |
| **Non-09 Prefix** | `08171234567` (11 digits) | Save blocked, error displayed | Error: `"Enter a valid 11-digit mobile number starting with 09."` | **PASSED** |
| **Valid Local Format** | `09171234567` | Saved successfully | Profile updated in cache & backend | **PASSED** |
| **DB E.164 Load** | `+639171234567` | Loaded as `09171234567` | Display normalized to local format | **PASSED** |

---

## 6. Screenshot Gallery Evidence

1. [`screenshots/api35_01_map.png`](file:///c:/Users/chris/Desktop/codes/floodguard/FloodGuard-AI-Mobile/screenshots/api35_01_map.png): Interactive Map on Android 15 API 35.
2. [`screenshots/api35_02_home.png`](file:///c:/Users/chris/Desktop/codes/floodguard/FloodGuard-AI-Mobile/screenshots/api35_02_home.png): Home Dashboard with sensor thresholds.
3. [`screenshots/api35_03_alerts.png`](file:///c:/Users/chris/Desktop/codes/floodguard/FloodGuard-AI-Mobile/screenshots/api35_03_alerts.png): Alerts notification screen.
4. [`screenshots/api35_04_profile.png`](file:///c:/Users/chris/Desktop/codes/floodguard/FloodGuard-AI-Mobile/screenshots/api35_04_profile.png): Profile screen with wave gradient header.
5. [`screenshots/api35_05_login.png`](file:///c:/Users/chris/Desktop/codes/floodguard/FloodGuard-AI-Mobile/screenshots/api35_05_login.png): Citizen Login screen.
6. [`screenshots/api35_06_reset_password.png`](file:///c:/Users/chris/Desktop/codes/floodguard/FloodGuard-AI-Mobile/screenshots/api35_06_reset_password.png): Forgot Password recovery modal.
7. [`screenshots/api35_07_signup.png`](file:///c:/Users/chris/Desktop/codes/floodguard/FloodGuard-AI-Mobile/screenshots/api35_07_signup.png): 3-step Registration Form.
8. [`screenshots/api35_08_profile_edit.png`](file:///c:/Users/chris/Desktop/codes/floodguard/FloodGuard-AI-Mobile/screenshots/api35_08_profile_edit.png): Profile in Edit mode.
9. [`screenshots/api35_09_phone_validation_error.png`](file:///c:/Users/chris/Desktop/codes/floodguard/FloodGuard-AI-Mobile/screenshots/api35_09_phone_validation_error.png): Mobile Number field displaying validation error for non-09 input.
10. [`screenshots/api35_10_phone_saved.png`](file:///c:/Users/chris/Desktop/codes/floodguard/FloodGuard-AI-Mobile/screenshots/api35_10_phone_saved.png): Saved Profile state with valid 11-digit phone.

---

## 7. Final QA Certification Verdict

```
================================================================================
STATUS: FLOODGUARD TRUE ANDROID 15 API 35 QA = PASSED
================================================================================
```
