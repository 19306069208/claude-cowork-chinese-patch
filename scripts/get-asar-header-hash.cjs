const crypto = require("crypto");
const asar = require("@electron/asar");

const archive = process.argv[2];
if (!archive) {
  console.error("Usage: node scripts/get-asar-header-hash.cjs <app.asar>");
  process.exit(1);
}

const raw = asar.getRawHeader(archive);
const hash = crypto.createHash("sha256").update(raw.headerString).digest("hex");
console.log(hash);
