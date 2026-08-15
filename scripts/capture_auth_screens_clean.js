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

async function captureAuthClean() {
  console.log("=== CAPTURING CLEAN AUTH FLOWS ===");

  // 1. From Profile in Dark Mode, tap Log In (540, 1330)
  console.log("1. Opening Login Screen in Dark Mode...");
  sh("shell input tap 540 1330");
  sleep(2000);
  capture("final_01_login_dark.png");

  // 2. From Login screen, tap 'Sign Up' link (540, 2200)
  console.log("2. Opening Signup Screen in Dark Mode...");
  sh("shell input tap 540 2200");
  sleep(2000);
  capture("final_02_signup_dark.png");

  // Return to Login (tap back arrow 80, 140)
  sh("shell input tap 80 140");
  sleep(1500);

  // 3. Tap 'Forgot Password?' (800, 1480)
  console.log("3. Opening Forgot Password Dialog in Dark Mode...");
  sh("shell input tap 800 1480");
  sleep(1500);
  capture("final_03_forgot_password_dark.png");

  // Dismiss dialog (Cancel ~ 320, 1400)
  sh("shell input tap 320 1400");
  sleep(1000);

  // Return to Profile (tap back arrow 80, 140)
  sh("shell input tap 80 140");
  sleep(1500);

  // 4. Switch to Map tab (260, 2240)
  sh("shell input tap 260 2240");
  sleep(1500);

  // 5. Open Drawer (960, 160)
  sh("shell input tap 960 160");
  sleep(1500);

  // 6. Toggle Dark Mode OFF to return to Light Mode (830, 530)
  console.log("6. Toggling back to Light Mode...");
  sh("shell input tap 830 530");
  sleep(2000);

  // Close Drawer (100, 1000)
  sh("shell input tap 100 1000");
  sleep(1500);

  // 7. Profile in Light Mode (890, 2240)
  console.log("7. Profile in Light Mode...");
  sh("shell input tap 890 2240");
  sleep(1500);

  // 8. Log In Screen in Light Mode (540, 1330)
  console.log("8. Opening Login in Light Mode...");
  sh("shell input tap 540 1330");
  sleep(2000);
  capture("final_04_login_light.png");

  // 9. Sign Up Screen in Light Mode (540, 2200)
  console.log("9. Opening Signup in Light Mode...");
  sh("shell input tap 540 2200");
  sleep(2000);
  capture("final_05_signup_light.png");

  // Return to Login
  sh("shell input tap 80 140");
  sleep(1500);

  // 10. Forgot Password in Light Mode (800, 1480)
  console.log("10. Opening Forgot Password in Light Mode...");
  sh("shell input tap 800 1480");
  sleep(1500);
  capture("final_06_forgot_password_light.png");

  // Dismiss dialog
  sh("shell input tap 320 1400");
  sleep(1000);

  // Return to Profile
  sh("shell input tap 80 140");
  sleep(1500);

  // Switch to Map tab
  sh("shell input tap 260 2240");
  sleep(1500);

  console.log("=== ALL AUTH CAPTURES COMPLETE ===");
}

captureAuthClean();
