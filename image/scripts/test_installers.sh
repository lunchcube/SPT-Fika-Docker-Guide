#!/bin/bash
# Offline check: install_mods.sh extracts a standard-layout .zip into the mount and
# is idempotent on re-run. No network — uses a file:// URL. Run: ./test_installers.sh
set -e
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

# Fixture mod with both a server mod (user/mods) and a client mod (BepInEx/plugins).
mkdir -p "$work/src/user/mods/testmod" "$work/src/BepInEx/plugins/clientmod" "$work/root"
echo hi  > "$work/src/user/mods/testmod/x.txt"
echo dll > "$work/src/BepInEx/plugins/clientmod/c.dll"
( cd "$work/src" && 7z a -tzip -bso0 "$work/testmod.zip" . >/dev/null )

MOD_URLS="file://$work/testmod.zip" "$here/install_mods.sh" "$work/root" >/dev/null
[ -f "$work/root/SPT/user/mods/testmod/x.txt" ]        || { echo "FAIL: server mod not in SPT/user/mods"; exit 1; }
[ -f "$work/root/BepInEx/plugins/clientmod/c.dll" ]    || { echo "FAIL: client mod not at game-root BepInEx"; exit 1; }

# second run must skip (tracked in .installed_mod_urls at the game root)
out="$(MOD_URLS="file://$work/testmod.zip" "$here/install_mods.sh" "$work/root")"
echo "$out" | grep -q "Already installed" || { echo "FAIL: not idempotent"; exit 1; }

# empty MOD_URLS is a no-op
MOD_URLS="" "$here/install_mods.sh" "$work/root" | grep -q "skipping" || { echo "FAIL: empty not skipped"; exit 1; }

echo "PASS"
