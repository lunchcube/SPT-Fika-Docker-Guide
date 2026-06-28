# SPT-Fika-Docker

> ⚠️ **The `UI-Configurator` branch is the v2 rework — work in progress.**
> A web configurator + multi-arch Docker image for self-hosting an SPT-FIKA stack.
> See **[DESIGN.md](DESIGN.md)** for the full architecture and phased build plan.
>
> The current stable guide lives on the [`main`](../../tree/main) branch.

## What this will be

Two surfaces, one image-driven contract:

1. **A web configurator** — pick your options in a browser, download a ready-to-run bundle (`docker-compose.yml` + `.env`), `docker compose up -d`.
2. **A multi-arch Docker image** (`linux/amd64` + `linux/arm64`) — SPT 3.11 (LTS) and 4.0, Fika, headless, all driven by env vars. Both SPT majors are **built from source** (4.0 = `server-csharp`/dotnet, 3.11 = `server`/Node).

## Repo layout (monorepo)

| Path | What |
|---|---|
| `image/` | The Docker image — `Dockerfile`, `scripts/`, `cron/`, `cosmetics/`, `headless/`, `mod-pack/` |
| `configurator/` | The Next.js web configurator (Phase 3) |
| `docs/` | Env-var contract, operations, troubleshooting |
| `DESIGN.md` | Architecture + phased build plan |

## Status

**Phase 2 (4.0) done — verified.** The 4.0 image builds from source, boots a verified SPT 4.0 server
(`SPT.Server.dll` run via `dotnet`), and on boot installs the **Fika server mod** plus any extra mods you
list — all env-driven. Still to come: the Phase 3 web configurator and the 3.11 build path. See
`DESIGN.md` §12 for the full phase plan.

## Configure

Everything is driven by environment variables — see **[docs/env-vars.md](docs/env-vars.md)** for the full
contract. The common ones:

| Var | Default | Does |
|---|---|---|
| `INSTALL_FIKA` | `true` | Installs the Fika server mod on first boot |
| `FIKA_VERSION` | `2.3.2` | Which [Fika-Server-CSharp](https://github.com/project-fika/Fika-Server-CSharp/releases) release to install |
| `MOD_URLS` | _(empty)_ | Whitespace-separated archive URLs (`.zip`/`.7z`) to download + install |
| `LISTEN_ALL_NETWORKS` | `false` | Bind `0.0.0.0` so LAN / Fika clients can connect |
| `PUID` / `PGID` | `1000` | UID/GID the server runs as and that owns your bind mount |

## Build & test the image (dev, 4.0)

Build amd64 locally and smoke-test in an isolated container — use a free host port + throwaway volume so it
never collides with a running server:

```bash
# build (amd64). SPT_VERSION must be a valid sp-tarkov/server-csharp tag.
docker build image/ -t spt-fika-server:4.0.13 \
    --build-arg SPT_MAJOR=4 --build-arg SPT_VERSION=4.0.13

# run isolated, then watch it boot
docker run -d --name spt-test -p 6979:6969 -v "$PWD/.test-data":/opt/server spt-fika-server:4.0.13
docker logs -f spt-test            # → "Installing Fika server mod" → "Server has started, happy playing"
curl -k https://localhost:6979/launcher/ping

# tear down
docker rm -f spt-test && rm -rf .test-data
```

The installer scripts have an offline self-check: `bash image/scripts/test_installers.sh`.

> ARM64 builds compile under QEMU emulation (slow) and aren't wired up yet — that's Phase 4.
