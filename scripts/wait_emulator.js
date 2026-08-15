import { execSync } from 'child_process';

const adb = 'C:\\Users\\chris\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe';

for (let i = 0; i < 40; i++) {
  try {
    const out = execSync(`"${adb}" shell getprop sys.boot_completed`, { stdio: 'pipe' }).toString().trim();
    if (out === '1') {
      console.log('Emulator BOOT COMPLETED!');
      console.log(execSync(`"${adb}" devices -l`, { stdio: 'pipe' }).toString());
      break;
    }
    console.log(`Booting... attempt ${i + 1}`);
  } catch (e) {
    console.log(`Waiting for device... attempt ${i + 1}`);
  }
  const start = Date.now();
  while (Date.now() - start < 3000) {}
}
