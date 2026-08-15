import { execSync } from 'child_process';
import fs from 'fs';

const adb = 'C:\\Users\\chris\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe';
if (!fs.existsSync('./screenshots')) {
  fs.mkdirSync('./screenshots', { recursive: true });
}

const files = [
  'scenario_a_cold_launch.png',
  'scenario_d_home.png',
  'scenario_e_map.png',
  'scenario_f_profile.png',
  'scenario_h_alerts.png',
  'scenario_drawer.png'
];

for (const f of files) {
  try {
    execSync(`"${adb}" pull /sdcard/${f} ./screenshots/${f}`, { stdio: 'pipe' });
    console.log('Pulled', f);
  } catch (e) {
    console.log('Failed to pull', f, e.message);
  }
}
