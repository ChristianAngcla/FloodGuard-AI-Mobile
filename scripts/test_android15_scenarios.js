import { execSync, spawn } from 'child_process';
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

async function runScenarioTests() {
  console.log("============================================================");
  console.log("STARTING ANDROID 15 CRASH REPRODUCTION & SCENARIO AUDIT");
  console.log("============================================================");

  // Clear logcat
  sh("logcat -c");

  const logProcess = spawn(adb, ['logcat', '-v', 'time']);
  let allLogs = '';
  let fatalErrors = [];

  logProcess.stdout.on('data', (d) => {
    const s = d.toString();
    allLogs += s;
    if (s.includes('FATAL') || s.includes('AndroidRuntime') || s.includes('SIGSEGV') || s.includes('SIGABRT') || s.includes('UnsatisfiedLinkError') || s.includes('DeadSystemException')) {
      console.error("\n💥 [CRASH / FATAL DETECTED]", s);
      fatalErrors.push(s);
    }
  });

  const scenarioResults = [];

  const recordScenario = (name, passed, details) => {
    scenarioResults.push({ scenario: name, status: passed ? 'PASS' : 'FAIL', details });
    console.log(`[${passed ? 'PASS' : 'FAIL'}] ${name}: ${details}`);
  };

  try {
    // ── Scenario A: Cold Launch ──
    console.log("\n--- Testing Scenario A: Cold Launch ---");
    sh("shell am force-stop com.example.floodguard_ai");
    sleep(1000);
    sh("shell monkey -p com.example.floodguard_ai -c android.intent.category.LAUNCHER 1");
    sleep(4000);
    let currentFocus = sh("shell dumpsys window | grep -E mCurrentFocus");
    let isRunning = currentFocus.includes("com.example.floodguard_ai");
    recordScenario("A. Cold Launch", isRunning, `Current focus: ${currentFocus}`);
    sh("shell screencap -p /sdcard/scenario_a_cold_launch.png");
    sh(`pull /sdcard/scenario_a_cold_launch.png screenshots/scenario_a_cold_launch.png`);

    // ── Scenario D: Home Screen Interaction ──
    console.log("\n--- Testing Scenario D: Home Dashboard Tab ---");
    // Tab 0 is Home: bottom left icon ~ x=140, y=2280
    sh("shell input tap 140 2280");
    sleep(2000);
    currentFocus = sh("shell dumpsys window | grep -E mCurrentFocus");
    recordScenario("D. Home Dashboard", currentFocus.includes("com.example.floodguard_ai"), `Focus: ${currentFocus}`);
    sh("shell screencap -p /sdcard/scenario_d_home.png");
    sh(`pull /sdcard/scenario_d_home.png screenshots/scenario_d_home.png`);

    // ── Scenario E: Map Screen & Barangay Tap ──
    console.log("\n--- Testing Scenario E: Map Tab & Interaction ---");
    // Tab 1 is Map: ~ x=380, y=2280
    sh("shell input tap 380 2280");
    sleep(2000);
    // Tap on the map center to select a barangay ~ x=540, y=1200
    sh("shell input tap 540 1200");
    sleep(1500);
    // Pan on map
    sh("shell input swipe 540 1200 540 800 300");
    sleep(1500);
    currentFocus = sh("shell dumpsys window | grep -E mCurrentFocus");
    recordScenario("E. Map Tab & Interaction", currentFocus.includes("com.example.floodguard_ai"), `Focus: ${currentFocus}`);
    sh("shell screencap -p /sdcard/scenario_e_map.png");
    sh(`pull /sdcard/scenario_e_map.png screenshots/scenario_e_map.png`);

    // ── Scenario F: Profile Screen ──
    console.log("\n--- Testing Scenario F: Profile Tab ---");
    // Tab 2 is Profile: ~ x=700, y=2280
    sh("shell input tap 700 2280");
    sleep(2000);
    currentFocus = sh("shell dumpsys window | grep -E mCurrentFocus");
    recordScenario("F. Profile Screen", currentFocus.includes("com.example.floodguard_ai"), `Focus: ${currentFocus}`);
    sh("shell screencap -p /sdcard/scenario_f_profile.png");
    sh(`pull /sdcard/scenario_f_profile.png screenshots/scenario_f_profile.png`);

    // ── Scenario H: Alerts / Notifications Screen ──
    console.log("\n--- Testing Scenario H: Alerts Tab ---");
    // Tab 3 is Alerts: ~ x=940, y=2280
    sh("shell input tap 940 2280");
    sleep(2000);
    currentFocus = sh("shell dumpsys window | grep -E mCurrentFocus");
    recordScenario("H. Alerts Screen", currentFocus.includes("com.example.floodguard_ai"), `Focus: ${currentFocus}`);
    sh("shell screencap -p /sdcard/scenario_h_alerts.png");
    sh(`pull /sdcard/scenario_h_alerts.png screenshots/scenario_h_alerts.png`);

    // ── Scenario K & L: Background & Resume App ──
    console.log("\n--- Testing Scenario K & L: Background & Resume ---");
    sh("shell input keyevent KEYCODE_HOME");
    sleep(2000);
    let homeFocus = sh("shell dumpsys window | grep -E mCurrentFocus");
    console.log("Home screen focus:", homeFocus);
    sh("shell monkey -p com.example.floodguard_ai -c android.intent.category.LAUNCHER 1");
    sleep(3000);
    currentFocus = sh("shell dumpsys window | grep -E mCurrentFocus");
    recordScenario("K & L. Background & Resume", currentFocus.includes("com.example.floodguard_ai"), `Resumed focus: ${currentFocus}`);

    // ── Scenario M: Repeated Navigation Cycles (Home -> Map -> Profile -> Alerts -> Home) ──
    console.log("\n--- Testing Scenario M: Repeated Navigation Cycles (10x) ---");
    let cycleFailed = false;
    for (let c = 1; c <= 10; c++) {
      sh("shell input tap 140 2280"); // Home
      sleep(300);
      sh("shell input tap 380 2280"); // Map
      sleep(300);
      sh("shell input tap 700 2280"); // Profile
      sleep(300);
      sh("shell input tap 940 2280"); // Alerts
      sleep(300);
      sh("shell input tap 140 2280"); // Home
      sleep(300);
      currentFocus = sh("shell dumpsys window | grep -E mCurrentFocus");
      if (!currentFocus.includes("com.example.floodguard_ai")) {
        cycleFailed = true;
        console.error(`Cycle ${c} failed! App crashed.`);
        break;
      }
    }
    recordScenario("M. Repeated Navigation Cycles (10x)", !cycleFailed, cycleFailed ? "Crashed during navigation" : "All 10 cycles completed smoothly");

    // ── Scenario B & C: Login & Signup Flow Navigation ──
    console.log("\n--- Testing Scenario B & C: Auth Navigation ---");
    // Open Profile tab and tap Log In button
    sh("shell input tap 700 2280");
    sleep(1500);
    // Tap "Sign In / Register" in profile or drawer ~ x=540, y=1400 or open drawer
    sh("shell input tap 100 160"); // drawer button top left
    sleep(1500);
    sh("shell screencap -p /sdcard/scenario_drawer.png");
    sh(`pull /sdcard/scenario_drawer.png screenshots/scenario_drawer.png`);
    sh("shell input keyevent KEYCODE_BACK"); // close drawer
    sleep(1000);

    // Save final raw logs
    fs.writeFileSync('ANDROID15_CRASH_RAW_LOG.txt', allLogs);
    console.log("\n=== ALL SCENARIOS TESTED ===");
    console.table(scenarioResults);
  } catch (err) {
    console.error("Test execution error:", err);
  } finally {
    logProcess.kill();
  }
}

runScenarioTests();
