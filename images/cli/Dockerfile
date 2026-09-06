# syntax=docker/dockerfile:1.7
# mesa-cli — browser terminal (ttyd + tmux) with the MESA agent toolchain.
# Base: quay.io/jupyter/minimal-notebook (jovyan 1000:100, conda) pinned by digest
# through the `base` bake context; tools come from the `tools` bake target.
FROM base AS app
ARG DEBIAN_FRONTEND=noninteractive
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && icu="$(apt-cache search --names-only '^libicu[0-9]+$' | awk '{print $1}' | sort -V | tail -1)" && \
      apt-get install -y --no-install-recommends \
      tmux git openssh-client gettext-base locales jq unzip xz-utils bzip2 less \
      bubblewrap socat "$icu" libssl3 && \
    locale-gen en_US.UTF-8 && rm -rf /var/lib/apt/lists/*
COPY --from=tools /opt/vice /opt/vice
COPY images/common /opt/vice/common
RUN /opt/vice/common/install-common.sh && rm -rf /opt/vice/common
COPY --chmod=755 images/cli/entry.sh /opt/vice/bin/vice-cli-entry
RUN printf 'set-option -g status off\nset -g mouse on\n' > /etc/tmux.conf && \
    printf '. /etc/profile.d/mesa-prompt.sh\n[ -n "$TERM" ] && [ -r /etc/motd ] && /etc/motd\n' > /etc/profile.d/zz-mesa.sh && \
    chown -R 1000:100 /home/jovyan && chmod 750 /home/jovyan
ENV PATH=/opt/vice/bin:/opt/conda/bin:$PATH \
    SHELL=/bin/bash TERM=xterm LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TZ=UTC \
    VICE_APP=cli
EXPOSE 7681
WORKDIR /home/jovyan/data-store
USER 1000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD curl -fsS http://127.0.0.1:7681/ >/dev/null || exit 1
ENTRYPOINT ["/opt/vice/bin/tini", "--", "/opt/vice/bin/vice-cli-entry"]
