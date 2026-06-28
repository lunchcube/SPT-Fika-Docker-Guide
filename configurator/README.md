# configurator/

The web configurator (Phase 3) — a **single static page** (plain HTML/CSS/JS, no
framework, no build step). It renders a tabbed form, previews the
`docker-compose.yml` + `.env` it generates live, and downloads a ready-to-run
`.zip` bundle. Nothing leaves the browser; there's no backend.

The form mirrors **[../docs/env-vars.md](../docs/env-vars.md)** — the image's
real env-var contract is the source of truth.

## Files

| File | What |
|---|---|
| `index.html` | Page layout (hero, quick-start strip, tabs + live preview, checklist) |
| `app.js` | Schema (the form surface), emitters (compose / `.env` / README), validation, localStorage |
| `zip.js` | Tiny store-only zip writer (browser + Node) |
| `styles.css` | Dark theme |
| `test_zip.cjs` | Offline check for the zip writer (`node test_zip.cjs`, needs `unzip`) |
| `deploy/` | `Dockerfile` (nginx), `docker-compose.yml`, `caddy-snippet.txt` |

## Develop

It's static — just open `index.html` in a browser, or serve the folder:

```bash
python3 -m http.server -d configurator 8000   # → http://localhost:8000
node configurator/test_zip.cjs                 # verify the zip writer
```

## Deploy (behind the shared Caddy proxy)

```bash
cd configurator/deploy
docker compose up -d --build           # joins caddy-proxy-network, no published ports
```

Then add the block from `deploy/caddy-snippet.txt` to your Caddyfile and reload Caddy.

## Deliberately deferred (ponytail)

- **Live version detection** (GitHub releases API) — version fields are free-text
  with known-good defaults instead. Add later if pinning gets annoying.
- **Syntax highlighting** — plain `<pre>` with line numbers; no highlighter dependency.
- **Presets** — the defaults already are the "common Fika server" preset.
