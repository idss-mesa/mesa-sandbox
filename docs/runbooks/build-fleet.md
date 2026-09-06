# Build fleet runbook (ADR-0013)

Goal: every image published as a multi-arch manifest list (linux/amd64 + linux/arm64) on `harbor.cyverse.org/vice/mesa-*`, built natively, never emulated.

## Nodes

| Node | Platform | Role | Docker |
|---|---|---|---|
| MacBook Air (Apple Silicon) | linux/arm64 | day-to-day development, local `make build`/`tests/smoke.sh` | Colima (`colima start --cpu 4 --memory 16 --disk 120`) |
| AMD cloud VM | linux/amd64 | amd64 half of every manifest list; can also host CI runners | Docker Engine 27+ with buildx; SSH reachable |
| CARC DGX Spark (`sparky-1`/`sparky-2`) | linux/arm64 | arm64 builds when the laptop is busy; GPU images later | Docker Engine with NVIDIA toolkit; SSH reachable |
| GitHub Actions (`ubuntu-latest`, `ubuntu-24.04-arm`) | both | `.github/workflows/bake.yml` on push/weekly | hosted |

Disk: the `tools` layer is ~2.5 GB and each overlay 3–7 GB; keep ≥ 40 GB free per node (`docker system df`, `docker builder prune`).

## One multi-node builder from the laptop

```bash
# docker contexts for the remote daemons (SSH keys, no passwords)
docker context create amd-vm --docker "host=ssh://ubuntu@AMD_VM_HOST"
docker context create spark  --docker "host=ssh://tswetnam@sparky-1.hpc.unm.edu"
# one builder with a native node per platform
make builder AMD_VM=ssh://ubuntu@AMD_VM_HOST SPARK=ssh://tswetnam@sparky-1.hpc.unm.edu
docker buildx ls          # mesa: colima (arm64) + amd-vm (amd64) [+ spark (arm64)]
# multi-arch build + push of the whole family with attestations
docker login harbor.cyverse.org        # robot account, see below
make push TAG=$(date +%F)
docker buildx imagetools inspect harbor.cyverse.org/vice/mesa-cli:$(date +%F)
```

`make push` runs `docker buildx bake --push` with `PLATFORMS=linux/amd64,linux/arm64 ATTEST=true`; buildx sends each platform to its native node and assembles the manifest list. Registry cache (`mesa-cache:<target>`) is shared by all nodes.

## CI

1. Harbor: create a robot account with push on project `vice` (Harbor UI → Projects → vice → Robot Accounts); note `robot$vice+ci` and its secret.
2. GitHub → `idss-mesa/mesa-sandbox` → Settings → Secrets: `HARBOR_USERNAME` = `robot$vice+ci`, `HARBOR_PASSWORD` = the secret.
3. Optional self-hosted runners on the AMD VM and a Spark: register with labels `self-hosted, linux, x64` / `arm64` and change the `runner:` values in `bake.yml`; hosted runners work without this.
4. First run: Actions → bake → Run workflow (targets `tools cli agent-runner`); the `merge` job tags `latest`, `<sha>`, `<date>` and signs with cosign (keyless, GitHub OIDC). Kyverno's `vice-verify-images` policy trusts that identity.

## Registering in the DE

Use `vice-app-integrator` (separate repo): `validate_dockerfile` on each `images/*/Dockerfile`, `create_tool` with the Harbor image (multi-arch tag), `create_app` per app, then `vice_test_app`/`launch_app`.

## Single-architecture pushes from one node

Until a second node exists, `make push-arch TAG=<date>` pushes the local platform's images as `mesa-<app>:<date>-<arch>` (for example `2026-09-06-arm64`). These are complete, usable images for that architecture; `:latest` and the date tag without suffix stay reserved for manifest lists, which `make push` (multi-node) or CI produce later. The docker driver cannot export registry cache or attestations, so `push-arch` disables both.

## Local-only cycle

```bash
make check                       # lock/hcl in sync
make test                        # tools image + build-time smoke stage
make build T=cli && tests/smoke.sh harbor.cyverse.org/vice/mesa-cli:dev 7681 / /home/jovyan 1000 100
make build T=vscode && tests/smoke.sh harbor.cyverse.org/vice/mesa-vscode:dev 8080 /healthz /home/coder 1000 1000
make build T=rstudio && tests/smoke.sh harbor.cyverse.org/vice/mesa-rstudio:dev 8787 / /home/rstudio 1000 1000
make build T=jupyterlab && tests/smoke.sh harbor.cyverse.org/vice/mesa-jupyterlab:dev 8888 /api /home/jovyan 1000 100
```

## Updating versions

Renovate opens PRs that bump `resources.yaml`, `images/tools/npm/package.json` and image digests, then re-runs `scripts/resources.py lock --force && export && hcl` in the branch. Manually: edit the `version:` and URLs in `resources.yaml`, run `make lock export`, commit `resources.yaml resources.lock resources.hcl`. Cursor and Antigravity have no release feed: read the version from `https://cursor.com/install` and the Antigravity manifests (see `resources.yaml` comments).
