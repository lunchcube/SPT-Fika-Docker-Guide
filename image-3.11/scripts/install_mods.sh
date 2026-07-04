#!/bin/bash
set -e
#
# Download + install extra mods from MOD_URLS. Env-driven; runs each boot.
# Called as: install_mods.sh <game-root>. Contract mirrors the 4.0 image (MOD_URLS).
#
# Each URL is downloaded once (tracked in .installed_mod_urls), extracted, and its
# standard SPT mod trees merged into the mount. 3.11 is a flat layout, so both
# user/ (server mods) and BepInEx/ (client mods) go straight to the game root.

ROOT="${1:?game root required}"
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
    [ -d "$tmp/x/user" ]    && { mkdir -p "$ROOT/user";    cp -a "$tmp/x/user/."    "$ROOT/user/"; }
    [ -d "$tmp/x/BepInEx" ] && { mkdir -p "$ROOT/BepInEx"; cp -a "$tmp/x/BepInEx/." "$ROOT/BepInEx/"; }
    rm -rf "$tmp"
    echo "$url" >> "$done_file"
    echo "  installed $file"
done
