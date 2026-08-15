import { execSync } from 'child_process';
import fs from 'fs';

const adb = 'C:\\Users\\chris\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe';

function sh(cmd) {
  try {
    return execSync(`"${adb}" ${cmd}`, { stdio: 'pipe' }).toString().trim();
  } catch (e) {
    return `ERROR: ${e.message}`;
  }
}

function sleep(ms) {
  const end = Date.now() + ms;
  while (Date.now() < end) {}
}

function captureScreen(filename) {
  sh(`shell screencap -p /sdcard/${filename}`);
  sh(`pull /sdcard/${filename} ./screenshots/${filename}`);
  console.log(`Captured screenshots/${filename}`);
}

async function runInteractiveTest() {
  console.log("=== STARTING FULL ANDROID 15 INTERACTIVE UI AUDIT ===");

  // 1. Dismiss Welcome Dialog if present
  console.log("1. Dismissing Welcome Dialog...");
  sh("shell input tap 540 2180"); // "Explore Flood Map" button
  sleep(2000);
  captureScreen("01_map_active.png");

  // 2. Tap a Barangay on the Map (e.g. center)
  console.log("2. Tapping Barangay on Map...");
  sh("shell input tap 540 1200");
  sleep(2000);
  captureScreen("02_barangay_sheet_open.png");

  // Close the sheet
  sh("shell input keyevent KEYCODE_BACK");
  sleep(1500);

  // 3. Switch to Home Dashboard Tab (Tab 0 ~ x=140, y=2280)
  console.log("3. Switching to Home Dashboard Tab...");
  sh("shell input tap 140 2280");
  sleep(2000);
  captureScreen("03_home_dashboard.png");

  // 4. Switch to Alerts Tab (Tab 3 ~ x=940, y=2280)
  console.log("4. Switching to Alerts Tab...");
  sh("shell input tap 940 2280");
  sleep(2000);
  captureScreen("04_alerts_screen.png");

  // 5. Switch to Profile Tab (Tab 2 ~ x=700, y=2280)
  console.log("5. Switching to Profile Tab...");
  sh("shell input tap 700 2280");
  sleep(2000);
  captureScreen("05_profile_screen.png");

  // 6. From Profile, tap Log In button (~ x=540, y=1000)
  console.log("6. Opening Login Screen...");
  sh("shell input tap 540 1000");
  sleep(2000);
  captureScreen("06_login_screen.png");

  // 7. From Login, tap Sign Up (~ x=540, y=1950)
  console.log("7. Opening Signup Screen...");
  sh("shell input tap 540 1950");
  sleep(2000);
  captureScreen("07_signup_screen.png");

  // Go back to Login
  sh("shell input keyevent KEYCODE_BACK");
  sleep(1500);

  // 8. From Login, tap Forgot Password (~ x=800, y=1300)
  console.log("8. Testing Reset Password / Forgot Password...");
  sh("shell input tap 750 1320");
  sleep(2000);
  captureScreen("08_reset_password_dialog.png");

  // Dismiss dialog / go back to Map
  sh("shell input keyevent KEYCODE_BACK");
  sleep(1000);
  sh("shell input keyevent KEYCODE_BACK");
  sleep(1500);

  // 9. Open Drawer from Home/Map (~ x=100, y=160)
  console.log("9. Opening App Drawer...");
  sh("shell input tap 100 160");
  sleep(2000);
  captureScreen("09_app_drawer.png");

  // 10. Toggle Dark Mode in Drawer (~ x=850, y=550)
  console.log("10. Toggling Dark Mode in Drawer...");
  sh("shell input tap 850 550");
  sleep(2000);
  captureScreen("10_drawer_dark_mode.png");

  // Close Drawer to see Map in Dark Mode
  sh("shell input keyevent KEYCODE_BACK");
  sleep(2000);
  captureScreen("11_map_dark_mode.png");

  // Switch to Profile in Dark Mode
  sh("shell input tap 700 2280");
  sleep(2000);
  captureScreen("12_profile_dark_mode.png");

  console.log("\n=== INTERACTIVE TEST COMPLETE ===");
}

runInteractiveTest();
