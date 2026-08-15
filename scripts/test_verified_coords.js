import { execSync } from 'child_process';

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

// 1. Switch to Profile tab (x=890, y=2240)
console.log("Switching to Profile tab (890, 2240)...");
sh("shell input tap 890 2240");
sleep(2000);
captureScreen("verified_01_profile.png");

// 2. From Profile, tap Log In button (~ x=540, y=1020)
console.log("Opening Log In from Profile (540, 1020)...");
sh("shell input tap 540 1020");
sleep(2000);
captureScreen("verified_02_login.png");

// 3. From Login, tap Sign Up (~ x=540, y=1980)
console.log("Opening Sign Up from Login (540, 1980)...");
sh("shell input tap 540 1980");
sleep(2000);
captureScreen("verified_03_signup.png");

// Return to Login
sh("shell input tap 100 160");
sleep(1500);

// 4. From Login, tap Forgot Password (~ x=800, y=1310)
console.log("Opening Forgot Password...");
sh("shell input tap 800 1310");
sleep(2000);
captureScreen("verified_04_forgot_password.png");

// Cancel dialog
sh("shell input tap 320 1400");
sleep(1000);

// Return to Profile screen
sh("shell input tap 100 160");
sleep(1500);
captureScreen("verified_05_profile_again.png");

// 5. Switch to Alerts tab (x=730, y=2240)
console.log("Switching to Alerts tab (730, 2240)...");
sh("shell input tap 730 2240");
sleep(2000);
captureScreen("verified_06_alerts.png");

// 6. Switch to Home tab (x=110, y=2240)
console.log("Switching to Home tab (110, 2240)...");
sh("shell input tap 110 2240");
sleep(2000);
captureScreen("verified_07_home_dashboard.png");

// 7. Switch to Map tab (x=260, y=2240)
console.log("Switching to Map tab (260, 2240)...");
sh("shell input tap 260 2240");
sleep(2000);
captureScreen("verified_08_map.png");
