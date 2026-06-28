#!/bin/bash
set -e
#
# Download + install extra mods from MOD_URLS. Env-driven; runs each boot.
# Called from init-server.sh as: install_mods.sh <server-dir>
# Contract: docs/env-vars.md (MOD_URLS)
#
# Each URL is downloaded once (tracked in .installed_mod_urls), extracted, and its
# standard SPT mod trees (user/ and/or BepInEx/) merged into the mount.
# ponytail: handles .zip and .7z (the two formats SPT mods actually ship as) and
# assumes those trees sit at the archive root; add tar / nested-dir search only if a
# real mod needs it. zhliau's download_unzip_install_mods.sh is the fuller reference.

ROOT="${1:?game root required}"
SPT="$ROOT/SPT"   # server mods live in SPT/user/mods; client mods (BepInEx) at the game root
[ -n "${MOD_URLS:-}" ] || { echo "No MOD_URLS set — skipping extra mods"; exit 0; }

done_file="$ROOT/.installed_mod_urls"
touch "$done_file"

for url in $MOD_URLS; do
    if grep -qxF "$url" "$done_file"; then
        echo "Already installed: $url"
        continue
    fi
    echo "Downloading mod: $url"
    tmp="$(mktemp -d)"
    file="$(cd "$tmp" && curl -fsSL -OJ -w '%{filename_effective}' "$url")"
    case "$file" in
        *.zip) unzip -qo "$tmp/$file" -d "$tmp/x" ;;
        *.7z)  7z x -y -o"$tmp/x" "$tmp/$file" >/dev/null ;;
        *) echo "  Unsupported archive '$file' — skipping"; rm -rf "$tmp"; continue ;;
    esac
    [ -d "$tmp/x/user" ]    && { mkdir -p "$SPT/user";  cp -a "$tmp/x/user/."    "$SPT/user/"; }    # server mods → SPT/user/mods
    [ -d "$tmp/x/BepInEx" ] && { mkdir -p "$ROOT/BepInEx"; cp -a "$tmp/x/BepInEx/." "$ROOT/BepInEx/"; }  # client mods → game root (ModSync serves these)
    rm -rf "$tmp"
    echo "$url" >> "$done_file"
    echo "  installed $file"
done
