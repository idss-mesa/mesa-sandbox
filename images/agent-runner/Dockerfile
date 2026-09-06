# syntax=docker/dockerfile:1.7
# mesa-agent-runner — headless image for profile P2–P4 agent pods (ADR-0001).
# No desktop, no ttyd; runs one harness command as the unprivileged `agent`
# user with the workspace mounted at /workspace and NO user credentials.
FROM base AS app
ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && icu="$(apt-cache search --names-only '^libicu[0-9]+$' | awk '{print $1}' | sort -V | tail -1)" && \
      apt-get install -y --no-install-recommends \
      ca-certificates curl git openssh-client gettext-base jq less procps tmux \
      bubblewrap socat "$icu" libssl3 && rm -rf /var/lib/apt/lists/*
COPY --from=tools /opt/vice /opt/vice
COPY images/common /opt/vice/common
RUN /opt/vice/common/install-common.sh && rm -rf /opt/vice/common && \
    mkdir -p /workspace && chown 1001:1001 /workspace
COPY --chmod=755 images/agent-runner/entry.sh /opt/vice/bin/vice-agent-entry
ENV PATH=/opt/vice/bin:$PATH HOME=/home/agent SHELL=/bin/bash LANG=C.UTF-8 TZ=UTC VICE_APP=agent-runner VICE_PROFILE=P2
WORKDIR /workspace
USER 1001
ENTRYPOINT ["/opt/vice/bin/tini", "--", "/opt/vice/bin/vice-agent-entry"]
CMD ["sleep", "infinity"]
