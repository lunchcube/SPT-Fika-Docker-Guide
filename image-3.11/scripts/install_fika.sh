#!/bin/bash
set -e
#
# Install the Fika server mod for SPT 3.11 (pre-C# project-fika/Fika-Server).
# Env-driven; runs each boot. Called as: install_fika.sh <game-root>
# 3.11 is FROZEN — no auto-update (install-once, then skip). Contract mirrors the
# 4.0 image (INSTALL_FIKA, FIKA_VERSION, NUM_HEADLESS_PROFILES).

ROOT="${1:?game root required}"      # 3.11 server runs from the game root
INSTALL_FIKA="${INSTALL_FIKA:-true}"
FIKA_VERSION="${FIKA_VERSION:-2.4.8}"

[ "$INSTALL_FIKA" = "true" ] || { echo "Fika install disabled (INSTALL_FIKA=false)"; exit 0; }

mod_dir="$ROOT/user/mods/fika-server"
config_rel="assets/configs/fika.jsonc"
artifact="fika-server-${FIKA_VERSION}.zip"
url="https://github.com/project-fika/Fika-Server/releases/download/v${FIKA_VERSION}/${artifact}"

install_fika() {
    echo "Installing Fika server mod v${FIKA_VERSION} (SPT 3.11)"
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL "$url" -o "$tmp/$artifact"
    # zip is rooted at user/mods/fika-server → extract straight into the game root
    unzip -q -o "$tmp/$artifact" -d "$ROOT"
    rm -rf "$tmp"
    echo "Fika installed"
}

if [ ! -d "$mod_dir" ]; then
    install_fika
else
    echo "Fika already installed (3.11 is frozen — no auto-update)"
fi

# Optional: set headless profile count (3.11.x uses the "headless" section in fika.jsonc).
if [ -n "$NUM_HEADLESS_PROFILES" ] && [ -f "$mod_dir/$config_rel" ]; then
    echo "Setting headless profile amount to $NUM_HEADLESS_PROFILES"
    patched="$(jq --argjson n "$NUM_HEADLESS_PROFILES" '.headless.profiles.amount = $n' "$mod_dir/$config_rel")" \
        && printf '%s' "$patched" > "$mod_dir/$config_rel"
fi
