# ADR-0013: Native multi-architecture builds merged into manifest lists on harbor.cyverse.org

Status: accepted (user statement 2026-09-06). Sources: `docs/research/image-build-technique.md`; current `cli/.github/workflows/harbor.yml` (native runner per arch, `:latest` = amd64, `:arm64` = arm64).

## Context
Builds run today on a MacBook Air (Apple Silicon, arm64) via Colima. An AMD cloud VM (linux/amd64) will host later builds, the CARC DGX Sparks (aarch64, Grace Blackwell) are available for arm64 builds, and GitHub Actions offers native `ubuntu-latest` (amd64) and `ubuntu-24.04-arm` (arm64) runners. Emulated builds are slow (the conda solve under QEMU takes ~40 min and can OOM). The current tag scheme (`:latest` amd64, `:arm64`) forces users to pick an architecture.

## Decision
- Every image is published as an OCI **manifest list** for `linux/amd64` and `linux/arm64` under one tag; per-arch tags (`<tag>-amd64`, `<tag>-arm64`) are also pushed for debugging. CUDA variants are amd64-only until upstream bases exist for arm64 (recorded per target in `docker-bake.hcl`). Tags: `latest`, `<git sha>`, `<YYYY-MM-DD>`, and semver when released; `harbor.cyverse.org/vice/mesa-<app>[-cuda]`.
- Build topology: one buildx builder with **per-platform native nodes**, or per-arch builds pushed by digest and merged with `docker buildx imagetools create`. Concretely:
  - `make builder` creates `docker buildx create --name mesa --platform linux/arm64 <local>` and `--append --platform linux/amd64 ssh://<amd-vm>` (and optionally `--append --platform linux/arm64 ssh://sparky-1` when the DGX Spark is preferred over the laptop). `docker buildx bake --push` then emits manifest lists directly.
  - CI: a matrix of native runners (`ubuntu-latest`, `ubuntu-24.04-arm`) builds each target with `--output type=image,push-by-digest=true,name-canonical=true` and a merge job runs `docker buildx imagetools create -t <tag> <digests>`; self-hosted runners on the AMD VM and a DGX Spark are supported by the same workflow via runner labels.
- Reproducibility (ADR-0011) applies per architecture; attestations and cosign signatures are attached to the manifest list and to each arch image.
- Local development on Apple Silicon builds only `linux/arm64` by default (`make build` uses the local platform); amd64 is delegated to the remote node or CI.

## Consequences
No QEMU emulation in CI or locally; Harbor holds one tag per image for all users; the existing `:arm64` tag convention is retired once the DE tools point at the manifest list.
