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

function capture(name) {
  sh(`shell screencap -p /sdcard/${name}`);
  sh(`pull /sdcard/${name} ./screenshots/${name}`);
  console.log(`[CAPTURED] screenshots/${name}`);
}

async function runCleanAudit() {
  console.log("=== STARTING CLEAN NAVIGATION & VISUAL QA AUDIT ===");

  // 1. Dismiss any open bottom sheet or dialog
  sh("shell input keyevent KEYCODE_BACK");
  sleep(1000);
  sh("shell input keyevent KEYCODE_BACK");
  sleep(1000);

  // Bring app to foreground if needed
  sh("shell monkey -p com.example.floodguard_ai -c android.intent.category.LAUNCHER 1");
  sleep(2000);

  // If welcome dialog is up, dismiss it
  sh("shell input tap 540 2150");
  sleep(1500);

  // Step 1: Clean Map Screen
  console.log("1. Capturing Clean Map Screen...");
  sh("shell input tap 260 2240"); // Map tab
  sleep(1500);
  capture("01_clean_map.png");

  // Step 2: Home Dashboard Tab (Tab 0)
  console.log("2. Switching to Home Dashboard (110, 2240)...");
  sh("shell input tap 110 2240");
  sleep(2000);
  capture("02_clean_home_dashboard.png");

  // Step 3: Alerts Tab (Tab 3)
  console.log("3. Switching to Alerts Tab (730, 2240)...");
  sh("shell input tap 730 2240");
  sleep(2000);
  capture("03_clean_alerts.png");

  // Step 4: Profile Tab (Tab 2)
  console.log("4. Switching to Profile Tab (890, 2240)...");
  sh("shell input tap 890 2240");
  sleep(2000);
  capture("04_clean_profile.png");

  // Step 5: Log In Screen from Profile
  console.log("5. Opening Login Screen (540, 940)...");
  sh("shell input tap 540 940");
  sleep(2000);
  capture("05_clean_login.png");

  // Step 6: Sign Up Screen from Login
  console.log("6. Opening Signup Screen (540, 1980)...");
  sh("shell input tap 540 1980");
  sleep(2000);
  capture("06_clean_signup.png");

  // Step 7: Return to Login & Open Reset Password
  console.log("7. Returning to Login & opening Reset Password...");
  sh("shell input tap 80 140"); // Back arrow
  sleep(1500);
  sh("shell input tap 800 1310"); // Forgot password link
  sleep(1500);
  capture("07_clean_reset_password.png");

  // Dismiss Reset Password dialog
  sh("shell input tap 320 1400"); // Cancel
  sleep(1000);

  // Return from Login to Profile
  sh("shell input tap 80 140"); // Back arrow
  sleep(1500);
  capture("08_return_profile.png");

  // Step 8: Return to Map and Open Drawer
  console.log("8. Returning to Map and opening App Drawer...");
  sh("shell input tap 260 2240");
  sleep(1500);
  sh("shell input tap 960 160"); // Settings gear icon
  sleep(2000);
  capture("09_clean_app_drawer.png");

  // Step 9: Toggle Dark Mode
  console.log("9. Toggling Dark Mode in Drawer...");
  sh("shell input tap 900 360");
  sleep(2000);
  capture("10_clean_drawer_dark.png");

  // Step 10: Close Drawer & view Map in Dark Mode
  console.log("10. Viewing Map in Dark Mode...");
  sh("shell input tap 100 1000"); // Backdrop tap
  sleep(1500);
  capture("11_clean_map_dark.png");

  // Step 11: Profile in Dark Mode
  console.log("11. Profile in Dark Mode...");
  sh("shell input tap 890 2240");
  sleep(2000);
  capture("12_clean_profile_dark.png");

  // Step 12: Home in Dark Mode
  console.log("12. Home Dashboard in Dark Mode...");
  sh("shell input tap 110 2240");
  sleep(2000);
  capture("13_clean_home_dark.png");

  // Step 13: Alerts in Dark Mode
  console.log("13. Alerts in Dark Mode...");
  sh("shell input tap 730 2240");
  sleep(2000);
  capture("14_clean_alerts_dark.png");

  console.log("=== CLEAN AUDIT CAPTURES FINISHED ===");
}

runCleanAudit();
