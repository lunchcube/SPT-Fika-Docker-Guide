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
  [dCompose.includes("name: spt-fika"), "project name emitted"],
  [dCompose.includes("/fika/presence/get"), "fika healthcheck emitted"],
  [/\\nnetworks:\\n  spt-fika-net:/.test(dCompose), "network declared"],
  [dCompose.includes("- spt-fika-net"), "server joins the network"],
]);

state.arch = "x86_64"; state.headlessEnabled = true; state.headlessTag = "latest";
checks([
  [emitCompose().includes("spt-fika-headless"), "headless service on x86"],
  [emitCompose().includes("25565:25565/udp"), "headless P2P udp port"],
  [emitCompose().includes("SERVER_URL: spt-fika"), "headless SERVER_URL = server service"],
  [emitCompose().includes('condition: service_healthy'), "headless waits for healthy server"],
  [emitEnv().includes("HEADLESS_TAG=latest"), "HEADLESS_TAG emitted"],
  [emitEnv().includes("HEADLESS_PROFILE_ID="), "HEADLESS_PROFILE_ID emitted"],
]);

state.modUrls = "https://x/a.zip\\n  https://x/b.7z";
checks([[emitEnv().includes('MOD_URLS="https://x/a.zip https://x/b.7z"'), "MOD_URLS joined"]]);

checks([[!emitEnv().includes("USE_MODSYNC"), "no ModSync vars when off"]]);
state.useModsync = true; state.modsyncVersion = "0.12.5";
checks([
  [emitEnv().includes("USE_MODSYNC=true"), "USE_MODSYNC emitted"],
  [emitEnv().includes("MODSYNC_VERSION=0.12.5"), "MODSYNC_VERSION emitted"],
]);

state.sptMajor = "3";
checks([
  [!emitEnv().includes("USE_MODSYNC"), "ModSync suppressed on SPT 3.11"],
  [emitCompose().includes("ghcr.io/dildz/spt-fika-server-3.11.x:"), "3.11 pulls the dedicated -3.11.x image"],
]);
state.sptMajor = "4";
checks([
  [emitCompose().includes("ghcr.io/dildz/spt-fika-server:") && !emitCompose().includes("spt-fika-server-3.11.x"), "4.0 pulls the base image"],
]);

state.healthcheck = false;
checks([
  [!emitCompose().includes("healthcheck:"), "no healthcheck when toggled off"],
  [emitCompose().includes("condition: service_started"), "deps gate on service_started when no healthcheck"],
  [!emitCompose().includes("service_healthy"), "no service_healthy without a healthcheck"],
]);
state.healthcheck = true;

checks([[!emitCompose().includes("fikawebapp"), "no web app by default"]]);
state.webapp = true; state.webappApiKey = "abc123"; state.webappPort = 8080;
checks([
  [emitCompose().includes("lacyway/fikawebapp:latest"), "web app service emitted"],
  [emitCompose().includes('"8080:5000"'), "web app port mapped"],
  [emitCompose().includes("webappdata:/app/data"), "web app uses named volume"],
  [/\\nvolumes:\\n  webappdata:/.test(emitCompose()), "named volume declared"],
  [emitEnv().includes("WEBAPP_API_KEY=abc123"), "WEBAPP_API_KEY emitted"],
]);
state.webapp = false;

state.arch = "aarch64";
checks([[!emitCompose().includes("headless"), "headless suppressed on ARM"]]);

// ARM: webapp is patched locally from lacyway's image, not pulled (amd64-only).
state.webapp = true;
const armWebapp = bundleFiles().find((f) => f.name === "webapp/Dockerfile");
checks([
  [emitCompose().includes("build: ./webapp"), "ARM webapp builds locally"],
  [emitCompose().includes("image: spt-fika-webapp:local"), "ARM webapp tags the local build"],
  [!emitCompose().includes("lacyway/fikawebapp:latest"), "ARM does not pull the amd64 image"],
  [!!armWebapp, "webapp/Dockerfile shipped in the bundle on ARM"],
  [armWebapp && armWebapp.content.includes("mcr.microsoft.com/dotnet/aspnet:10.0"), "webapp Dockerfile targets the arm64 .NET runtime base"],
  [armWebapp && armWebapp.content.includes("FROM --platform=linux/amd64 lacyway/fikawebapp:latest"), "webapp Dockerfile sources lacyway's own image"],
]);
state.webapp = false;
done();
`;
ctx.checks = (rows) => rows.forEach(([c, m]) => assert(c, m));
ctx.done = () => console.log("PASS");
vm.runInContext(fs.readFileSync(path.join(__dirname, "app.js"), "utf8") + epilogue, ctx);
