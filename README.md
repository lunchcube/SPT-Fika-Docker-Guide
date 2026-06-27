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

**Phase 1 in progress.** The 4.0 image **builds from source and boots a verified SPT 4.0 server**
(`SPT.Server.dll` run via `dotnet`). Still to come: `docs/env-vars.md`, the Phase 2 feature scripts, and the
3.11 build path. See `DESIGN.md` §12 for the full phase plan.

## Build & test the image (dev, 4.0)

Build amd64 locally and smoke-test in an isolated container — use a free host port + throwaway volume so it
never collides with a running server:

```bash
# build (amd64). SPT_VERSION must be a valid sp-tarkov/server-csharp tag.
docker build image/ -t spt-fika-server:4.0.13 \
    --build-arg SPT_MAJOR=4 --build-arg SPT_VERSION=4.0.13

# run isolated, then watch it boot
docker run -d --name spt-test -p 6979:6969 -v "$PWD/.test-data":/opt/server spt-fika-server:4.0.13
docker logs -f spt-test            # → "Server has started, happy playing"
curl -k https://localhost:6979/launcher/ping

# tear down
docker rm -f spt-test && rm -rf .test-data
```

> ARM64 builds compile under QEMU emulation (slow) and aren't wired up yet — that's Phase 4.
