# SPT-FIKA-Docker — Design Document

> Branch: `next` · Repo target name: `SPT-FIKA-Docker` (rename on merge to `main`)
> Status: Design — no implementation yet. Drafted 2026-05-27, revised 2026-05-27 evening to a web-configurator-first UX after reviewing [setuphytale.com](https://setuphytale.com). Revised 2026-06-27 to **build the SPT 4.0 server from source** and **base headless on Outshynd's wine-tkg image** (see §4, §7, §11).

---

## 1. Vision

A **turnkey, configurable Docker stack** for self-hosting SPT-FIKA. Two surfaces:

1. **A web configurator** (`setup-spt-fika.<your-domain>`) — Next.js app with a form-driven UI on the left and a live `docker-compose.yml` preview on the right. The host picks options, downloads a bundle (`compose.yml` + `.env` + a quick-start README), and runs `docker compose up -d`.
2. **A multi-arch Docker image** (`ghcr.io/dildz/spt-fika-server:<version>`) — the same image used by everyone, parameterised entirely through env vars. All version branching (SPT 3.11 vs 4.0), Fika installation, auto-update, mod handling, profile backups live *inside* the image, not in any installer.

The configurator is *dumb on purpose* — it just emits YAML from form state. All operational complexity lives in the image's env-var contract. This mirrors [setuphytale.com](https://setuphytale.com) / godstepx's `docker-hytale-server` pattern; both surfaces are independently deployable and updateable.

A **post-deploy script** (Phase 5) handles the host-side things compose can't — systemd log-capture units, host directory creation, UID/GID alignment, ufw rules. It ships inside the downloaded bundle as `setup-host.sh`, optional.

The user opens the configurator URL, fills in the form, downloads the bundle, and ends with a working stack that matches *their* choices — not ours.

### Audience

- People with a Linux box (ARM or x86) who want a working SPT-FIKA server in minutes.
- 3.11.x LTS players (the largest current audience) **and** 4.0.x players (the cutting edge). Both must be first-class.
- Hosts on Oracle Free Tier ARM, on Raspberry Pi, on dedicated x86 servers, on home NAS.

### Anti-goals

- Not a curated mod-pack. Users bring their own mods or pick from menus we surface.
- Not a managed/SaaS panel (defer Pelican / web UI).
- Not the world's most elegant Dockerfile. It's allowed to have version branches inside; the *UX* is what stays simple.

---

## 2. Constraints (immutable)

- **Headless = x86_64 only.** Wine + EFT cannot run on ARM. ARM hosts get server-only.
- **SPT major versions:** 3.11.x (Node.js, `SPT.Server.exe` — pkg bundle) AND 4.0.x (C# .NET, `SPT.Server.Linux`). Both must work from the same installer.
- **Volume bind mounts only.** No docker named volumes. User-facing path layout must stay obvious.
- **UID/GID parity** with host user. Default `1000:1000`, configurable.
- **Host-side log capture** (systemd `fika-*-logs.service` pattern) is mandatory — Unity truncates `LogOutput.log` on each EFT start, so container-internal logs alone are unreliable for crash forensics.

---

## 3. What users get to configure

This is the *product*. Every item here corresponds to an installer prompt.

### Stack-level
- **SPT major version:** `3.11` (LTS) or `4.0` (current)
- **SPT minor version:** auto-detect latest within major, or pin
- **Fika version:** auto-detect latest compatible with chosen SPT, or pin
- **Host architecture:** auto-detected (`x86_64` / `aarch64`). Determines whether headless service is offered.
- **Install location:** default `/home/<user>/docker/containers/spt-fika`, customizable
- **Listen address:** all networks vs. localhost
- **Ports:** server (default 6969), headless (default 25565)

### Components to enable
- [ ] **Fika server mod** — almost always yes, but optional (someone might want vanilla SPT)
- [ ] **Headless container** — x86 only, asked only on x86 hosts
- [ ] **Corter-ModSync** — auto-sync mods from server to clients
- [ ] **Profile backup cron** — daily snapshot of `user/profiles` with retention (default 7)
- [ ] **Auto-update SPT on version mismatch** — env-driven
- [ ] **Auto-update Fika on version mismatch** — env-driven
- [ ] **`AUTO_RESTART_ON_RAID_END`** (headless) — watches BepInEx log
- [ ] **Host-side log capture systemd unit(s)** — recommended on by default

### Mod selection
- [ ] **Empty start** — no mods, user adds their own
- [ ] **Curated picks per category** — installer shows menu (e.g. QoL, performance, content) with URL fetchers
- [ ] **BYO mod-list** — user provides a URL list file; installer downloads/extracts/places

### Optional cosmetics (from the old Oracle ARM repo)
- [ ] Themed launcher background packs (`SPT-launcher-images/alt*`) — keep these
- [ ] HD trader images — keep
- [ ] `randomize-bg.sh` — keep, but make it work for both major versions

### Operational
- [ ] **Container restart policy:** `unless-stopped` (default) / `always` / `no`
- [ ] **Update procedure:** which subset of `BepInEx/config`, `user/mods`, `user/profiles` to back up on image rebuild

---

## 4. Inventory: assets to carry forward

### From this repo's current `main` (the OnniSaarni → Dildz fork, frozen at SPT 3.10.x)

| File | Disposition |
|---|---|
| `files/Dockerfile` | Replace with multi-major version (see §7) |
| `files/init-server.sh` | Replace — that one was 3.10-shaped |
| `files/docker-compose.yml` | Replace with version-agnostic compose using profiles |
| `files/pre-setup.sh`, `post-setup.sh` | Merge into the new `install.sh` |
| `files/restart-fika.sh` | Keep, generalize for both major versions |
| `files/randomize-bg.sh` | Keep, generalize |
| `files/SPT-launcher-images/alt*` | **Keep as-is** — they're a nice differentiator |
| `files/HD-trader-images/` | **Keep as-is** |
| `mod-pack/ModSync.Updater.exe` | Keep, expose as optional opt-in |
| `files/commands.txt` | Reference; reformat into `docs/operations.md` |
| `README.md` | Rewrite to match the new framing |
| `LICENSE` | Keep |

### From `/home/ubuntu/docker/containers/spt-fika/v4.0.x/files/Image-Update/`

| File | Disposition |
|---|---|
| `Dockerfile` | Use as base for the 4.0 path inside the unified Dockerfile |
| `init-server.sh` | Use as base for the 4.0 path inside unified `init-server.sh` |
| `update-server.sh` | Generalize into `update.sh` — the backup-rebuild-restore pattern is unique and valuable |
| `commands.txt` | Reference notes |

### From `/home/ubuntu/spt-fika-setup.sh` (Aug 2025, stale 3.11 paths)

- Reuse the **interactive prompt pattern** (`get_valid_input` helper).
- Discard everything else — paths are wrong, references OnniSaarni's external repo, no version branching.

### From memory (this session and prior)

- `reference-fika-logs` — log capture pattern, Unity truncation gotcha, operational rule (use `restart` not `down/up`).
- `project-matching-error` — diagnostic infrastructure to bake in.
- `project-blackdiv-fix` — example of a custom-mod fix workflow that hosts may need to do; influence docs.

### From Outshynd's stripped SPT4 Docker (added 2026-06-27 — see `reference-outshynd-spt-docker`)

Local file set at `/home/ubuntu/github-repos/Outshynd SPT Docker/` (the two gists are the provenance). A clean strip of zhliau's containers.

| Asset | Disposition |
|---|---|
| `server/Dockerfile` | **Adopt as the 4.0 build path** (§7) — compiles `server-csharp` from source → native arm64. |
| `server/entrypoint.sh` | Pattern source for `init-server.sh`: gosu PUID/PGID, config seeding, sha256 config-drift warn, log-spam filter. |
| `server/build` | buildx multi-arch driver — reference for Phase 4 (§10). |
| `headless/*` (Dockerfile, entrypoint.sh, run-game.sh, monitor-logs.sh) | **Base for §11** — wine-tkg + ntsync + structured exit codes. |

---

## 5. Inventory: features available in the public landscape

Each can be offered as an installer prompt (opt-in or opt-out).

| Feature | Source | In our installer? |
|---|---|---|
| `INSTALL_FIKA` / `FIKA_VERSION` env-driven install | zhliau/fika-spt-server-docker | Yes — default on |
| `AUTO_UPDATE_SPT` / `AUTO_UPDATE_FIKA` | zhliau | Yes — opt-in |
| `ENABLE_PROFILE_BACKUP` (daily cron) | zhliau | Yes — default on |
| `INSTALL_OTHER_MODS` (URL list) | zhliau | Yes — opt-in |
| `AUTO_RESTART_ON_RAID_END` (headless) | zhliau/fika-headless-docker | Yes — passthrough |
| `USE_MODSYNC` / Corter-ModSync | zhliau headless | Yes — opt-in |
| Multi-arch via buildx | stblog, AirryCo | Yes — required |
| Build SPT4 from source → native arm64 | Outshynd | Yes — adopt as the 4.0 build path (§7) |
| Clean wine-tkg/ntsync headless rebuild | Outshynd | Yes — base for §11 |
| CI auto-build on SPT release | AirryCo | Phase 5 (later) |
| Pelican panel egg | zhliau headless | Skip (out of scope) |
| Nvidia DGPU support | zhliau headless | Skip (out of scope; passthrough only if user overrides env) |
| Docker Hub publication | dildz, stblog | Yes — GHCR primary, Docker Hub mirror optional |

---

## 6. Repo structure — three repos, separated concerns

The web configurator and the Docker image are independent projects with separate lifecycles. They get separate repos. The host-side helper script ships *inside* the configurator's generated bundle, not in either repo's source. So:

### 6a. `dildz/spt-fika-server` — the Docker image (public)

> Renamed from `SPT-FIKA-OracleARM--Docker-Guide` on merge to `main`.

```
spt-fika-server/
├── README.md                        Image catalog + env-var contract; links to configurator
├── LICENSE
├── DESIGN.md                        This file (lives here on merge)
├── Dockerfile                       Multi-major (SPT_MAJOR build-arg). See §7.
├── init-server.sh                   Version-branched entrypoint. See §7.
├── scripts/
│   ├── install_fika.sh
│   ├── auto_update.sh
│   ├── profile_backup.sh
│   ├── install_other_mods.sh
│   └── enforce_spt4_structure.sh    (only runs when SPT_MAJOR=4)
├── cron/
│   └── profile_backup.cron
├── headless/                        x86-only service / pinned zhliau image
│   ├── README.md                    "We pin zhliau's image, host-side sidecar for logs"
│   └── compose.fragment.yml         Reference snippet the configurator embeds
├── cosmetics/                       Carried forward from current repo
│   ├── HD-trader-images/
│   ├── SPT-launcher-images/
│   └── randomize-bg.sh
├── mod-pack/
│   └── ModSync.Updater.exe          Opt-in client-side installer (bundled separately)
└── docs/
    ├── architecture.md              How version-branching works
    ├── env-vars.md                  AUTHORITATIVE contract — configurator reads this
    ├── operations.md                Day-2: logs, backups, restarts, recovery
    ├── troubleshooting.md           Matching-error recipe, common pitfalls
    └── version-compatibility.md     What changes between 3.11 and 4.0
```

The previous plan included `install.sh`, `update.sh`, `.env.example`, and `docker-compose.yml` at the repo root. They're gone — the configurator emits them at download time, and they aren't checked-in artifacts anymore. `systemd/` units move into the configurator's bundle template (§9b).

### 6b. `dildz/setup-spt-fika-docker` — the web configurator (private)

> Scaffolded from `Dildz/Portfolio-Page` (cloned locally at `/home/ubuntu/github-repos/Portfolio-Page`). Same stack: Next.js 16 App Router · React 19 · TypeScript 5 · Tailwind v4 · ESLint flat. Same deploy model: multi-stage Dockerfile → static export → behind the existing shared Caddy proxy on the Oracle VPS.

```
setup-spt-fika-docker/
├── README.md
├── package.json                     copies from Portfolio-Page; adds yaml deps if needed
├── tsconfig.json                    copy as-is
├── eslint.config.mjs                copy as-is
├── postcss.config.mjs               copy as-is
├── next.config.ts                   copy as-is
├── app/
│   ├── layout.tsx                   Reframed title/description; keep Geist fonts
│   ├── page.tsx                     The configurator itself (form + preview)
│   ├── globals.css                  @import "tailwindcss";
│   └── components/                  Tabs, FormField, YamlPreview, Bundle download
├── lib/
│   ├── compose-emitter.ts           Form-state → docker-compose.yml string
│   ├── env-emitter.ts               Form-state → .env string
│   ├── bundle.ts                    Form-state → zip download (compose+.env+README+setup-host.sh)
│   └── schema.ts                    Form schema; mirrors spt-fika-server/docs/env-vars.md
├── public/                          Logos, favicons
└── deploy/
    ├── Dockerfile                   Multi-stage Next.js → static export → nginx serve
    ├── docker-compose.yml           Service on existing caddy-proxy-network
    └── caddy-snippet.txt            Block to paste into existing Caddyfile
```

**Why private:** the configurator could expose proprietary defaults, server keys, or moderation logic over time. Public would be fine for the OSS itself, but a private repo keeps options open. The image repo stays public.

### 6c. The bundle the configurator generates (delivered as a downloadable zip)

This is the "product" the end user receives — never lives in source control.

```
spt-fika-bundle-<timestamp>/
├── README.md                        Quick-start: "run docker compose up -d, then..."
├── docker-compose.yml               Generated from form state
├── .env                             Generated from form state
├── setup-host.sh                    Optional: systemd units + log dirs + UID/GID
└── systemd/                         Templates the script installs
    ├── fika-server-logs.service
    └── fika-headless-logs.service   (only present if headless was opted in)
```

---

## 7. Single-codebase, dual-version handling

The hard part. **The two SPT majors are built completely differently**, so the Dockerfile branches its *build* stage on `SPT_MAJOR` and converges on a shared runtime stage. `init-server.sh` is version-aware at runtime.

### 4.0 path — build from source (adopted from Outshynd)

SPT 4.0 is C#/.NET. We **compile it from source** instead of downloading a prebuilt archive — this is what yields a **native `arm64`** binary for Oracle Free Tier, which a prebuilt x86 `.7z` cannot. Pattern lifted from Outshynd's `spt-server` image (§4).

```dockerfile
# ---- build stage (SPT 4.0): compile server-csharp for the target arch ----
FROM mcr.microsoft.com/dotnet/sdk:10.0-noble AS build-v4
ARG TARGETOS
ARG TARGETARCH
ARG SPT_VERSION=4.0.13
RUN apt update && apt install -y --no-install-recommends curl ca-certificates git git-lfs \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp
RUN git clone --depth 1 --branch "$SPT_VERSION" https://github.com/sp-tarkov/server-csharp.git server
WORKDIR /tmp/server
RUN git lfs pull
RUN dotnet publish ./SPTarkov.Server/SPTarkov.Server.csproj \
      -c Release -f net9.0 -r ${TARGETOS}-${TARGETARCH} \
      --self-contained false -p:IsPublish=true -p:UseAppHost=false \
      -p:SptVersion=$SPT_VERSION -o /app/publish \
 && rm -f /app/publish/*.pdb

# ---- build stage (SPT 3.11): also from source, but Node not .NET (resolved — §13 Q1) ----
FROM debian:bookworm AS build-v3
ARG SPT_VERSION=3.11.4
RUN apt update && apt install -y --no-install-recommends curl ca-certificates git git-lfs
RUN git clone --branch "$SPT_VERSION" https://github.com/sp-tarkov/server.git /spt
WORKDIR /spt/project
# Node 20.11.1 (asdf/nvm), then build → emits ./build/SPT.Server.exe (a pkg-bundled Node binary)
RUN git lfs pull && npm ci && npm run build:release && mv build /app/publish

# ---- runtime stage: base branches per major ----
# 4.0 needs the .NET runtime (aspnet:9.0-noble); 3.11's pkg exe is self-contained (debian:bookworm-slim).
# Pick via buildx --target final-v${SPT_MAJOR}, or run both on the debian-based aspnet image (3.11 just
# ignores the unused .NET runtime — slightly larger 3.11 image, one stage). Minor; decide at Phase 1.
FROM mcr.microsoft.com/dotnet/aspnet:9.0-noble AS final
ARG SPT_MAJOR=4
RUN apt update && apt install -y --no-install-recommends curl gosu cron jq \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build-v${SPT_MAJOR} --chmod=755 /app/publish /opt/SPT
COPY init-server.sh /usr/bin/init-server
COPY scripts/ /opt/scripts/
COPY cron/profile_backup.cron /opt/cron/
ENV SPT_MAJOR=${SPT_MAJOR}
EXPOSE 6969
HEALTHCHECK CMD curl -fk --header responsecompressed:0 https://localhost:6969/launcher/ping || exit 1
ENTRYPOINT ["/usr/bin/init-server"]
```

This replaces the earlier `base-v${SPT_MAJOR}` "one final stage" trick: 4.0 needs a full SDK build stage (with `git-lfs`), so the per-major split now lives in the **build** stages and `final` does `COPY --from=build-v${SPT_MAJOR}`. **Fika server mod is layered by `scripts/install_fika.sh` at runtime** (from the bind mount), not baked in — keeps the image Fika-version-agnostic.

### `init-server.sh` shape

```bash
#!/bin/bash -e

case "$SPT_MAJOR" in
  3)
    SPT_BINARY="SPT.Server.exe"       # 3.11 build emits a pkg-bundled Node exe; runs directly on Linux
    # Node.js-based, different layout
    ;;
  4)
    SPT_BINARY="SPT.Server.Linux"
    enforce_spt_4_structure            # only relevant for v4
    ;;
  *)
    echo "FATAL: Unsupported SPT_MAJOR=$SPT_MAJOR" && exit 1
    ;;
esac

# Common path (Outshynd-derived): seed/repair SPT_Data/configs into the bind mount + warn on drift,
# install_fika if enabled, profile-backup cron if enabled, then drop privileges via gosu (PUID/PGID)
# and exec the server (optionally filtering keepalive/ping log spam when VERBOSE_LOGS=false).
```

The cost is conditional logic in a few places. The benefit is one repo, one installer, one mental model.

---

## 8. Multi-arch handling (x86 + ARM)

The **image** ships as a multi-arch manifest (`linux/amd64` + `linux/arm64`) on GHCR — a single `image:` reference resolves correctly on either arch.

For the **compose**, we don't use `COMPOSE_PROFILES` — that pattern was useful when one checked-in compose file had to serve multiple modes. With a configurator that emits a fresh compose per host, **the simpler rule is "include only services the user picked"**. The HEADLESS tab is greyed out on aarch64, so generated compose files on ARM hosts never reference the headless service in the first place.

Shape of an emitted compose (x86 host that opted into headless):

```yaml
services:
  fika-server:
    image: ghcr.io/dildz/spt-fika-server:${SPT_VERSION}   # multi-arch manifest
    environment:
      SPT_MAJOR: "4"
      SPT_VERSION: "4.0.13"
      INSTALL_FIKA: "true"
      ENABLE_PROFILE_BACKUP: "true"
      # … the rest from form state

  fika-headless:
    image: ghcr.io/zhliau/fika-headless-docker:${HEADLESS_TAG:-latest}
    # … only emitted when arch=x86_64 AND headless tab toggle is on
```

User runs `docker compose up -d`; gets exactly what they configured. Re-configuring means going back to the configurator, re-downloading the bundle, replacing the compose, and `docker compose up -d` again.

---

## 9. Configurator UX

The user-facing surface. A single Next.js page at `setup-spt-fika.<your-domain>` with a two-column layout: tabbed form on the left, live YAML preview on the right. Modelled on [setuphytale.com](https://setuphytale.com).

### 9a. Page layout

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  SetupSPT-FIKA  Server Configurator                                  GitHub  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SPT-FIKA Server Setup                                                       │
│  Generate your Docker Compose configuration in seconds.                      │
│                                                                              │
│  ┌─ QUICK START ─────────────────────────────────────────────────────────┐  │
│  │  1 Prerequisites    2 Configuration   3 Download                      │  │
│  │    Install Docker     Customize tabs    Get spt-fika-bundle.zip       │  │
│  │                                                                       │  │
│  │  4 Deploy           5 First run         6 Play                        │  │
│  │    docker compose     Watch logs for     Connect SPT-Launcher to      │  │
│  │    up -d              auth / readiness   your-server-ip:6969          │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─ TABS ──────────────────┐  ┌─ PREVIEW ──────────────  [YAML][.env]   ┐  │
│  │ GENERAL  VERSION        │  │ ⌽ docker-compose.yml          [⧉] [⤓]   │  │
│  │ HEADLESS MODS  OPS  ADV │  ├─────────────────────────────────────────┤  │
│  ├─────────────────────────┤  │   1  # SPT-FIKA Server Docker Compose   │  │
│  │ <form fields per tab>   │  │   2  # Generated by setup-spt-fika      │  │
│  │                         │  │   3  # https://setup-spt-fika.<domain>  │  │
│  │                         │  │   …                                     │  │
│  └─────────────────────────┘  └─────────────────────────────────────────┘  │
│                                                                              │
│            ┌─────────────────────────────────────┐                           │
│            │  ⤓  Download bundle (.zip)          │                           │
│            └─────────────────────────────────────┘                           │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 9b. Tabs — option surface

Six tabs. Defaults match the most common setup; everything is changeable.

| Tab | Purpose | Maps to (in §3 list) |
|---|---|---|
| **GENERAL** | Server identity + paths + ports + listen address | server name, install path, ports |
| **VERSION** | SPT major (3.11 / 4.0), SPT version, Fika version | SPT major, SPT minor, Fika version |
| **HEADLESS** | Headless toggle (auto-disabled on aarch64), profile id, restart-on-raid-end, bot caps per map | headless container |
| **MODS** | Empty / curated picks / BYO list, ModSync toggle, list URL field | mod selection, ModSync |
| **OPS** | Profile backups (enable / frequency / retention), auto-update toggles, restart policy, host-side log capture | profile backup, auto-update, log capture, restart policy |
| **ADV** | UID/GID, custom env passthrough, dev/debug toggles, MoreBots & ABPS bot-cap overrides | UID/GID, edge-case operational knobs |

Tab content detail (field-by-field — names, defaults, helpers, validation, env-var mapping) lives in `app/lib/schema.ts` in the configurator repo. The schema is the single source of truth; the form renders it; the YAML emitter consumes it. **DESIGN.md does not duplicate the field list** — the schema file is authoritative and will drift over time.

### 9c. Live preview

Right pane shows `docker-compose.yml` by default, with a small toggle for `.env` (the bundle has both). Syntax-highlighted via `shiki` (or `react-syntax-highlighter`; final pick deferred to implementation). Copy + download icons in the top-right of the panel.

### 9d. Bundle download

The "Download bundle" button at the bottom triggers a zip with:
- `docker-compose.yml` — generated from form state
- `.env` — generated from form state
- `README.md` — quick-start steps matching the QUICK START strip
- `setup-host.sh` (optional, opt-in checkbox) — see §12 (Phase 5)
- `systemd/*.service` — only when log-capture is enabled

Architecture-aware: on aarch64 hosts, the bundle omits headless service blocks entirely and the HEADLESS tab is greyed out in the UI.

### 9e. Behavioural rules

- **No backend.** The configurator is a static Next.js export. No data leaves the browser; the bundle is generated client-side and offered as a blob URL.
- **Version detection client-side.** On page load, fetch latest SPT and Fika versions from the GitHub releases API (`api.github.com`). Cache for 1h via `localStorage`. Fall back gracefully if rate-limited.
- **Form state survives reload.** Persist to `localStorage` so refreshing doesn't wipe a half-filled form.
- **Headless tab is reactive to arch.** A user-selectable "Host arch" radio in GENERAL controls whether HEADLESS is enabled — no `uname` shenanigans (we're in a browser).
- **Validation is inline.** Bad ports / paths / version pins show a red helper under the field. The download button is disabled while any error is present.

---

## 10. Server image publication

- Registry: **GHCR** under `ghcr.io/dildz/spt-fika-server` (under your account).
- Tags:
  - `:3.11.4` / `:4.0.13` — exact SPT version
  - `:3.11` / `:4.0` — track minor
  - `:lts` → currently `:3.11`
  - `:latest` → currently `:4.0`
- Built via `docker buildx build --platform linux/amd64,linux/arm64 --push` with `SPT_MAJOR` and `SPT_VERSION` build args matrix.
- Optional Docker Hub mirror later (kept lazy until publication needs demand it).

---

## 11. Headless handling

Decision (revised 2026-06-27): **maintain our own headless image, derived from Outshynd's clean wine-tkg build — don't pin zhliau.**

The earlier plan pinned zhliau because rebuilding Wine+EFT looked like a 1000+ line nightmare. Outshynd disproved that: a maintainable image (one Dockerfile + 3 small scripts) on **wine-tkg** (Kron4ek 11.2 staging-tkg wow64) with **ntsync** support. We base on it. EFT itself is still **mounted, never rebuilt** — the user bind-mounts their 60GB+ SPT+Fika+Headless install to `/opt/tarkov`.

Inherited from Outshynd's headless:
- wine-tkg prefix init with binary-checksum reinit; `/dev/ntsync` device passthrough for performance.
- **Structured exit codes** (10–16: empty-error / early-disconnect / plugin-load / wine-crash / backend-disconnect / config-changed) → clean restart-vs-park decisions.
- Crash watchdog (tails `wine.log`), `HALT_ON_CRASH` parking, quick-exit-as-crash detection.
- Fika config injection via env (`FIKA_FORCE_IP`, `FIKA_UDP_PORT`, NAT punching, UPnP) → maps to the configurator's HEADLESS tab.
- Backend wait-loop against `/launcher/ping`.

What we add on top:
- Companion systemd unit `fika-headless-logs.service` (host-side log capture — §2 constraint).

Still **x86-only** (§2): Wine+EFT can't run on ARM, so the headless service is simply absent from ARM bundles.

Insurance: keep both the `~/github-repos/fika-headless-docker-3.11` clone and the Outshynd file set as references; the Outshynd gists are the provenance for the base.

---

## 12. Phased build plan

Phases are gated on the **image repo** completing first. The configurator is meaningless without an image to deploy. The configurator and image evolve independently after Phase 1.

**Phase 1 — Image skeleton (`dildz/spt-fika-server`)**
- Restructure `next` branch per §6a (drop `install.sh`, `update.sh`, `.env.example`, top-level `docker-compose.yml`).
- Carry forward cosmetics from current `main` into `cosmetics/`.
- Multi-major Dockerfile per §7 (4.0 branch implemented; 3.11 branch stubbed behind §13 Q1).
- Document the env-var contract in `docs/env-vars.md` — this becomes the contract the configurator targets.

**Phase 2 — Image features**
- `install_fika.sh`, `auto_update.sh`, `profile_backup.sh`, `install_other_mods.sh`.
- Wire `init-server.sh` to call them based on env.
- Test 4.0 path end-to-end on the current x86 box.

**Phase 3 — Configurator (`dildz/setup-spt-fika-docker`, private)**
- Scaffold by copying from `/home/ubuntu/github-repos/Portfolio-Page` per §6b.
- Build the 6-tab form per §9b; live YAML preview per §9c.
- Bundle generator per §9d.
- Client-side version detection via GitHub releases API.
- Deploy as a sibling service behind the existing Caddy on the Oracle VPS.

**Phase 4 — Multi-arch image publish**
- Buildx pipeline, GHCR push.
- Test on the current x86 box AND one ARM host (Oracle Free Tier).
- Verify headless gating in the configurator on aarch64.

**Phase 5 — `setup-host.sh` (optional bundle component)**
- Bash script the configurator ships inside the bundle. Installs systemd `fika-*-logs.service` units, creates host dirs, sets UID/GID, optionally opens ufw ports.
- Opt-in via a checkbox on the OPS tab; bundle download adds it when checked.
- Idempotent; safe to re-run.

**Phase 6 — Optional CI**
- GH Actions on the image repo: watch SPT + Fika releases → bump versions → rebuild image → publish.
- GH Actions on the configurator repo: build + push container on every merge to `main` → trigger deploy on Oracle VPS.

**Merge `next` → `main` and rename the image repo `SPT-FIKA-OracleARM--Docker-Guide` → `spt-fika-server`** when Phase 4 ships and is verified end-to-end.

---

## 13. Open questions

### Image (Phase 1-2)
- **3.11.x Linux binary path — RESOLVED 2026-06-27** (from zhliau's `3.11.4` tag): build from source with Node 20 (`git clone sp-tarkov/server` [the TS repo], `git lfs pull`, `npm ci`, `npm run build:release`). The build emits **`SPT.Server.exe`** — a pkg-bundled Node single-executable run directly on Linux via `./SPT.Server.exe`. *Not* `Aki.Server`, *not* a separate Node entrypoint; runtime stage needs no .NET. **Both majors build-from-source** (4.0 = `server-csharp`/dotnet, 3.11 = `server`/Node), same clone→lfs→build→copy shape. Remaining sub-question: arm64 under buildx/QEMU — pkg fetches a per-arch Node base, so verify the 3.11 arm64 build actually succeeds under emulation (4.0's dotnet cross-publish is the safer of the two).
- **Fika compatibility matrix:** Where is the authoritative table mapping Fika version → SPT version? Probably `wiki.project-fika.com` or release notes; need a cached copy embedded in the configurator's schema for the VERSION tab.
- **Headless on 3.11 vs 4.0:** zhliau's headless says "tested 3.9.x, 3.10.x, 3.11.x, 4.0.x" — confirm whether the same image works across both, or whether we need separate `HEADLESS_TAG` per SPT major.
- **Mod compatibility detection:** if the configurator's MODS tab lets a user pick a 3.11-incompatible mod for a 4.0 build, do we warn inline? Defer to a per-mod manifest scheme; out of scope for Phase 3.
- **Storage layout on update:** does the image's `update.sh`-equivalent need different behaviour between 3.11 (Node user/profiles structure) and 4.0 (`SPT/user/profiles`)? Almost certainly yes — needs per-version backup config in `scripts/profile_backup.sh`.

### Configurator (Phase 3)
- **Hosting subdomain:** Confirm the URL — `setup-spt-fika.duckdns.org`? Something on a custom domain? Affects Caddyfile entry and any SEO copy.
- **GitHub releases API rate limits:** Anonymous calls are 60/hour per IP. Acceptable for individual hosts opening the page once, but a busy day could hit the limit. Need a graceful fallback (cached release lists shipped with the build, refreshed on each `next build`).
- **YAML preview library choice:** `shiki` (heavy but accurate) vs `react-syntax-highlighter` (lighter) vs DIY Tailwind classes (zero deps, ugly). Decide during implementation; not a blocker.
- **Form validation library:** plain React + custom validators, or `react-hook-form` + `zod`? The latter is ~30KB extra but pays back in DX and structured error rendering. Lean toward `zod` since the schema's already going to be typed.
- **Bundle versioning:** Should the downloaded bundle include a `version.json` stamp pointing back to the image tag it was generated for? Useful for `setup-host.sh` to verify compatibility on later re-runs. Probably yes.

### Bundle / setup-host.sh (Phase 5)
- **ufw vs iptables:** What firewall does the script assume on the host? Likely `ufw` (Ubuntu/Debian default) with `iptables` fallback.
- **`setup-host.sh` privileges:** Asks for sudo at the top, or expects the user to run it with sudo? Either is fine; pick one and document.

---

## 14. Out of scope (for this design)

- Web admin UI / status page
- Pelican panel integration
- Nvidia DGPU (passthrough only)
- Discord webhooks / alerting
- Snapshot/restore across hosts
- Bring-your-own-base-image (we pick the base image)
