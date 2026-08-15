# FloodGuard Mobile: Profile Phone Validation & Storage Audit

## 1. Executive Summary & Root Cause

| Item | Details |
| :--- | :--- |
| **Component** | `ProfileScreen` (`lib/screens/profile_screen.dart`) |
| **Identified Issue** | The Profile edit mobile-number text field lacked length limiters and format pattern validators, allowing users to type or paste >11 digits or invalid non-Philippine number formats. |
| **Original Behavior** | Field only checked `val.isEmpty` on save; did not enforce 11 digits; did not enforce `^09\d{9}$`; allowed alphanumeric pasting; did not normalize +63 E.164 database values to local `09` format for editing. |
| **Resolution** | Implemented `FilteringTextInputFormatter.digitsOnly`, `LengthLimitingTextInputFormatter(11)`, `maxLength: 11`, regex validation `^09\d{9}$` both in the field validator and in `_saveProfile()`, with automated bidirectional E.164 (+63) normalization. |

---

## 2. Phone Number Storage & Format Conventions

| Layer / Subsystem | Storage / Wire Format | User Display Format | Notes / Normalization |
| :--- | :--- | :--- | :--- |
| **Profile Screen (UI)** | `09XXXXXXXXX` (11 digits) | `09XXXXXXXXX` | Local Philippine format with digits only. |
| **Signup Screen (UI)** | `+63 9XXXXXXXXX` | `9XXXXXXXXX` (10 digits) | Prefixed with `+63 ` in UI. |
| **Firebase Phone Auth** | `+639XXXXXXXXX` (E.164) | Masked `********1234` | Standard international E.164 required by Firebase. |
| **MongoDB Backend (`/api/auth/*`, `/api/user/*`)** | `09XXXXXXXXX` or `+639XXXXXXXXX` | — | Backend accepts string; `AuthService` safely bridges both formats. |
| **Password Reset Lookup** | `+639XXXXXXXXX` / `09XXXXXXXXX` | Masked in dialog | Normalizes leading `0` to `+63` before sending Firebase SMS OTP. |

---

## 3. Code Modifications Applied

### 3.1. Input Restriction Formatter & Max Length
In `lib/screens/profile_screen.dart`:
```dart
_buildTextField(
  controller: _phoneCtrl,
  label: "Mobile Number",
  icon: Icons.phone_outlined,
  isDark: isDark,
  readOnly: !_isEditing,
  keyboardType: TextInputType.phone,
  maxLength: 11,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(11),
  ],
  validator: (val) {
    if (val == null || val.trim().isEmpty) {
      return "Required";
    }
    final clean = val.trim();
    if (!RegExp(r'^09\d{9}$').hasMatch(clean)) {
      return widget.isTaglish
          ? "Maglagay ng wastong 11-digit mobile number na nagsisimula sa 09."
          : "Enter a valid 11-digit mobile number starting with 09.";
    }
    return null;
  },
),
```

### 3.2. Save-Time Validation Guard
In `_saveProfile()`:
```dart
if (!_formKey.currentState!.validate()) return;

final phone = _phoneCtrl.text.trim();
if (!RegExp(r'^09\d{9}$').hasMatch(phone)) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isTaglish
              ? "Maglagay ng wastong 11-digit mobile number na nagsisimula sa 09."
              : "Enter a valid 11-digit mobile number starting with 09.",
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
  return;
}
```

### 3.3. Database / E.164 Load Normalization
In `_loadProfile()`:
```dart
String rawPhone = profile.phone.trim();
if (rawPhone.startsWith('+63')) {
  rawPhone = '0${rawPhone.substring(3)}';
} else if (rawPhone.startsWith('63') && rawPhone.length == 12) {
  rawPhone = '0${rawPhone.substring(2)}';
}
_phoneCtrl.text = rawPhone;
```

---

## 4. Test Matrix & Verification

Automated suite `test/profile_phone_validation_test.dart` verified all 5 scenarios:

| # | Test Scenario | Input Under Test | Expected Result | Actual Result |
| :---: | :--- | :--- | :--- | :---: |
| **1** | Valid 09 formats | `09171234567`, `09991234567` | Accepted (`^09\d{9}$` matches) | **PASSED** |
| **2** | Invalid numbers | `9171234567` (10 digits), `08171234567` (non-09) | Rejected (`^09\d{9}$` fails) | **PASSED** |
| **3** | Alphanumeric rejection | `0917ABC4567` | Digits-only keeps `09174567` | **PASSED** |
| **4** | Length truncation | `091712345678999` (>11 digits) | Truncated at 11 digits (`09171234567`) | **PASSED** |
| **5** | E.164 display normalization | `+639171234567` loaded from DB | Converted to `09171234567` | **PASSED** |

---

## 5. Visual & Theming Confirmation
- Error messages render in `#FF5252` (Red Accent) with high contrast against both Light `#F8FAFC` and Dark `#0F172A` surfaces.
- No layout overflow or clipping occurs when validation error text renders beneath the text field.
