# Environment variables — the image contract

This is the **authoritative** list of knobs the image exposes. The web
configurator's schema (`configurator/lib/schema.ts`) mirrors this file; the
`image/` scripts are the implementation. If they disagree, **the code wins** —
fix this doc to match `init-server.sh` and `scripts/`, not the reverse.

Status legend: **live** = implemented and verified · **Phase 2** = implemented,
unverified end-to-end · **deferred** = not built yet (see bottom).

## Build-time (Docker `--build-arg`)

These bake a specific SPT into the image; you can't change them at `docker run`.
Updating SPT means building (or pulling) a new image tag.

| Arg | Default | Meaning |
|---|---|---|
| `SPT_MAJOR` | `4` | `4` = C#/.NET build (live). `3` = 3.11 Node build (present, unverified). |
| `SPT_VERSION` | `4.0.13` | A valid tag/branch of the matching `sp-tarkov` repo (`server-csharp` for 4.x, `server` for 3.11.x). |

```
docker build image/ -t spt-fika-server:4.0.13 \
    --build-arg SPT_MAJOR=4 --build-arg SPT_VERSION=4.0.13
```

## Runtime — core (live)

Read by `init-server.sh` on every boot.

| Var | Default | Meaning |
|---|---|---|
| `PUID` | `1000` | UID the server runs as / owns the bind mount. |
| `PGID` | `1000` | GID the server runs as. |
| `USER_NAME` | `spt` | Name for a created user (ignored if `PUID` already exists). |
| `GROUP_NAME` | `spt` | Name for a created group (ignored if `PGID` already exists). |
| `SPT_MAJOR` | baked from build | Picks the run command (`dotnet SPT.Server.dll` for 4, `SPT.Server.exe` for 3). Normally inherited from the image; override only to force a path. |
| `VERBOSE_LOGS` | `true` | `false` filters high-frequency request spam (`keepalive`, `ping`, Fika `heartbeat`/`items`). |
| `LISTEN_ALL_NETWORKS` | `false` | `true` patches `http.json` to bind `0.0.0.0` (needed for LAN / Fika clients). |

## Runtime — Fika (Phase 2)

Read by `scripts/install_fika.sh`. Runs each boot; safe on an already-set-up mount.

| Var | Default | Meaning |
|---|---|---|
| `INSTALL_FIKA` | `true` | Install the Fika server mod into `user/mods/fika-server` if absent. `false` skips entirely. |
| `FIKA_VERSION` | `2.3.2` | Release tag of [`project-fika/Fika-Server-CSharp`](https://github.com/project-fika/Fika-Server-CSharp/releases) to install. |
| `AUTO_UPDATE_FIKA` | `false` | If Fika is already installed and this is `true`, reinstall `FIKA_VERSION` in place, preserving `fika.jsonc`. If `false`, an existing install is left untouched. |
| `NUM_HEADLESS_PROFILES` | _(unset)_ | If set, writes `headless.profiles.amount` in `fika.jsonc`. Leave unset for a non-headless server. |

## Runtime — extra mods (Phase 2)

Read by `scripts/install_mods.sh`.

| Var | Default | Meaning |
|---|---|---|
| `MOD_URLS` | _(empty)_ | Whitespace/newline-separated archive URLs. Each is downloaded once (tracked in `.installed_mod_urls`), extracted, and its `user/` + `BepInEx/` trees merged into the mount. Empty = no extra mods. Supports `.zip` and `.7z`; archives must carry `user/` and/or `BepInEx/` at their root. |

## Runtime — ModSync (Phase 2)

Read by `scripts/install_modsync.sh`. Installs the [Corter-ModSync](https://github.com/Dildz/ModSync-for-SPT4.0)
server mod (the SPT 4.0 fork) so clients keep their mods in sync with the server.

| Var | Default | Meaning |
|---|---|---|
| `USE_MODSYNC` | `false` | Install the ModSync server mod. Off by default (opt-in). **SPT 4 only** — ignored (with a logged skip) when `SPT_MAJOR=3`, since 3.11 needs Corter's original mod and a different layout. |
| `MODSYNC_VERSION` | `0.12.5` | Release tag (without the `v`) of `Dildz/ModSync-for-SPT4.0` to install. |
| `AUTO_UPDATE_MODSYNC` | `false` | Reinstall the pinned version on boot if already present, preserving your `config.jsonc`. |
| `MODSYNC_URL` | _(derived)_ | Override the release-zip URL (e.g. a self-hosted mirror, or `file://` for testing). Normally leave unset. |

**Placement note (SPT 4 specific):** the ModSync server mod loads only if the desktop
updater and the client plugin exist *one level above* the SPT install — at `../ModSync.Updater.exe`
and `../BepInEx/plugins/...` (the SPT-4 server runs from `<gameRoot>/SPT/`). The script puts the
server mod in the mount (`user/mods/Corter-ModSync`, where your `config.jsonc` persists) and the
client files at the game root (`/opt`, outside the mount), redeploying them on each boot. Getting
this wrong is the `'../ModSync.Updater.exe' not found` failure seen with generic mod installers.

## Not env vars — handled elsewhere

- **Profile backups.** SPT 4.0 backs profiles up natively (`SPT_Data/configs/backup.json`
  → `Saves`). We expose no `ENABLE_PROFILE_BACKUP` / cron — that reinvents a built-in
  (zhliau's image deprecated theirs for the same reason). Tune SPT's own setting in
  `SPT_Data/configs/`.

## Deferred (not built)

- **`AUTO_UPDATE_SPT`.** With build-from-source, each image *is* a pinned SPT version,
  so the normal update path is "pull a new image tag and `docker compose up -d`". A boot-time
  re-seed (back up mount → recopy `/opt/SPT` binaries + `SPT_Data`, preserve `user/`) is a real
  but separate feature with data-clobbering edge cases — left for a follow-up. `seed_server`
  currently only seeds a *fresh* mount and warns on an existing one.
