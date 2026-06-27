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

Phase 0 — design complete, implementation not started. See `DESIGN.md` §12 for the phase plan.
