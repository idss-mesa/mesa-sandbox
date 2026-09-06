# syntax=docker/dockerfile:1.7
# mesa-kasm — Kasm AI Dev Studio (Ubuntu 22.04, XFCE, KasmVNC, Cursor IDE,
# Claude Code/Gemini/Codex) + the MESA agent toolchain (ADR-0009). Kasm's own
# entrypoint stays; VICE boot runs from /dockerstartup/custom_startup.sh.
# The image ships no sudo; kasm-user is UID 1000 GID 0.
FROM base AS app
ARG DEBIAN_FRONTEND=noninteractive
USER root
ENV HOME=/home/kasm-default-profile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && icu="$(apt-cache search --names-only '^libicu[0-9]+$' | awk '{print $1}' | sort -V | tail -1)" && \
      apt-get install -y --no-install-recommends \
      tmux git openssh-client gettext-base jq unzip xz-utils bzip2 less bubblewrap socat "$icu" libssl3 && \
    rm -rf /var/lib/apt/lists/*
COPY --from=tools /opt/vice /opt/vice
COPY images/common /opt/vice/common
RUN /opt/vice/common/install-common.sh && rm -rf /opt/vice/common && \
    # prefer the pinned, checksum-verified copies over Kasm's curl|bash installs
    for b in claude codex gemini cursor-agent; do rm -f /usr/local/bin/$b; done && \
    printf '. /etc/profile.d/mesa-prompt.sh\n' > /etc/profile.d/zz-mesa.sh
COPY --chmod=755 images/kasm/custom_startup.sh /dockerstartup/custom_startup.sh
RUN chown 1000:0 /dockerstartup/custom_startup.sh && mkdir -p /home/kasm-user/data-store /home/kasm-user/work && chown -R 1000:0 /home/kasm-user
ENV PATH=/opt/vice/bin:$PATH VICE_APP=kasm HOME=/home/kasm-user
WORKDIR /home/kasm-user/data-store
USER 1000
