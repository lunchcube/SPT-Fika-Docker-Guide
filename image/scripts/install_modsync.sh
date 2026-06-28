#!/bin/bash
set -e
#
# Install the Corter-ModSync server mod (Dildz SPT 4.0 fork) and the client files the
# server is required to serve. Env-driven; runs each boot.
# Called from init-server.sh: install_modsync.sh <server-dir>
# Contract: docs/env-vars.md (USE_MODSYNC, MODSYNC_VERSION, AUTO_UPDATE_MODSYNC)
#
# SPT 4 placement (from the mod's own code — ModSync.Server/ModSyncMod.cs): the server
# runs from <gameRoot>/SPT/ and, RELATIVE TO ITS CWD, hard-requires:
#   ../ModSync.Updater.exe                                (desktop updater it serves)
#   ../BepInEx/plugins/Corter-ModSync/Corter-ModSync.dll  (client plugin it serves)
# It refuses to load if either is missing. In this image the server's cwd is the bind
# mount ($SERVER = the SPT/ dir), so the "game root" is its parent. We map the release
# zip (laid out for a game root) onto that:
#   zip SPT/user/mods/Corter-ModSync  -> $SERVER/user/mods/Corter-ModSync   (persistent mount)
#   zip BepInEx/  +  ModSync.Updater.exe  -> $SERVER/..  (game root, where the server looks)
# The game-root files live OUTSIDE the mount, so they vanish on a fresh container — we
# stash them in the mount and redeploy them up to the game root on every boot.
# (This is the step zhliau's generic installer gets wrong on 4.0: it leaves the .exe in
#  the SPT install dir, so ../ModSync.Updater.exe misses — see the Discord report.)

SERVER="${1:?server dir required}"
USE_MODSYNC="${USE_MODSYNC:-false}"
MODSYNC_VERSION="${MODSYNC_VERSION:-0.12.5}"
AUTO_UPDATE_MODSYNC="${AUTO_UPDATE_MODSYNC:-false}"

[ "$USE_MODSYNC" = "true" ] || { echo "ModSync disabled (USE_MODSYNC=false)"; exit 0; }

# SPT 4 only: this installs the Dildz/ModSync-for-SPT4.0 fork with the SPT-4 game-root
# layout. SPT 3.11 needs Corter's original mod and a different (server-root) placement —
# not wired yet. Skip rather than install the wrong mod in the wrong place.
if [ "${SPT_MAJOR:-4}" != "4" ]; then
    echo "ModSync auto-install supports SPT 4 only (SPT_MAJOR=${SPT_MAJOR:-4}); skipping. For 3.11, install Corter's original ModSync via MOD_URLS."
    exit 0
fi

gameroot="$(dirname "$SERVER")"                 # cwd at runtime is $SERVER; the mod looks ../ = here
mod_dir="$SERVER/user/mods/Corter-ModSync"
stash="$SERVER/.modsync"                        # client files cached in the mount (persist)
config_rel="config.jsonc"
artifact="Corter-ModSync-v${MODSYNC_VERSION}.zip"
url="${MODSYNC_URL:-https://github.com/Dildz/ModSync-for-SPT4.0/releases/download/v${MODSYNC_VERSION}/${artifact}}"

# Download + lay down the server mod (preserving an existing server config) and stash
# the client files (BepInEx + updater) in the mount.
install_modsync() {
    echo "Installing ModSync v${MODSYNC_VERSION}"
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL "$url" -o "$tmp/ms.zip"
    unzip -q "$tmp/ms.zip" -d "$tmp/x"

    local saved=""
    [ -f "$mod_dir/$config_rel" ] && { saved="$(mktemp)"; cp "$mod_dir/$config_rel" "$saved"; }
    rm -rf "$mod_dir"; mkdir -p "$SERVER/user/mods"
    cp -a "$tmp/x/SPT/user/mods/Corter-ModSync" "$SERVER/user/mods/"
    [ -n "$saved" ] && { cp "$saved" "$mod_dir/$config_rel"; rm -f "$saved"; echo "  kept existing config.jsonc"; }

    rm -rf "$stash"; mkdir -p "$stash"
    cp -a "$tmp/x/BepInEx" "$stash/"
    cp -f "$tmp/x/ModSync.Updater.exe" "$stash/"
    rm -rf "$tmp"
    echo "ModSync installed"
}

# Copy the stashed client files up to the game root, where the server mod expects them.
# Idempotent; runs every boot because the game root is outside the persistent mount.
deploy_client_files() {
    [ -d "$stash/BepInEx" ] || { echo "WARNING: ModSync client files missing from stash"; return; }
    mkdir -p "$gameroot/BepInEx"
    cp -a "$stash/BepInEx/." "$gameroot/BepInEx/"
    cp -f "$stash/ModSync.Updater.exe" "$gameroot/ModSync.Updater.exe"
    chmod -R a+rX "$gameroot/BepInEx" "$gameroot/ModSync.Updater.exe"   # runtime (gosu) user only reads these
}

if [ ! -d "$mod_dir" ] || [ ! -d "$stash/BepInEx" ] || [ "$AUTO_UPDATE_MODSYNC" = "true" ]; then
    install_modsync
fi
deploy_client_files
echo "ModSync ready: server mod in user/mods/Corter-ModSync, client files at $gameroot"
