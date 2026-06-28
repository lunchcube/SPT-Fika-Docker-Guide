// Offline check: makeZip() produces a real .zip that `unzip` can list + verify.
// Run: node test_zip.cjs   (needs `unzip` on PATH)
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execSync } = require("child_process");
const { makeZip } = require("./zip.js");

const zip = makeZip([
  { name: "docker-compose.yml", content: "services:\n  spt-fika: {}\n" },
  { name: ".env", content: "SPT_VERSION=4.0.13\n" },
  { name: "README.md", content: "# quick start\n" },
]);

const f = path.join(os.tmpdir(), `cfg-test-${process.pid}.zip`);
fs.writeFileSync(f, Buffer.from(zip));
try {
  const list = execSync(`unzip -l ${f}`).toString();
  for (const n of ["docker-compose.yml", ".env", "README.md"]) {
    if (!list.includes(n)) { console.error("FAIL: missing", n); process.exit(1); }
  }
  execSync(`unzip -t ${f}`); // CRC integrity — throws on corruption
  console.log("PASS");
} finally {
  fs.unlinkSync(f);
}
