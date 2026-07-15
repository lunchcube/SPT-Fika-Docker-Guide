// Offline check for the emitters: loads app.js in a tiny DOM shim and asserts
// the non-obvious logic (arch-gated headless, required keys, quma/modsync emit).
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
  [dCompose.includes("name: spt-fika-4.0.x"), "default server name per major (4.0.x)"],
  [dCompose.includes("- ../server:/opt/server"), "default data dir mount"],
  [dCompose.includes("/fika/presence/get"), "fika healthcheck emitted"],
  [/\\nnetworks:\\n  spt-fika-4.0.x-net:/.test(dCompose), "network declared"],
  [dCompose.includes("- spt-fika-4.0.x-net"), "server joins the network"],
]);

// Pin the server name for the remaining service-naming assertions (independent of the per-major default).
state.serverName = "spt-fika";

state.arch = "x86_64"; state.headlessEnabled = true; state.headlessTag = "latest";
checks([
  [emitCompose().includes("spt-fika-headless"), "headless service on x86"],
  [emitCompose().includes("- ../headless:/opt/tarkov"), "headless dir mount default"],
  [emitCompose().includes("25565:25565/udp"), "headless P2P udp port"],
  [emitCompose().includes("SERVER_URL: spt-fika"), "headless SERVER_URL = server service"],
  [emitCompose().includes('condition: service_healthy'), "headless waits for healthy server"],
  [emitEnv().includes("HEADLESS_TAG=latest"), "HEADLESS_TAG emitted"],
  [emitEnv().includes("HEADLESS_PROFILE_ID="), "HEADLESS_PROFILE_ID emitted"],
]);

checks([[!emitEnv().includes("USE_MODSYNC"), "no ModSync vars when off"]]);
state.useModsync = true; state.modsyncVersion = "0.12.5";
checks([
  [emitEnv().includes("USE_MODSYNC=true"), "USE_MODSYNC emitted"],
  [emitEnv().includes("MODSYNC_VERSION=0.12.5"), "MODSYNC_VERSION emitted"],
  [emitEnv().includes("AUTO_UPDATE_MODSYNC="), "AUTO_UPDATE_MODSYNC emitted on 4.0 ModSync"],
  [emitEnv().includes("FIKA_HEADLESS_VERSION=1.4.14"), "FIKA_HEADLESS_VERSION emitted when headless + ModSync"],
]);

state.sptMajor = "3";
checks([
  [emitEnv().includes("USE_MODSYNC=true"), "ModSync now works on SPT 3.11 (Corter original)"],
  [emitCompose().includes("ghcr.io/dildz/spt-fika-server-3.11.x:"), "3.11 pulls the dedicated -3.11.x image"],
  [!emitEnv().includes("AUTO_UPDATE_MODSYNC"), "no AUTO_UPDATE_MODSYNC on frozen 3.11"],
  [!emitEnv().includes("FIKA_HEADLESS_VERSION"), "no FIKA_HEADLESS_VERSION on frozen 3.11"],
]);
state.quma = true; state.qumaAdminPassword = "supersecret";
checks([
  [!emitCompose().includes("ghcr.io/dildz/quma"), "quma is 4.0-only — gated off on SPT 3.11"],
  [!emitEnv().includes("QUMA_ADMIN_PASSWORD"), "no quma password in .env on 3.11"],
]);
state.quma = false;
state.sptMajor = "4";
checks([
  [emitCompose().includes("ghcr.io/dildz/spt-fika-server:") && !emitCompose().includes("spt-fika-server-3.11.x"), "4.0 pulls the base image"],
]);

state.quma = true;
checks([
  [/spt-fika-quma:[\\s\\S]*?condition: service_healthy/.test(emitCompose()), "quma waits for a healthy server before first-boot setup"],
]);

// Core-mod ownership: auto-update ON = the image reinstalls every boot (quma must not
// touch them); OFF = quma adopts them and can update/remove from its web UI.
state.autoUpdateFika = true; state.autoUpdateModsync = true;
checks([
  [emitCompose().includes('QUMA_MANAGE_FIKA: "false"'), "auto-update Fika on = compose owns Fika"],
  [emitCompose().includes('QUMA_MANAGE_MODSYNC: "false"'), "auto-update ModSync on = compose owns ModSync"],
]);
state.autoUpdateFika = false; state.autoUpdateModsync = false;
checks([
  [emitCompose().includes('QUMA_MANAGE_FIKA: "true"'), "auto-update Fika off = quma owns Fika"],
  [emitCompose().includes('QUMA_MANAGE_MODSYNC: "true"'), "auto-update ModSync off = quma owns ModSync"],
  [emitCompose().includes("FIKA_VERSION:"), "quma gets FIKA_VERSION to adopt against"],
  [emitCompose().includes("MODSYNC_VERSION:"), "quma gets MODSYNC_VERSION to adopt against"],
]);

