# ADR-0011: Adopt Iron Bank's hardening and reproducible-build methodology, not its registry

Status: accepted (user decision 2026-09-06). Sources: `docs/research/kasm-cursor-ironbank-notes.md`; docs-ironbank.dso.mil (Dockerfile requirements, FAQ, reproducible builds, fetched 2026-09-06).

## Context
Platform One's Iron Bank (registry1.dso.mil) publishes DoD-hardened images but forbids anonymous pulls (a free Repo1 account is required), accepts only Red Hat UBI bases for images built in its pipeline, and requires Nexus-mirrored, checksummed resources with no network access during builds. It hosts hardened OpenBao, vLLM, Ollama, GPU Operator, External Secrets, Falco, Envoy and JupyterLab images. Its "Reproducible Builds" guidance: the same Dockerfile and inputs must yield the same digest; `SOURCE_DATE_EPOCH` is set to the commit timestamp and used for `org.opencontainers.image.created`; avoid volatile bases; pin pip with `--require-hashes`; clear apt/npm/pip caches, logs and temp files in the same layer; normalise `/etc/shadow` "days since password change"; new attestations only when findings or Syft change; `diffoci` for debugging; `org.opencontainers.image.source`/`revision` labels for traceability.

## Decision
Adopt the methodology in this repo's own pipeline (bases stay Ubuntu/Jupyter/rocker/Kasm, published to harbor.cyverse.org):
- `resources.yaml` declares every downloaded artifact (url, filename, version, sha256 per architecture); Dockerfiles never call the network except through declared resources (a `fetch-resources` Bake stage verifies checksums); no `ADD`; no `curl | bash`.
- Numeric non-root `USER` ≥ 1000; no `su`/`gosu` privilege switching at runtime; no `chmod 777`; SUID/SGID bits removed; no secrets or private keys in layers; GPG keys vendored under `gpg/`.
- Labels (`org.opencontainers.image.*`, `org.cyverse.vice.profile.*`) are set by Bake from git metadata, not hard-coded in Dockerfiles; `SOURCE_DATE_EPOCH` = commit timestamp; `rewrite-timestamp=true` on `--output`; apt/pip/npm caches cleared in-layer; pip installs use `--require-hashes` lock files; `/etc/shadow` volatile fields normalised.
- SBOM (Syft via BuildKit `type=sbom`) and SLSA provenance attestations on every image; cosign keyless signatures; `diffoci` in CI to confirm digest stability across two builds of the same commit.
- Registry1 images are not consumed; CyVerse may revisit if ops accept Registry1 pull secrets. Contributing images back would require UBI bases and is out of scope.

## Consequences
Builds are hermetic and reproducible per commit and architecture; Renovate drives all version bumps through `resources.yaml` and base digests.
