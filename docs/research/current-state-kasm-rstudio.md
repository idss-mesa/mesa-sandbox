# Current state: cyverse-vice/kasm-ubuntu and cyverse-vice/rstudio-geospatial

Audit date: 2026-09-06 (read-only).

## Base, user, sudo

| | kasm 24.04 | kasm 24.04-gpu | rstudio latest | rstudio 4.5.0 |
|---|---|---|---|---|
| Base | `kasmweb/ubuntu-noble-desktop:1.17.0-rolling-daily` | `kasmweb/ubuntu-noble-nvidia-pytorch:1.18.0-rolling-daily` | `ghcr.io/rocker-org/geospatial:latest` | same |
| Final `USER` | `kasm-user` (:63) | `kasm-user` (:159) | **`root`** (:98) | none → root |
| sudo | `ARG PRIV_CMDS='ALL'` (:34) → `kasm-user ALL=NOPASSWD: ALL` (:38-39) | same (:137-140) | `rstudio ALL=(ALL) NOPASSWD: ALL` (:67); the restricted `PRIV_CMDS` list at :62 is declared but never used | same |

The checked-in `24.04/sudoers` and `24.04-gpu/sudoers` files are dead: `24.04/Dockerfile:59` is `#COPY sudoers /etc/sudoers` and the GPU Dockerfile copies only `kasmvnc_defaults.yaml` and `vnc_startup.sh`. UID/GID are not pinned in either repo; rstudio assumes 1000:1000 (`latest/Dockerfile:82 chown -R 1000:1000 /etc/nginx /var/log/supervisor`).

## Credential handling

- kasm `24.04/vnc_startup.sh:5-11` (GPU identical) and rstudio `latest/run.sh:8-14` copy `.gitconfig` and `.ssh` from `/data-store/iplant/home/$IPLANT_USER` into `~`. In rstudio `run.sh` runs as root, so the copies land in `/root`, invisible to the `rstudio` session.
- Env vars: `IPLANT_USER`; rstudio `ENV PASSWORD "rstudio1"` (`latest/Dockerfile:48`) is inert because rocker's `userconf` is commented out (`:49`) and the custom ENTRYPOINT replaces `/init`; READMEs still advertise `-e PASSWORD=`. KasmVNC `VNC_PW`, `VNC_VIEW_ONLY_PW`, `KASM_API_JWT`/`KASM_API_HOST` (Kasm-cloud plumbing).
- iRODS env: kasm bakes it at **build time** through `envsubst` with `IPLANT_USER` unset (empty user); rstudio writes the literal `$IPLANT_USER` with `>>` on every restart and never creates `~/.irods`.
- `curl | bash`: NodeSource (`24.04:46`, `gpu:81`, `latest:37`), OpenCode (`24.04:71`, `latest:95`), GoCommands with floating `VERSION.txt` into `/usr/local/bin` (`24.04:22-23`, `gpu:129-130`, `latest:72`), gomplate `ADD` pinned to v3.11.5 without digest (`latest:42`).

## Exposure and process model

- No `EXPOSE` and no `HEALTHCHECK` in any of the four Dockerfiles.
- kasm: port 6901; `ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]`; the script is its own PID-1 watchdog (`KASM_PROCS`, loop at `:396-465`). `vncserver ... -disableBasicAuth ... -interface 0.0.0.0 -BlacklistThreshold=0` (`:149/:151`) overrides `security.brute_force_protection.blacklist_threshold: 5` in `kasmvnc_defaults.yaml:64`. `$HOME/.kasmpasswd` is regenerated each boot with fixed salt `$5$kasm$`; a self-signed cert is generated each boot; YAML says `network.protocol: http`, `require_ssl: false`. Sessions never self-terminate (`idle_timeout: never`, all `auto_shutdown` never). GNOME packages installed (`24.04:41-43`) but the session runs XFCE.
- rstudio: nginx on :80 proxies to `rserver` bound to `127.0.0.1:8787` (`rserver.conf: www-address=127.0.0.1`, `auth-none=1`); `nginx.conf.tmpl:23-30` rewrites absolute redirects to `REDIRECT_URL` and upgrades websockets (`proxy_read_timeout 20d`), it does not rewrite a path prefix. `run.sh:16-18`: `gomplate -f /nginx.conf.tmpl -o /etc/nginx/nginx.conf` then `sudo supervisord -c /etc/supervisor/supervisord.conf -n` (root to root; the "drop privileges" comment is wrong). Supervisor programs run as root; `setcap cap_net_bind_service=+ep /usr/bin/supervisord` (`:84`) is moot. `chmod -R 777 /usr/local/lib/R/site-library` (`:46`).