// Discord webhook is optional: no field, no env, no compose var.
checks([
  [!emitCompose().includes("QUMA_DISCORD_WEBHOOK_URL"), "no webhook var when the field is blank"],
  [!emitEnv().includes("QUMA_DISCORD_WEBHOOK_URL"), "no webhook in .env when the field is blank"],
]);
state.qumaDiscordWebhook = "https://discord.com/api/webhooks/1/abc";
checks([
  [emitCompose().includes('QUMA_DISCORD_WEBHOOK_URL: "\${QUMA_DISCORD_WEBHOOK_URL}"'), "webhook wired from .env when set"],
  [emitEnv().includes("QUMA_DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/1/abc"), "webhook value lands in .env"],
]);
state.qumaDiscordWebhook = "";
state.quma = false;

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

// Quartermaster (quma) optional service.
state.arch = "x86_64";
checks([[!emitCompose().includes("-quma:"), "no quma service by default"]]);
state.quma = true; state.qumaAdminPassword = "supersecret"; state.qumaPort = 9190;
checks([
  [emitCompose().includes("ghcr.io/dildz/quma:latest"), "quma image emitted"],
  [emitCompose().includes("spt-fika-quma:"), "quma service named off the server name"],
  [emitCompose().includes('"9190:9190"'), "quma port mapped"],
  [emitCompose().includes("/var/run/docker.sock:/var/run/docker.sock"), "quma mounts the docker socket"],
  [emitCompose().includes("QUMA_SERVER_CONTAINER: spt-fika"), "quma points at the server container"],
  [emitEnv().includes("QUMA_ADMIN_PASSWORD=supersecret"), "QUMA_ADMIN_PASSWORD emitted to .env"],
  [emitCompose().includes("QUMA_SPT_DIR: /opt/server"), "quma reads the data dir at /opt/server"],
  [emitCompose().includes("- ../server:/opt/server"), "quma mounts the data dir (any path style) at /opt/server"],
  [!validate().qumaAdminPassword, "quma password valid at 8+ chars"],
]);
state.qumaAdminPassword = "short";
checks([[!!validate().qumaAdminPassword, "quma rejects a <8 char password"]]);
state.quma = false;

// Fika off: healthcheck falls back to /launcher/ping and INSTALL_FIKA=false.
state.sptMajor = "4"; state.healthcheck = true; state.installFika = false;
checks([
  [emitEnv().includes("INSTALL_FIKA=false"), "INSTALL_FIKA=false emitted"],
  [emitCompose().includes("/launcher/ping"), "healthcheck falls back to /launcher/ping without Fika"],
  [!emitCompose().includes("/fika/presence/get"), "no Fika presence check without Fika"],
]);
state.installFika = true;
checks([[emitCompose().includes("/fika/presence/get"), "Fika presence check restored with Fika on 4.0"]]);

// autoUpdateFika: emitted on 4.0 (living), omitted on frozen 3.11.
state.sptMajor = "4"; state.autoUpdateFika = true;
checks([[emitEnv().includes("AUTO_UPDATE_FIKA=true"), "AUTO_UPDATE_FIKA emitted on 4.0"]]);
state.sptMajor = "3";
checks([[!emitEnv().includes("AUTO_UPDATE_FIKA"), "AUTO_UPDATE_FIKA omitted on frozen 3.11"]]);
state.sptMajor = "4"; state.autoUpdateFika = false;

// listenAll -> LISTEN_ALL_NETWORKS passthrough (both states).
state.listenAll = true;
checks([[emitEnv().includes("LISTEN_ALL_NETWORKS=true"), "LISTEN_ALL_NETWORKS=true emitted"]]);
state.listenAll = false;
checks([[emitEnv().includes("LISTEN_ALL_NETWORKS=false"), "LISTEN_ALL_NETWORKS=false emitted"]]);

// Validation surface: name regex + number range.
state.userName = "bad name!";
checks([[!!validate().userName, "invalid userName rejected by regex"]]);
state.userName = "spt";
state.puid = 99999999;
checks([[!!validate().puid, "out-of-range PUID rejected"]]);
state.puid = 1000;
checks([[Object.keys(validate()).length === 0, "clean state has no validation errors"]]);
done();
`;
ctx.checks = (rows) => rows.forEach(([c, m]) => assert(c, m));
ctx.done = () => console.log("PASS");
vm.runInContext(fs.readFileSync(path.join(__dirname, "app.js"), "utf8") + epilogue, ctx);
