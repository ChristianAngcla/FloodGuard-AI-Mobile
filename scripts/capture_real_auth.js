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

function capture(name) {
  sh(`shell screencap -p /sdcard/${name}`);
  sh(`pull /sdcard/${name} ./screenshots/${name}`);
  console.log(`[CAPTURED] screenshots/${name}`);
}

// 1. Pop bottom sheet
sh("shell input keyevent KEYCODE_BACK");
sleep(1500);

// 2. Tap Profile Tab (890, 2240)
sh("shell input tap 890 2240");
sleep(1500);
capture("real_01_profile.png");

// 3. Tap Log In button on Profile (540, 1330)
sh("shell input tap 540 1330");
sleep(2000);
capture("real_02_login.png");

// 4. Tap Sign Up link at bottom of Login (540, 2200)
sh("shell input tap 540 2200");
sleep(2000);
capture("real_03_signup.png");

// 5. Back to Login
sh("shell input keyevent KEYCODE_BACK");
sleep(1500);

// 6. Tap Forgot Password (800, 1480)
sh("shell input tap 800 1480");
sleep(1500);
capture("real_04_forgot_password.png");

// Dismiss dialog (tap cancel 320, 1400)
sh("shell input tap 320 1400");
sleep(1000);

// Return to Profile
sh("shell input keyevent KEYCODE_BACK");
sleep(1500);
capture("real_05_profile_returned.png");

// Return to Map
sh("shell input tap 260 2240");
sleep(1000);
capture("real_06_map_returned.png");
