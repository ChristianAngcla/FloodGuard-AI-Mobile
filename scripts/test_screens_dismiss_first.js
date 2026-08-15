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

async function testScreens() {
  // Tap "Explore Flood Map" to dismiss WelcomePopup
  console.log("Dismissing WelcomePopup at (540, 2150)...");
  sh("shell input tap 540 2150");
  sleep(1500);
  captureScreen("modal_dismissed_map.png");

  // Switch to Home Dashboard (x=120, y=2300)
  console.log("Switching to Home Tab (120, 2300)...");
  sh("shell input tap 120 2300");
  sleep(2000);
  captureScreen("screen_home_dashboard.png");

  // Switch to Alerts Screen (x=760, y=2300)
  console.log("Switching to Alerts Tab (760, 2300)...");
  sh("shell input tap 760 2300");
  sleep(2000);
  captureScreen("screen_alerts.png");

  // Switch to Profile Screen (x=960, y=2300)
  console.log("Switching to Profile Tab (960, 2300)...");
  sh("shell input tap 960 2300");
  sleep(2000);
  captureScreen("screen_profile.png");

  // From Profile, tap Log In button (~ x=540, y=1020)
  console.log("Opening Log In screen (540, 1020)...");
  sh("shell input tap 540 1020");
  sleep(2000);
  captureScreen("screen_login.png");

  // From Login, tap Sign Up (~ x=540, y=1950)
  console.log("Opening Sign Up screen (540, 1950)...");
  sh("shell input tap 540 1950");
  sleep(2000);
  captureScreen("screen_signup.png");

  // Go back to Login (back button top-left ~ x=100, y=160)
  sh("shell input tap 100 160");
  sleep(1500);

  // From Login, tap Forgot Password (~ x=800, y=1280)
  console.log("Opening Forgot Password...");
  sh("shell input tap 800 1280");
  sleep(2000);
  captureScreen("screen_forgot_password.png");

  // Close dialog (Tap Cancel ~ x=320, y=1380)
  sh("shell input tap 320 1380");
  sleep(1000);

  // Return to Profile (back button top-left)
  sh("shell input tap 100 160");
  sleep(1500);

  // Switch to Map (x=320, y=2300)
  console.log("Switching back to Map...");
  sh("shell input tap 320 2300");
  sleep(1500);

  // Open Drawer via settings gear (x=960, y=170)
  console.log("Opening Drawer...");
  sh("shell input tap 960 170");
  sleep(2000);
  captureScreen("screen_drawer_open.png");

  // Toggle Dark Mode in Drawer (x=900, y=360)
  console.log("Toggling Dark Mode...");
  sh("shell input tap 900 360");
  sleep(2000);
  captureScreen("screen_drawer_dark_mode.png");

  // Close Drawer by tapping on backdrop (x=100, y=1000)
  sh("shell input tap 100 1000");
  sleep(1500);
  captureScreen("screen_map_dark_mode.png");

  // Switch to Profile in Dark Mode (x=960, y=2300)
  console.log("Profile in Dark Mode...");
  sh("shell input tap 960 2300");
  sleep(2000);
  captureScreen("screen_profile_dark_mode.png");

  console.log("Done!");
}

testScreens();
