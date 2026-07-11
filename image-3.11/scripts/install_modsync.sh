#!/bin/bash
set -e
#
# Install Corter's ORIGINAL ModSync for SPT 3.11 (c-orter/ModSync). Env-driven.
# Called as: install_modsync.sh <game-root>
#
# 3.11 is FROZEN — no auto-update (install-once, then skip).
# The 3.11 release zip is rooted at BepInEx/ + ModSync.Updater.exe + user/mods/
# Corter-ModSync/ — and the 3.11 server runs from the game root, so the whole
# archive extracts straight into the mount (no ../ split like the SPT4 fork needs).

ROOT="${1:?game root required}"
USE_MODSYNC="${USE_MODSYNC:-false}"
MODSYNC_VERSION="${MODSYNC_VERSION:-0.11.1}"

[ "$USE_MODSYNC" = "true" ] || { echo "ModSync disabled (USE_MODSYNC=false)"; exit 0; }

mod_dir="$ROOT/user/mods/Corter-ModSync"
artifact="Corter-ModSync-v${MODSYNC_VERSION}.zip"
url="${MODSYNC_URL:-https://github.com/c-orter/ModSync/releases/download/v${MODSYNC_VERSION}/${artifact}}"

install_modsync() {
    echo "Installing Corter ModSync v${MODSYNC_VERSION} (SPT 3.11)"
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL "$url" -o "$tmp/ms.zip"
    unzip -q -o "$tmp/ms.zip" -d "$ROOT"
    rm -rf "$tmp"
    echo "ModSync installed"
}

if [ ! -d "$mod_dir" ]; then
    install_modsync
else
    echo "ModSync already installed (3.11 is frozen — no auto-update)"
fi
