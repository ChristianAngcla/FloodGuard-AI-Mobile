import { execSync } from 'child_process';

const adb = 'C:\\Users\\chris\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe';

function cmd(c) {
  try {
    return execSync(`"${adb}" ${c}`, { stdio: 'pipe' }).toString().trim();
  } catch (e) {
    return `ERROR: ${e.message}`;
  }
}

console.log("=== ANDROID 15 ENVIRONMENT PROPERTIES ===");
console.log("Release Version (ro.build.version.release):", cmd("shell getprop ro.build.version.release"));
console.log("SDK Version (ro.build.version.sdk):", cmd("shell getprop ro.build.version.sdk"));
console.log("Product Model (ro.product.model):", cmd("shell getprop ro.product.model"));
console.log("Product CPU ABI (ro.product.cpu.abi):", cmd("shell getprop ro.product.cpu.abi"));
console.log("Page Size (getconf PAGE_SIZE):", cmd("shell getconf PAGE_SIZE"));
console.log("Navigation Mode:", cmd("shell settings get secure navigation_mode"));
