# SPT 3.11 server — self-contained, build-from-source. Clean base (no Fika baked in).
# Build-once: SPT 3.11 is frozen (last release 3.11.4). Built + booted on arm64.
#
#   docker build -t spt-fika-server-3.11.x:3.11.4 .
#
# Build it natively per arch (the pkg binary is per-arch); CI does amd64 + arm64
# on native runners. No external scripts — this file clones and builds everything.

ARG SPT_VERSION=3.11.4

# ---------- build ----------
FROM debian:bookworm AS build
ARG SPT_VERSION
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git git-lfs xz-utils \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "$SPT_VERSION" \
        https://github.com/sp-tarkov/server.git /src
WORKDIR /src/project
RUN git lfs pull
# 3.11 ships no package-lock.json (so npm install, not ci); setEncoding strip is
# the 2024 guide's known workaround for the pkg build.
RUN sed -i '/setEncoding/d' src/Program.ts || true
RUN npm install \
 && npm run build:release \
 && mv build /opt/SPT
RUN chmod +x /opt/SPT/SPT.Server.exe

# ---------- runtime ----------
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/SPT
COPY --from=build /opt/SPT /opt/SPT
EXPOSE 6969
ENTRYPOINT ["./SPT.Server.exe"]
