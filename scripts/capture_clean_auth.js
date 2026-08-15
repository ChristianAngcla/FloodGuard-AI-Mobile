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

// 1. Close alert modal
sh("shell input tap 540 2170");
sleep(1500);

// 2. Go to Profile Tab
sh("shell input tap 890 2240");
sleep(1500);
capture("clean_auth_00_profile.png");

// 3. Open Login
sh("shell input tap 540 1330");
sleep(2000);
capture("clean_auth_01_login.png");

// 4. Open Signup
sh("shell input tap 540 2200");
sleep(2000);
capture("clean_auth_02_signup.png");

// 5. Back to Login
sh("shell input tap 80 140");
sleep(1500);

// 6. Open Forgot Password
sh("shell input tap 800 1480");
sleep(1500);
capture("clean_auth_03_forgot_password.png");

// Dismiss dialog (tap 320 1400)
sh("shell input tap 320 1400");
sleep(1000);

// Back to Profile
sh("shell input tap 80 140");
sleep(1500);

// Switch to Map
sh("shell input tap 260 2240");
sleep(1000);
