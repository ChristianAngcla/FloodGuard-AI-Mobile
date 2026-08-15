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

async function testAuthAndTheme() {
  console.log("=== TESTING AUTH SCREENS & THEME MODES ===");

  // 1. We are currently on Profile tab. Tap 'Log In' button at (540, 1330)
  console.log("1. Tapping Log In button (540, 1330)...");
  sh("shell input tap 540 1330");
  sleep(2000);
  capture("auth_01_login_screen.png");

  // 2. From Login screen, tap 'Sign Up' link (x=680, y=1770)
  console.log("2. Opening Signup screen from Login...");
  sh("shell input tap 680 1770");
  sleep(2000);
  capture("auth_02_signup_screen.png");

  // Go back to Login (Tap back button top-left x=80, y=140)
  sh("shell input tap 80 140");
  sleep(1500);

  // 3. From Login screen, tap 'Forgot Password?' (x=800, y=1180)
  console.log("3. Tapping Forgot Password...");
  sh("shell input tap 800 1180");
  sleep(1500);
  capture("auth_03_forgot_password_dialog.png");

  // Dismiss dialog (Tap outside or Cancel)
  sh("shell input tap 320 1400");
  sleep(1000);

  // Return to Profile (back button top-left x=80, y=140)
  sh("shell input tap 80 140");
  sleep(1500);

  // 4. Switch to Map tab (260, 2240)
  console.log("4. Switching to Map...");
  sh("shell input tap 260 2240");
  sleep(1500);

  // 5. Open Drawer (Settings icon top-right x=960, y=160)
  console.log("5. Opening Drawer...");
  sh("shell input tap 960 160");
  sleep(2000);
  capture("theme_01_drawer_light.png");

  // 6. Toggle Dark Mode (Switch in drawer ~ x=900, y=360)
  console.log("6. Toggling Dark Mode...");
  sh("shell input tap 900 360");
  sleep(2000);
  capture("theme_02_drawer_dark.png");

  // Close drawer (tap backdrop x=100, y=1000)
  sh("shell input tap 100 1000");
  sleep(1500);
  capture("theme_03_map_dark.png");

  // 7. Profile in Dark Mode (890, 2240)
  console.log("7. Profile in Dark Mode...");
  sh("shell input tap 890 2240");
  sleep(2000);
  capture("theme_04_profile_dark.png");

  // 8. Log In screen in Dark Mode
  console.log("8. Log In in Dark Mode...");
  sh("shell input tap 540 1330");
  sleep(2000);
  capture("theme_05_login_dark.png");

  // 9. Sign Up screen in Dark Mode
  console.log("9. Sign Up in Dark Mode...");
  sh("shell input tap 680 1770");
  sleep(2000);
  capture("theme_06_signup_dark.png");

  // Return to Login and Profile
  sh("shell input tap 80 140");
  sleep(1000);
  sh("shell input tap 80 140");
  sleep(1500);

  // 10. Home Dashboard in Dark Mode (110, 2240)
  console.log("10. Home in Dark Mode...");
  sh("shell input tap 110 2240");
  sleep(2000);
  capture("theme_07_home_dark.png");

  // 11. Alerts in Dark Mode (730, 2240)
  console.log("11. Alerts in Dark Mode...");
  sh("shell input tap 730 2240");
  sleep(2000);
  capture("theme_08_alerts_dark.png");

  console.log("=== AUTH & THEME TEST COMPLETE ===");
}

testAuthAndTheme();
