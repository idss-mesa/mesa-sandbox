# syntax=docker/dockerfile:1.7
# mesa-vscode — ghcr.io/coder/code-server (user `coder`, UID 1000, no s6/root)
# + the MESA agent toolchain. Auth none behind the VICE proxy, no sudo.
FROM base AS app
ARG DEBIAN_FRONTEND=noninteractive
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      tmux git openssh-client gettext-base jq unzip xz-utils bzip2 less bubblewrap socat libicu74 libssl3 python3 && \
    rm -rf /var/lib/apt/lists/*
COPY --from=tools /opt/vice /opt/vice
COPY images/common /opt/vice/common
RUN /opt/vice/common/install-common.sh && rm -rf /opt/vice/common
COPY --chmod=755 images/vscode/entry.sh /opt/vice/bin/vice-vscode-entry
RUN printf '. /etc/profile.d/mesa-prompt.sh\n' > /etc/profile.d/zz-mesa.sh && mkdir -p /home/coder/data-store /home/coder/work && chown -R 1000:1000 /home/coder && chmod 750 /home/coder
ENV PATH=/opt/vice/bin:$PATH SHELL=/bin/bash TZ=UTC VICE_APP=vscode
EXPOSE 8080
WORKDIR /home/coder/data-store
USER 1000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD curl -fsS http://127.0.0.1:8080/healthz >/dev/null || exit 1
ENTRYPOINT ["/opt/vice/bin/tini", "--", "/opt/vice/bin/vice-vscode-entry"]
