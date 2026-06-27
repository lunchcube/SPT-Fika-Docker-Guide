#!/bin/bash
set -e
#
# SPT-FIKA-Docker entrypoint (Phase 1).
# Brings up a vanilla SPT server. The 4.0 path is implemented; the 3.11 run-command
# is branched but unverified. Everything below is driven by env vars — this set is
# the contract the web configurator targets (docs/env-vars.md).

# ---- env (user-configurable) ----
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
USER_NAME="${USER_NAME:-spt}"
GROUP_NAME="${GROUP_NAME:-spt}"
SPT_MAJOR="${SPT_MAJOR:-4}"
VERBOSE_LOGS="${VERBOSE_LOGS:-true}"
LISTEN_ALL_NETWORKS="${LISTEN_ALL_NETWORKS:-false}"

# ---- paths ----
IMAGE_SRC=/opt/SPT      # server compiled into the image (read-only baseline)
SERVER=/opt/server      # host bind mount — persistent server files (profiles, mods, configs)

orange="\033[38;5;208m"; reset="\033[0m"

banner() {
    echo "========================================================="
    echo "==  SPT-FIKA-Docker  |  SPT_MAJOR=$SPT_MAJOR  UID=$PUID:$PGID  =="
    echo "========================================================="
}

# Create the runtime user/group, reusing any that already own the mount.
setup_user_and_group() {
    getent group  "$PGID" >/dev/null || groupadd -g "$PGID" "$GROUP_NAME"
    getent passwd "$PUID" >/dev/null || useradd -u "$PUID" -g "$PGID" -d "$SERVER" -s /bin/sh "$USER_NAME"
    GROUP_NAME="$(getent group  "$PGID" | cut -d: -f1)"
    USER_NAME="$(getent passwd "$PUID" | cut -d: -f1)"
}

# First boot: copy the image-built server into the (empty) bind mount, so server
# files persist on the host. Re-seeding / version updates are Phase 2.
seed_server() {
    if [ -z "$(ls -A "$SERVER" 2>/dev/null)" ]; then
        echo -e "${orange}Note: $SERVER is empty — bind-mount a host dir here to persist server files.${reset}"
    fi
    if [ ! -e "$SERVER/SPT_Data" ]; then
        echo "First boot — seeding server files into $SERVER"
        cp -a "$IMAGE_SRC/." "$SERVER/"
    else
        echo "Existing server files found in $SERVER (version updates handled in Phase 2)"
    fi
    mkdir -p "$SERVER/user/mods" "$SERVER/user/profiles"
    chown -R "$PUID:$PGID" "$SERVER"
}

# Make the server bind to all interfaces (needed for LAN / Fika clients).
listen_all_networks() {
    local http="$SERVER/SPT_Data/configs/http.json"
    if [ "$LISTEN_ALL_NETWORKS" = "true" ] && [ -f "$http" ]; then
        local patched
        patched="$(jq '.ip = "0.0.0.0" | .backendIp = "0.0.0.0"' "$http")" \
            && printf '%s' "$patched" > "$http"
        echo "Server set to listen on all networks (0.0.0.0)"
    fi
}

run_server() {
    cd "$SERVER"
    case "$SPT_MAJOR" in
        4) set -- dotnet "$SERVER/SPT.Server.dll" ;;   # 4.0: framework-dependent C# build
        3) set -- "$SERVER/SPT.Server.exe" ;;          # 3.11: pkg Node bundle (UNVERIFIED)
        *) echo "FATAL: unsupported SPT_MAJOR=$SPT_MAJOR" >&2; exit 1 ;;
    esac

    echo "Starting SPT $SPT_MAJOR server as $USER_NAME:$GROUP_NAME"
    if [ "$VERBOSE_LOGS" = "true" ]; then
        exec gosu "$USER_NAME:$GROUP_NAME" "$@"
    else
        # Filter the high-frequency request spam; keep everything else.
        echo "Log filtering on (set VERBOSE_LOGS=true to disable)"
        exec gosu "$USER_NAME:$GROUP_NAME" "$@" 2>&1 | grep --line-buffered -Ev \
            -e '/client/game/keepalive' -e '/launcher/ping' \
            -e '/fika/api/items' -e '/fika/api/heartbeat'
    fi
}

banner
setup_user_and_group
seed_server
listen_all_networks
run_server
