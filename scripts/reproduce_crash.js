import { spawn, execSync } from 'child_process';
import fs from 'fs';

const adb = 'C:\\Users\\chris\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe';
const flutter = 'C:\\src\\flutter\\bin\\flutter.bat';

console.log("=== CLEARING LOGCAT NOISE ===");
execSync(`"${adb}" logcat -c`);

console.log("\n=== BUILDING APP (DEBUG) FOR ANDROID 15 (16KB) ===");
try {
  const buildOut = execSync(`"${flutter}" build apk --debug`, { stdio: 'pipe' }).toString();
  console.log("Build succeeded:\n", buildOut);
} catch (err) {
  console.error("Build failed:", err.message);
  if (err.stdout) console.log(err.stdout.toString());
  if (err.stderr) console.error(err.stderr.toString());
}

console.log("\n=== INSTALLING APP ON EMULATOR ===");
try {
  execSync(`"${adb}" install -r build/app/outputs/flutter-apk/app-debug.apk`, { stdio: 'inherit' });
  console.log("Installed successfully!");
} catch (e) {
  console.error("Install error:", e.message);
}

console.log("\n=== LAUNCHING APP AND MONITORING LOGCAT ===");
execSync(`"${adb}" shell monkey -p com.example.floodguard_ai -c android.intent.category.LAUNCHER 1`);

const logcatProcess = spawn(adb, ['logcat', '-v', 'time']);
let rawLog = '';

logcatProcess.stdout.on('data', (data) => {
  const str = data.toString();
  rawLog += str;
  if (str.includes('FATAL') || str.includes('AndroidRuntime') || str.includes('Exception') || str.includes('Error') || str.includes('flutter') || str.includes('floodguard')) {
    console.log("[LOGCAT]", str);
  }
});

setTimeout(() => {
  logcatProcess.kill();
  fs.writeFileSync('ANDROID15_CRASH_RAW_LOG.txt', rawLog);
  console.log("\nLogcat captured and saved to ANDROID15_CRASH_RAW_LOG.txt");
}, 15000);