## AI agent CLIs

| Tool | kasm 24.04 | kasm 24.04-gpu | rstudio latest | rstudio 4.5.0 |
|---|---|---|---|---|
| claude, gemini, codex (npm) | :67 | :167 | :91 | — |
| opencode | :71 | absent | :95 | — |
| goose / antigravity | — | — | — | — |

No configuration is baked for any agent (no settings, MCP registrations, sandbox or permission config, keys). `bubblewrap` is installed in `24.04-gpu:73` and unused.

## GPU (kasm 24.04-gpu)

`NVIDIA_VISIBLE_DEVICES=all`, `NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,display`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json`, `VGL_DISPLAY=egl` (`:7-11`). No driver or CUDA packages; GL/EGL userspace and test tools added (`:21-38`); glvnd ICD and `ld.so.conf.d` entries (`:91-101`). **VirtualGL itself is never installed** (`:40-42` installs only its dependencies); `vglrun-wrapper.sh`, `verify-gpu.sh` and `vnc_startup.sh:176` all branch on its presence and silently fall back to software rendering. XFCE launches under `vglrun -d $KASM_EGL_CARD` only if `KASM_EGL_CARD`/`KASM_RENDERD` are set **and owned by the current user** (`-O`), which fails under a Kubernetes device plugin. `verify-gpu.sh` and `vglrun-wrapper.sh` are copied but never invoked. `24.04-gpu` differs from `24.04` in `kasmvnc_defaults.yaml` only by `desktop.gpu.hw3d: true`.

## CI

- `security.yml` (both): hadolint on one Dockerfile (`24.04/Dockerfile`, `latest/Dockerfile`) with `no-fail: true`; trivy `0.28.0` on the published image with `exit-code: '0'`, skipped on PRs; SARIF upload.
- `harbor.yml`: kasm has `tag` and `variant` inputs (default context `24.04`); rstudio hardcodes `latest`. No `platforms:`; amd64-only downloads; single tag per build. rstudio pins actions to patch versions, kasm to major tags; nothing by SHA; all bases are rolling tags.
- `24.04-gpu` is entirely outside CI (never linted, scanned or built); a dispatch with `variant=24.04-gpu` and the default `tag` would overwrite `:latest`.
- `.trivyignore` files are comment-only; Dependabot (`github-actions`) in both.

## What breaks without root or under restricted Pod Security

Hard failures: rstudio's `sudo supervisord` (setuid blocked by `allowPrivilegeEscalation: false`); `runAsNonRoot: true` refuses the rstudio image (`USER root`); nginx `listen 80` needs `CAP_NET_BIND_SERVICE`; `readOnlyRootFilesystem` breaks `gomplate -o /etc/nginx/nginx.conf`, the iRODS env write, `~/.vnc/self.pem`, `~/.kasmpasswd`, `/tmp/.X11-unix`; `runAsUser` ≠ 1000 breaks rstudio's hard-coded ownership.
Degradations: VirtualGL/GPU path (device ownership), FUSE/s3fs, bubblewrap, in-session `sudo apt install`. KasmVNC's own needs are modest (writable `/tmp` and `$HOME`, port 6901 > 1024, Xvnc is userspace), so the kasm images are the closest to restricted-PSS compatibility.
