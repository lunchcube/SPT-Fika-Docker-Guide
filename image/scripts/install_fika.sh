#!/bin/bash
set -e
#
# Install / update the Fika server mod (4.0 C# build). Env-driven; runs each boot.
# Called from init-server.sh as: install_fika.sh <server-dir>
# Contract: docs/env-vars.md (INSTALL_FIKA, FIKA_VERSION, AUTO_UPDATE_FIKA, NUM_HEADLESS_PROFILES)

SERVER="${1:?server dir required}"
INSTALL_FIKA="${INSTALL_FIKA:-true}"
FIKA_VERSION="${FIKA_VERSION:-2.3.2}"
AUTO_UPDATE_FIKA="${AUTO_UPDATE_FIKA:-false}"

[ "$INSTALL_FIKA" = "true" ] || { echo "Fika install disabled (INSTALL_FIKA=false)"; exit 0; }

mod_dir="$SERVER/user/mods/fika-server"
config_rel="assets/configs/fika.jsonc"
artifact="Fika.Server.Release.${FIKA_VERSION}.zip"
url="https://github.com/project-fika/Fika-Server-CSharp/releases/download/v${FIKA_VERSION}/${artifact}"

install_fika() {
    echo "Installing Fika server mod v${FIKA_VERSION}"
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL "$url" -o "$tmp/$artifact"
    unzip -q "$tmp/$artifact" -d "$tmp/x"
    mv "$tmp/x/SPT/user/mods/fika-server" "$SERVER/user/mods/"   # artifact ships SPT/user/mods/fika-server
    rm -rf "$tmp"
    echo "Fika installed"
}

if [ ! -d "$mod_dir" ]; then
    install_fika
elif [ "$AUTO_UPDATE_FIKA" = "true" ]; then
    echo "AUTO_UPDATE_FIKA=true — reinstalling Fika v${FIKA_VERSION}, preserving config"
    saved=""
    [ -f "$mod_dir/$config_rel" ] && { saved="$(mktemp)"; cp "$mod_dir/$config_rel" "$saved"; }
    rm -rf "$mod_dir"
    install_fika
    [ -n "$saved" ] && { mkdir -p "$mod_dir/$(dirname "$config_rel")"; cp "$saved" "$mod_dir/$config_rel"; rm -f "$saved"; }
else
    echo "Fika already installed (set AUTO_UPDATE_FIKA=true to reinstall v${FIKA_VERSION})"
fi

# Optional: set headless profile count. ponytail: jq treats the .jsonc as plain JSON
# (mirrors zhliau); if Fika ever ships real comments in fika.jsonc, swap to a jsonc parser.
if [ -n "$NUM_HEADLESS_PROFILES" ] && [ -f "$mod_dir/$config_rel" ]; then
    echo "Setting headless profile amount to $NUM_HEADLESS_PROFILES"
    patched="$(jq --argjson n "$NUM_HEADLESS_PROFILES" '.headless.profiles.amount = $n' "$mod_dir/$config_rel")" \
        && printf '%s' "$patched" > "$mod_dir/$config_rel"
fi
