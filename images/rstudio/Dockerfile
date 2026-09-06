# syntax=docker/dockerfile:1.7
# mesa-rstudio — ghcr.io/rocker-org/geospatial (R + RStudio Server + spatial
# stack) launched WITHOUT rocker's root /init: rserver runs as UID 1000 with
# --server-user (the Open OnDemand pattern, ADR-0015). No nginx, no sudo.
FROM base AS app
ARG DEBIAN_FRONTEND=noninteractive
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      tmux git openssh-client gettext-base jq unzip xz-utils bzip2 less bubblewrap socat libicu74 libssl3 && \
    rm -rf /var/lib/apt/lists/*
COPY --from=tools /opt/vice /opt/vice
COPY images/common /opt/vice/common
RUN /opt/vice/common/install-common.sh && rm -rf /opt/vice/common
COPY --chmod=755 images/rstudio/entry.sh /opt/vice/bin/vice-rstudio-entry
RUN printf '. /etc/profile.d/mesa-prompt.sh\n' > /etc/profile.d/zz-mesa.sh && \
    mkdir -p /home/rstudio/data-store /home/rstudio/work && chown -R 1000:1000 /home/rstudio && chmod 750 /home/rstudio && \
    # user-writable RStudio Server state; rocker's /init is not used
    mkdir -p /var/lib/rstudio-server /var/run/rstudio-server && chown -R 1000:1000 /var/lib/rstudio-server /var/run/rstudio-server
ENV PATH=/opt/vice/bin:/usr/lib/rstudio-server/bin:$PATH SHELL=/bin/bash TZ=UTC VICE_APP=rstudio
EXPOSE 8787
WORKDIR /home/rstudio/data-store
USER 1000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD curl -fsS http://127.0.0.1:8787/ >/dev/null || exit 1
ENTRYPOINT ["/opt/vice/bin/tini", "--", "/opt/vice/bin/vice-rstudio-entry"]
