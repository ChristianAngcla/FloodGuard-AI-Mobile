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

// 1. From Login screen, tap 'Sign up' at (620, 1860)
console.log("Tapping Sign Up at (620, 1860)...");
sh("shell input tap 620 1860");
sleep(2000);
capture("final_signup_screen.png");

// 2. Return to Login (tap back arrow 80, 140)
sh("shell input tap 80 140");
sleep(1500);

// 3. Tap 'Forgot password?' at (780, 1510)
console.log("Tapping Forgot Password at (780, 1510)...");
sh("shell input tap 780 1510");
sleep(1500);
capture("final_forgot_password_dialog.png");

// 4. Dismiss dialog (tap cancel ~ 320, 1400)
sh("shell input tap 320 1400");
sleep(1000);

// 5. Return to Profile (tap back arrow 80, 140)
sh("shell input tap 80 140");
sleep(1500);
capture("final_profile_screen.png");

// 6. Return to Map
sh("shell input tap 260 2240");
sleep(1500);
capture("final_map_screen.png");
