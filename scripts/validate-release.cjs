const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const forbiddenExtensions = new Set([".asar", ".exe", ".bak", ".tmp", ".log"]);
const ignoredDirs = new Set([".git", "node_modules"]);
const scripts = [
  "scripts/patch-asar.cjs",
  "scripts/update-locale.cjs",
  "scripts/patch-exe-hash.cjs",
  "scripts/get-asar-header-hash.cjs",
  "scripts/validate-release.cjs",
];

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ignoredDirs.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else out.push(full);
  }
  return out;
}

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

const translationPath = path.join(root, "translations", "zh-CN.json");
try {
  const parsed = JSON.parse(fs.readFileSync(translationPath, "utf8"));
  const count = Object.keys(parsed).length;
  if (count < 50) fail(`Translation table looks too small: ${count} entries`);
  else console.log(`Translation table OK: ${count} entries`);
} catch (error) {
  fail(`Cannot parse translations/zh-CN.json: ${error.message}`);
}

for (const script of scripts) {
  const result = spawnSync(process.execPath, ["--check", path.join(root, script)], {
    encoding: "utf8",
  });
  if (result.status !== 0) fail(`Syntax check failed for ${script}\n${result.stderr || result.stdout}`);
  else console.log(`Syntax OK: ${script}`);
}

for (const file of walk(root)) {
  const rel = path.relative(root, file).replace(/\\/g, "/");
  const ext = path.extname(file).toLowerCase();
  if (forbiddenExtensions.has(ext)) fail(`Forbidden release file: ${rel}`);
}

if (!process.exitCode) console.log("Release validation passed.");
