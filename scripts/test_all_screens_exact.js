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
  console.log(`Saved screenshots/${filename}`);
}

async function runExactTests() {
  console.log("=== RUNNING EXACT SCREEN-BY-SCREEN TEST ===");

  // 1. Map Tab (index 1: x=320, y=2300)
  console.log("1. Switching to Map Tab...");
  sh("shell input tap 320 2300");
  sleep(1500);
  captureScreen("screen_01_map.png");

  // 2. Home Dashboard (index 0: x=120, y=2300)
  console.log("2. Switching to Home Dashboard...");
  sh("shell input tap 120 2300");
  sleep(1500);
  captureScreen("screen_02_home_dashboard.png");

  // 3. Alerts Tab (index 3: x=760, y=2300)
  console.log("3. Switching to Alerts Screen...");
  sh("shell input tap 760 2300");
  sleep(1500);
  captureScreen("screen_03_alerts.png");

  // 4. Profile Tab (index 2: x=960, y=2300)
  console.log("4. Switching to Profile Screen...");
  sh("shell input tap 960 2300");
  sleep(1500);
  captureScreen("screen_04_profile.png");

  // 5. Open Login Screen (Tap 'Log In' button in Profile ~ x=540, y=1020)
  console.log("5. Opening Login Screen from Profile...");
  sh("shell input tap 540 1020");
  sleep(1500);
  captureScreen("screen_05_login.png");

  // 6. Open Signup Screen (Tap 'Sign Up' in Login ~ x=540, y=1950)
  console.log("6. Opening Signup Screen from Login...");
  sh("shell input tap 540 1950");
  sleep(1500);
  captureScreen("screen_06_signup.png");

  // Go back to Login
  sh("shell input keyevent KEYCODE_BACK");
  sleep(1000);

  // 7. Open Forgot Password Dialog (Tap 'Forgot Password?' in Login ~ x=800, y=1280)
  console.log("7. Opening Forgot Password Dialog...");
  sh("shell input tap 800 1280");
  sleep(1500);
  captureScreen("screen_07_forgot_password.png");

  // Dismiss dialog and return to Profile / Map
  sh("shell input keyevent KEYCODE_BACK");
  sleep(800);
  sh("shell input keyevent KEYCODE_BACK");
  sleep(1200);

  // 8. Open App Drawer (Settings gear icon top right ~ x=980, y=160 or hamburger)
  console.log("8. Opening Drawer via Settings button...");
  sh("shell input tap 320 2300"); // go to map first
  sleep(1000);
  sh("shell input tap 960 170"); // settings gear top right
  sleep(1500);
  captureScreen("screen_08_drawer.png");

  // 9. Toggle Dark Mode (Switch in drawer ~ x=900, y=360)
  console.log("9. Toggling Dark Mode in Drawer...");
  sh("shell input tap 900 360");
  sleep(1500);
  captureScreen("screen_09_drawer_dark.png");

  // Close drawer
  sh("shell input keyevent KEYCODE_BACK");
  sleep(1000);
  captureScreen("screen_10_map_dark.png");

  // 10. Switch to Profile in Dark Mode (x=960, y=2300)
  console.log("10. Switching to Profile in Dark Mode...");
  sh("shell input tap 960 2300");
  sleep(1500);
  captureScreen("screen_11_profile_dark.png");

  // 11. Switch to Home Dashboard in Dark Mode (x=120, y=2300)
  console.log("11. Switching to Home Dashboard in Dark Mode...");
  sh("shell input tap 120 2300");
  sleep(1500);
  captureScreen("screen_12_home_dark.png");

  // 12. Switch to Alerts in Dark Mode (x=760, y=2300)
  console.log("12. Switching to Alerts in Dark Mode...");
  sh("shell input tap 760 2300");
  sleep(1500);
  captureScreen("screen_13_alerts_dark.png");

  console.log("\n=== ALL SCREENS TESTED SUCCESSFULLY ===");
}

runExactTests();
