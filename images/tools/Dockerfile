# syntax=docker/dockerfile:1.7
# images/tools/Dockerfile — the shared "tools" layer (ADR-0008, ADR-0011).
#
# Every agent CLI, MCP server and CyVerse utility is fetched by fetch.sh from
# resources.lock (sha256-verified), unpacked under /opt/vice, and exported from
# a scratch image that app images COPY --from. Base/builder images arrive as
# named bake contexts (ubuntu, golang, uv) pinned by digest in resources.hcl.
#
# Layout of the exported /opt/vice:
#   bin/            one entry per tool (binary or symlink); apps prepend to PATH
#   node/           Node.js runtime (nodejs)          npm/  npm ci tree (claude, codex, ccr, gemini, mcp-server-filesystem)
#   python/         CPython 3.13 with mesa-mcp, mesa-ducklake, duckdb (require-hashes)
#   aws-cli/        AWS CLI v2 install dir            gcm/  Git Credential Manager (self-contained)
#   cursor-agent/   Cursor agent package               goose/ Goose CLI files
#   MANIFEST.tsv    name, platform, version, sha256 of everything included
# NOTE: do not declare ARG TARGETPLATFORM/TARGETARCH globally (before the first
# FROM); a global declaration without a value shadows BuildKit's automatic values.

# ---------------------------------------------------------------------------
FROM ubuntu AS fetch
ARG TARGETPLATFORM
ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils bzip2 unzip
COPY resources.lock /resources.lock
COPY images/tools/fetch.sh /usr/local/bin/fetch.sh
RUN set -eu; for n in tini ttyd nodejs python gocmd gh git-credential-manager awscli duckdb ant opencode goose cursor-agent antigravity irods-mcp-server; do \
      fetch.sh "$n" "$TARGETPLATFORM" /dl; done && ls -la /dl

# ---------------------------------------------------------------------------
FROM ubuntu AS unpack
ARG TARGETPLATFORM
ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends xz-utils bzip2 unzip file
COPY --from=fetch /dl /dl
COPY resources.lock /resources.lock
RUN set -eux; V=/opt/vice; mkdir -p $V/bin; cd /dl; \
    # single binaries
    install -m 0755 tini-* $V/bin/tini; \
    install -m 0755 ttyd.* $V/bin/ttyd; \
    gunzip -c duckdb_cli-linux-*.gz > $V/bin/duckdb && chmod 0755 $V/bin/duckdb; \
    # tarballs with one binary inside
    mkdir -p /x/gocmd && tar -xzf gocmd-*.tar.gz -C /x/gocmd && install -m 0755 "$(find /x/gocmd -type f -name gocmd | head -1)" $V/bin/gocmd; \
    mkdir -p /x/gh && tar -xzf gh_*.tar.gz -C /x/gh && install -m 0755 "$(find /x/gh -type f -path '*/bin/gh' | head -1)" $V/bin/gh; \
    mkdir -p /x/ant && tar -xzf ant_*.tar.gz -C /x/ant && install -m 0755 "$(find /x/ant -type f -name ant | head -1)" $V/bin/ant; \
    mkdir -p /x/opencode && tar -xzf opencode-linux-*.tar.gz -C /x/opencode && install -m 0755 "$(find /x/opencode -type f -name opencode | head -1)" $V/bin/opencode; \
    # Antigravity ships one file named `antigravity`; its installer renames it to agy
    mkdir -p /x/agy && tar -xzf cli_linux_*.tar.gz -C /x/agy && install -m 0755 "$(find /x/agy -type f | head -1)" $V/bin/agy; \
    # multi-file packages kept whole, exposed through symlinks
    mkdir -p $V/goose && tar -xjf goose-*-unknown-linux-gnu.tar.bz2 -C $V/goose --strip-components=0 && \
      g="$(find $V/goose -type f -name goose | head -1)"; [ "$g" = "$V/goose/goose" ] || mv "$g" $V/goose/goose; chmod 0755 $V/goose/goose; ln -s $V/goose/goose $V/bin/goose; \
    mkdir -p $V/gcm && tar -xzf gcm-linux-*.tar.gz -C $V/gcm && chmod 0755 $V/gcm/git-credential-manager && ln -s $V/gcm/git-credential-manager $V/bin/git-credential-manager; \
    # Cursor: dist-package/cursor-agent is a wrapper that expects its siblings (bundled node, index.js); expose via a shell shim
    mkdir -p $V/cursor-agent && tar -xzf agent-cli-package.tar.gz -C $V/cursor-agent --strip-components=1 && chmod 0755 $V/cursor-agent/cursor-agent $V/cursor-agent/node && \
      printf '#!/bin/sh\nexec /opt/vice/cursor-agent/cursor-agent "$@"\n' > $V/bin/agent && chmod 0755 $V/bin/agent && cp $V/bin/agent $V/bin/cursor-agent; \
    mkdir -p /x/aws && unzip -q awscli-exe-linux-*.zip -d /x/aws && /x/aws/aws/install --install-dir $V/aws-cli --bin-dir $V/bin --update; \
    # runtimes
    mkdir -p $V/node && tar -xJf node-v*-linux-*.tar.xz -C $V/node --strip-components=1 && ln -s $V/node/bin/node $V/bin/node && ln -s $V/node/bin/npm $V/bin/npm && ln -s $V/node/bin/npx $V/bin/npx; \
    mkdir -p $V/python && tar -xzf cpython-3.13.*-install_only_stripped.tar.gz -C $V/python --strip-components=1; \
    rm -rf /x; ls -la $V/bin

