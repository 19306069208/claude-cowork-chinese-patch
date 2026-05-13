const fs = require("fs");
const path = require("path");

const localeFile = process.argv[2];
const translationsPath = process.argv[3] || path.join(__dirname, "..", "translations", "zh-CN.json");

if (!localeFile) {
  console.error("Usage: node scripts/update-locale.cjs <locale-json> [translations-json]");
  process.exit(1);
}

if (!fs.existsSync(localeFile)) {
  console.log(`Locale file not found, skipped: ${localeFile}`);
  process.exit(0);
}

const dict = JSON.parse(fs.readFileSync(translationsPath, "utf8"));
const locale = JSON.parse(fs.readFileSync(localeFile, "utf8"));
let changed = 0;

function visit(value) {
  if (typeof value === "string") {
    if (dict[value]) {
      changed += 1;
      return dict[value];
    }
    let next = value;
    for (const [from, to] of Object.entries(dict).sort((a, b) => b[0].length - a[0].length)) {
      if (from.length >= 4 && next.includes(from)) next = next.split(from).join(to);
    }
    if (next !== value) changed += 1;
    return next;
  }
  if (Array.isArray(value)) return value.map(visit);
  if (value && typeof value === "object") {
    for (const key of Object.keys(value)) value[key] = visit(value[key]);
  }
  return value;
}

visit(locale);
fs.writeFileSync(localeFile, JSON.stringify(locale, null, 2) + "\n", "utf8");
console.log(`Updated ${changed} locale entries in ${localeFile}`);
