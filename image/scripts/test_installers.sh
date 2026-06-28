#!/bin/bash
# Offline check: install_mods.sh extracts a standard-layout .zip into the mount and
# is idempotent on re-run. No network — uses a file:// URL. Run: ./test_installers.sh
set -e
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

mkdir -p "$work/src/user/mods/testmod" "$work/server/user/mods"
echo hi > "$work/src/user/mods/testmod/x.txt"
( cd "$work/src" && 7z a -tzip -bso0 "$work/testmod.zip" . >/dev/null )

MOD_URLS="file://$work/testmod.zip" "$here/install_mods.sh" "$work/server" >/dev/null
[ -f "$work/server/user/mods/testmod/x.txt" ] || { echo "FAIL: mod not installed"; exit 1; }

# second run must skip (tracked in .installed_mod_urls)
out="$(MOD_URLS="file://$work/testmod.zip" "$here/install_mods.sh" "$work/server")"
echo "$out" | grep -q "Already installed" || { echo "FAIL: not idempotent"; exit 1; }

# empty MOD_URLS is a no-op
MOD_URLS="" "$here/install_mods.sh" "$work/server" | grep -q "skipping" || { echo "FAIL: empty not skipped"; exit 1; }

echo "PASS"
