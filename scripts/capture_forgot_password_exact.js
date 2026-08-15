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

// 1. Send BACK to go from Signup to Login
sh("shell input keyevent KEYCODE_BACK");
sleep(1500);

// 2. Tap Forgot Password link (780, 1510)
sh("shell input tap 780 1510");
sleep(1500);
capture("clean_forgot_password_dialog.png");

// 3. Dismiss dialog (Cancel ~ 320, 1400)
sh("shell input tap 320 1400");
sleep(1000);

// 4. Send BACK to return to Profile
sh("shell input keyevent KEYCODE_BACK");
sleep(1500);

// 5. Switch to Map
sh("shell input tap 260 2240");
sleep(1000);
