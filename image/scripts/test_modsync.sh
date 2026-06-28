#!/bin/bash
# Offline check for install_modsync.sh: verifies the SPT-4 game-root placement —
# server mod into the mount, client files (BepInEx + updater) up at the game root,
# config preserved on update, and redeploy-from-stash without re-downloading.
# Run: ./test_modsync.sh   (needs 7z to build the fixture; no network)
set -e
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

# Build a fixture release zip laid out for a game root.
s="$work/src"
mkdir -p "$s/BepInEx/plugins/Corter-ModSync" "$s/BepInEx/patchers" "$s/SPT/user/mods/Corter-ModSync"
echo dll  > "$s/BepInEx/plugins/Corter-ModSync/Corter-ModSync.dll"
echo pre  > "$s/BepInEx/patchers/Corter-ModSync-Prepatch.dll"
echo srv  > "$s/SPT/user/mods/Corter-ModSync/ModSync.Server.dll"
echo '{"default":true}' > "$s/SPT/user/mods/Corter-ModSync/config.jsonc"
echo exe  > "$s/ModSync.Updater.exe"
( cd "$s" && 7z a -tzip -bso0 "$work/fixture.zip" . >/dev/null )

gr="$work/gr"; SERVER="$gr/server"; mkdir -p "$SERVER"
run() { USE_MODSYNC=true MODSYNC_URL="file://$work/fixture.zip" "$here/install_modsync.sh" "$SERVER" "$@"; }

# 1. fresh install
run >/dev/null
[ -f "$SERVER/user/mods/Corter-ModSync/ModSync.Server.dll" ] || fail "server mod not in mount"
[ -f "$SERVER/user/mods/Corter-ModSync/config.jsonc" ]       || fail "config not installed"
[ -f "$gr/ModSync.Updater.exe" ]                              || fail "updater not at game root (../ would miss)"
[ -f "$gr/BepInEx/plugins/Corter-ModSync/Corter-ModSync.dll" ] || fail "client plugin not at game root"
[ -f "$gr/BepInEx/patchers/Corter-ModSync-Prepatch.dll" ]    || fail "headless patcher not at game root"
[ -d "$SERVER/.modsync/BepInEx" ]                            || fail "client files not stashed in mount"

# 2. config preserved on update
echo '{"mine":true}' > "$SERVER/user/mods/Corter-ModSync/config.jsonc"
USE_MODSYNC=true AUTO_UPDATE_MODSYNC=true MODSYNC_URL="file://$work/fixture.zip" "$here/install_modsync.sh" "$SERVER" >/dev/null
grep -q '"mine"' "$SERVER/user/mods/Corter-ModSync/config.jsonc" || fail "user config clobbered on update"

# 3. redeploy from stash without the URL (simulates a fresh container: game-root files gone)
rm -rf "$gr/BepInEx" "$gr/ModSync.Updater.exe"
USE_MODSYNC=true MODSYNC_URL="file://$work/NONEXISTENT.zip" "$here/install_modsync.sh" "$SERVER" >/dev/null
[ -f "$gr/ModSync.Updater.exe" ] || fail "did not redeploy updater from stash"
[ -f "$gr/BepInEx/plugins/Corter-ModSync/Corter-ModSync.dll" ] || fail "did not redeploy plugin from stash"

# 4. disabled = no-op
SERVER2="$work/gr2/server"; mkdir -p "$SERVER2"
USE_MODSYNC=false "$here/install_modsync.sh" "$SERVER2" | grep -q "disabled" || fail "USE_MODSYNC=false not skipped"
[ ! -d "$SERVER2/user/mods/Corter-ModSync" ] || fail "installed while disabled"

# 5. SPT 3.x = gated (don't install the 4.0 mod on a 3.11 server)
SERVER3="$work/gr3/server"; mkdir -p "$SERVER3"
USE_MODSYNC=true SPT_MAJOR=3 MODSYNC_URL="file://$work/fixture.zip" "$here/install_modsync.sh" "$SERVER3" | grep -q "SPT 4 only" || fail "SPT 3 not gated"
[ ! -d "$SERVER3/user/mods/Corter-ModSync" ] || fail "installed 4.0 mod on SPT 3"

echo "PASS"
