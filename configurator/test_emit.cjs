// Offline check for the emitters: loads app.js in a tiny DOM shim and asserts
// the non-obvious logic (arch-gated headless, MOD_URLS join, required keys).
// Run: node test_emit.cjs   (no docker, no browser needed)
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const noop = () => {};
const elStub = () => new Proxy(() => {}, { get: () => elStub(), set: () => true, apply: () => elStub() });
const ctx = {
  TextEncoder, console,
  localStorage: { getItem: () => null, setItem: noop },
  navigator: { clipboard: { writeText: async () => {} } },
  setTimeout: noop, URL: { createObjectURL: () => "", revokeObjectURL: noop }, Blob: function () {},
  document: { getElementById: () => elStub(), createElement: () => elStub(), addEventListener: noop },
};
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, "zip.js"), "utf8"), ctx);

const assert = (cond, msg) => { if (!cond) { console.error("FAIL:", msg); process.exit(1); } };

const epilogue = `
const dEnv = emitEnv(), dCompose = emitCompose();
checks([
  [dEnv.includes("SPT_VERSION=4.0.13"), "default SPT_VERSION"],
  [dEnv.includes("INSTALL_FIKA=true"), "default INSTALL_FIKA"],
  [dEnv.includes("FIKA_VERSION=2.3.2"), "default FIKA_VERSION"],
  [dCompose.includes('"6969:6969"'), "default port mapping"],
  [!dCompose.includes("headless"), "no headless by default"],
]);

state.arch = "x86_64"; state.headlessEnabled = true; state.headlessTag = "latest";
checks([
  [emitCompose().includes("spt-fika-headless"), "headless service on x86"],
  [emitEnv().includes("HEADLESS_TAG=latest"), "HEADLESS_TAG emitted"],
]);

state.modUrls = "https://x/a.zip\\n  https://x/b.7z";
checks([[emitEnv().includes('MOD_URLS="https://x/a.zip https://x/b.7z"'), "MOD_URLS joined"]]);

state.arch = "aarch64";
checks([[!emitCompose().includes("headless"), "headless suppressed on ARM"]]);
done();
`;
ctx.checks = (rows) => rows.forEach(([c, m]) => assert(c, m));
ctx.done = () => console.log("PASS");
vm.runInContext(fs.readFileSync(path.join(__dirname, "app.js"), "utf8") + epilogue, ctx);
