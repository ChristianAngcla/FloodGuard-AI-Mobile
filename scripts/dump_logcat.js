import { execSync } from 'child_process';
import fs from 'fs';

const adb = 'C:\\Users\\chris\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe';
const logs = execSync(`"${adb}" logcat -d -v time`, { maxBuffer: 50 * 1024 * 1024 }).toString();
fs.writeFileSync('ANDROID15_CRASH_RAW_LOG.txt', logs);
console.log('Saved raw logcat size:', (logs.length / 1024).toFixed(1) + ' KB');

const lines = logs.split('\n');
console.log('Total lines:', lines.length);

const appLines = lines.filter(l => l.includes('com.example.floodguard_ai') || l.includes('flutter'));
console.log('App & Flutter lines count:', appLines.length);

const errors = appLines.filter(l => l.includes(' E ') || l.includes('FATAL') || l.includes('AndroidRuntime') || l.includes('Exception') || l.includes('Error'));
console.log('App Error lines count:', errors.length);
errors.forEach(e => console.log(' ->', e));
