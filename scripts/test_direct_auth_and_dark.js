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

async function runDirectAuthAndDark() {
  console.log("=== RUNNING DIRECT AUTH & THEME TEST ===");

  // Reset navigation to clean state
  sh("shell input keyevent KEYCODE_BACK");
  sleep(500);
  sh("shell input keyevent KEYCODE_BACK");
  sleep(500);
  sh("shell input keyevent KEYCODE_BACK");
  sleep(500);

  // Bring to foreground
  sh("shell monkey -p com.example.floodguard_ai -c android.intent.category.LAUNCHER 1");
  sleep(1500);

  // 1. Profile Tab (890, 2240)
  console.log("1. Opening Profile Tab...");
  sh("shell input tap 890 2240");
  sleep(1500);
  capture("qa_01_profile_light.png");

  // 2. Tap 'Log In' button (540, 1330)
  console.log("2. Opening Login Screen...");
  sh("shell input tap 540 1330");
  sleep(2000);
  capture("qa_02_login_screen.png");

  // 3. Tap 'Sign Up' link on Login screen (540, 1750)
  console.log("3. Opening Signup Screen from Login...");
  sh("shell input tap 540 1750");
  sleep(2000);
  capture("qa_03_signup_screen.png");

  // 4. Return to Login screen (back button 80, 140)
  console.log("4. Returning to Login...");
  sh("shell input tap 80 140");
  sleep(1500);

  // 5. Tap 'Forgot Password?' (800, 1180)
  console.log("5. Opening Forgot Password Dialog...");
  sh("shell input tap 800 1180");
  sleep(1500);
  capture("qa_04_forgot_password_dialog.png");

  // Dismiss dialog (Tap outside or Cancel ~ 320, 1400)
  sh("shell input tap 320 1400");
  sleep(1000);

  // 6. Return from Login to Profile
  console.log("6. Returning to Profile...");
  sh("shell input tap 80 140");
  sleep(1500);
  capture("qa_05_profile_screen.png");

  // 7. Switch to Map tab (260, 2240)
  console.log("7. Switching to Map Tab...");
  sh("shell input tap 260 2240");
  sleep(1500);
  capture("qa_06_map_light.png");

  // 8. Open Drawer via Settings Gear (960, 160)
  console.log("8. Opening Drawer...");
  sh("shell input tap 960 160");
  sleep(1500);
  capture("qa_07_drawer_light.png");

  // 9. Toggle Dark Mode (Switch in drawer ~ 830, 530)
  console.log("9. Toggling Dark Mode in Drawer (830, 530)...");
  sh("shell input tap 830 530");
  sleep(2000);
  capture("qa_08_drawer_dark.png");

  // 10. Close Drawer (tap backdrop 100, 1000)
  console.log("10. Closing Drawer & Viewing Map in Dark Mode...");
  sh("shell input tap 100 1000");
  sleep(1500);
  capture("qa_09_map_dark.png");

  // 11. Profile in Dark Mode (890, 2240)
  console.log("11. Profile in Dark Mode...");
  sh("shell input tap 890 2240");
  sleep(1500);
  capture("qa_10_profile_dark.png");

  // 12. Log In screen in Dark Mode (540, 1330)
  console.log("12. Login in Dark Mode...");
  sh("shell input tap 540 1330");
  sleep(2000);
  capture("qa_11_login_dark.png");

  // 13. Sign Up in Dark Mode (540, 1750)
  console.log("13. Signup in Dark Mode...");
  sh("shell input tap 540 1750");
  sleep(2000);
  capture("qa_12_signup_dark.png");

  // Return to Profile
  sh("shell input tap 80 140");
  sleep(1000);
  sh("shell input tap 80 140");
  sleep(1500);

  // 14. Home Dashboard in Dark Mode (110, 2240)
  console.log("14. Home Dashboard in Dark Mode...");
  sh("shell input tap 110 2240");
  sleep(1500);
  capture("qa_13_home_dark.png");

  // 15. Alerts in Dark Mode (730, 2240)
  console.log("15. Alerts in Dark Mode...");
  sh("shell input tap 730 2240");
  sleep(1500);
  capture("qa_14_alerts_dark.png");

  console.log("=== COMPLETED DIRECT QA CAPTURES ===");
}

runDirectAuthAndDark();
