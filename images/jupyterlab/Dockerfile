# syntax=docker/dockerfile:1.7
# mesa-jupyterlab — quay.io/jupyter/datascience-notebook (jovyan 1000:100) +
# the MESA agent toolchain. Token-less behind the VICE auth proxy, no sudo.
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
COPY --chmod=755 images/jupyterlab/entry.sh /opt/vice/bin/vice-jupyterlab-entry
COPY --chown=1000:100 images/jupyterlab/jupyter_server_config.json /etc/jupyter/jupyter_server_config.json
RUN printf '. /etc/profile.d/mesa-prompt.sh\n' > /etc/profile.d/zz-mesa.sh && chown -R 1000:100 /home/jovyan && chmod 750 /home/jovyan
ENV PATH=/opt/vice/bin:/opt/conda/bin:$PATH SHELL=/bin/bash TZ=UTC VICE_APP=jupyterlab
EXPOSE 8888
WORKDIR /home/jovyan/data-store
USER 1000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD curl -fsS http://127.0.0.1:8888/api >/dev/null || exit 1
ENTRYPOINT ["/opt/vice/bin/tini", "--", "/opt/vice/bin/vice-jupyterlab-entry"]