# ---------------------------------------------------------------------------
FROM unpack AS node
ARG TARGETPLATFORM
COPY images/tools/npm/package.json images/tools/npm/package-lock.json /opt/vice/npm/
ENV PATH=/opt/vice/node/bin:$PATH
RUN cd /opt/vice/npm && npm ci --omit=dev --no-audit --no-fund --loglevel=warn --cache /tmp/npm-cache && \
    rm -rf /tmp/npm-cache && \
    for b in claude codex ccr gemini mcp-server-filesystem; do ln -s /opt/vice/npm/node_modules/.bin/$b /opt/vice/bin/$b; done && \
    ls -la /opt/vice/bin

# ---------------------------------------------------------------------------
FROM golang AS gobuild
ARG TARGETARCH
COPY --from=fetch /dl/irods-mcp-server.tar.gz /src.tar.gz
RUN mkdir -p /src && tar -xzf /src.tar.gz -C /src --strip-components=1 && cd /src && \
    CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH GOFLAGS=-mod=mod go build -trimpath -buildvcs=false -ldflags='-s -w' -o /out/irods-mcp-server ./cmd/main.go

# ---------------------------------------------------------------------------
FROM unpack AS pybuild
COPY --from=uv /usr/local/bin/uv /usr/local/bin/uv
COPY images/tools/python/requirements.txt /req.txt
ENV UV_PYTHON=/opt/vice/python/bin/python3 UV_NO_CACHE=1 UV_LINK_MODE=copy
RUN uv pip install --python /opt/vice/python/bin/python3 --require-hashes --no-deps -r /req.txt || \
    uv pip install --python /opt/vice/python/bin/python3 --require-hashes -r /req.txt
RUN for b in mesa-mcp mesa-ducklake; do ln -sf /opt/vice/python/bin/$b /opt/vice/bin/$b; done && \
    /opt/vice/python/bin/python3 -c "import duckdb, mesa_mcp; print('python ok', duckdb.__version__)" || /opt/vice/python/bin/python3 -c "import duckdb; print('python ok', duckdb.__version__)" && \
    find /opt/vice/python -name '__pycache__' -type d -prune -exec rm -rf {} + && \
    /opt/vice/python/bin/python3 -m compileall -q -j0 /opt/vice/python/lib >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
FROM scratch AS tools
COPY --from=unpack /opt/vice /opt/vice
COPY --from=node /opt/vice/npm /opt/vice/npm
COPY --from=node /opt/vice/bin /opt/vice/bin
COPY --from=pybuild /opt/vice/python /opt/vice/python
COPY --from=pybuild /opt/vice/bin/mesa-mcp /opt/vice/bin/mesa-ducklake /opt/vice/bin/
COPY --from=gobuild /out/irods-mcp-server /opt/vice/bin/irods-mcp-server
COPY resources.lock /opt/vice/MANIFEST.tsv

# ---------------------------------------------------------------------------
# Build-time smoke test: every tool answers --version on this platform.
FROM ubuntu AS tools-test
ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends ca-certificates git libicu74 libssl3
COPY --from=tools /opt/vice /opt/vice
ENV PATH=/opt/vice/bin:$PATH HOME=/tmp/home
RUN set -eu; mkdir -p $HOME; fail=0; \
    check() { printf '%-44s ' "$1"; if out=$(sh -c "$1" 2>&1); then echo "$out" | head -1; else echo "FAILED (exit $?): $(echo "$out" | head -1)"; fail=1; fi; }; \
    check "tini --version"; check "ttyd --version"; check "node --version"; check "gocmd --version"; check "gh --version"; \
    check "git-credential-manager --version"; check "aws --version"; check "duckdb --version"; check "ant --version"; \
    check "opencode --version"; check "goose --version"; check "agent --version"; check "agy --version"; \
    check "claude --version"; check "codex --version"; check "gemini --version"; check "ccr -h"; \
    check "mesa-mcp --help"; check "mesa-ducklake --help 2>&1 | grep -q unknown_verb"; check "irods-mcp-server --help"; \
    check "/opt/vice/python/bin/python3 -c 'import mesa_mcp, mesa_ducklake, duckdb; print(duckdb.__version__)'"; \
    check "test -f /opt/vice/MANIFEST.tsv"; \
    [ "$fail" = 0 ] || { echo "tools smoke test failed"; exit 1; }
