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

async function runStepByStep() {
  console.log("=== STEP BY STEP FOREGROUND SCREEN TESTING ===");

  // Launch and bring to foreground
  sh("shell monkey -p com.example.floodguard_ai -c android.intent.category.LAUNCHER 1");
  sleep(3000);

  // If Welcome dialog is on screen, dismiss it by tapping Explore Flood Map (x=540, y=2180)
  // Let's tap Explore Flood Map or tap bottom bar
  console.log("1. Dismissing any dialog...");
  sh("shell input tap 540 2180");
  sleep(1500);
  captureScreen("01_map_main.png");

  // 2. Home Tab (index 0: x=120, y=2300)
  console.log("2. Tapping Home Tab (x=120, y=2300)...");
  sh("shell input tap 120 2300");
  sleep(2000);
  captureScreen("02_home_dashboard.png");

  // 3. Alerts Tab (index 3: x=760, y=2300)
  console.log("3. Tapping Alerts Tab (x=760, y=2300)...");
  sh("shell input tap 760 2300");
  sleep(2000);
  captureScreen("03_alerts_screen.png");

  // 4. Profile Tab (index 2: x=960, y=2300)
  console.log("4. Tapping Profile Tab (x=960, y=2300)...");
  sh("shell input tap 960 2300");
  sleep(2000);
  captureScreen("04_profile_screen.png");

  // 5. Open Login Screen (Tap 'Log In' button in Profile ~ x=540, y=1020)
  console.log("5. Tapping Log In button in Profile...");
  sh("shell input tap 540 1020");
  sleep(2000);
  captureScreen("05_login_screen.png");

  // 6. Open Signup Screen (Tap 'Sign Up' in Login ~ x=540, y=1950)
  console.log("6. Tapping Sign Up in Login...");
  sh("shell input tap 540 1950");
  sleep(2000);
  captureScreen("06_signup_screen.png");

  // Go back to Login (Tap back arrow top-left ~ x=100, y=160 or back key)
  console.log("Returning to Login...");
  sh("shell input tap 100 160");
  sleep(1500);

  // 7. Open Forgot Password Dialog (Tap 'Forgot Password?' in Login ~ x=800, y=1280)
  console.log("7. Tapping Forgot Password...");
  sh("shell input tap 800 1280");
  sleep(2000);
  captureScreen("07_forgot_password_dialog.png");

  // Dismiss dialog (Tap outside or Cancel ~ x=300, y=1400)
  sh("shell input tap 300 1400");
  sleep(1000);

  // Go back to Profile screen (Tap back arrow top-left)
  sh("shell input tap 100 160");
  sleep(1500);
  captureScreen("08_back_to_profile.png");

  // 8. Return to Map (index 1: x=320, y=2300)
  console.log("8. Returning to Map Tab...");
  sh("shell input tap 320 2300");
  sleep(2000);
  captureScreen("09_map_screen.png");

  // 9. Open Drawer via settings gear (x=960, y=170)
  console.log("9. Opening Settings / Drawer...");
  sh("shell input tap 960 170");
  sleep(2000);
  captureScreen("10_app_drawer.png");

  // 10. Toggle Dark Mode (Switch in drawer ~ x=900, y=360)
  console.log("10. Toggling Dark Mode...");
  sh("shell input tap 900 360");
  sleep(2000);
  captureScreen("11_drawer_dark.png");

  // Close drawer (tap outside on the left ~ x=100, y=1000)
  sh("shell input tap 100 1000");
  sleep(1500);
  captureScreen("12_map_dark.png");

  // 11. Profile in Dark Mode (x=960, y=2300)
  console.log("11. Profile in Dark Mode...");
  sh("shell input tap 960 2300");
  sleep(2000);
  captureScreen("13_profile_dark.png");

  // 12. Home in Dark Mode (x=120, y=2300)
  console.log("12. Home in Dark Mode...");
  sh("shell input tap 120 2300");
  sleep(2000);
  captureScreen("14_home_dark.png");

  // 13. Alerts in Dark Mode (x=760, y=2300)
  console.log("13. Alerts in Dark Mode...");
  sh("shell input tap 760 2300");
  sleep(2000);
  captureScreen("15_alerts_dark.png");

  console.log("=== COMPLETED ALL SCREEN CAPTURES ===");
}

runStepByStep();
