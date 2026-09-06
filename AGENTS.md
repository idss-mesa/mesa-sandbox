# Working rules for coding agents in this repository

- Read `docs/plan.md`, `docs/profiles.md` and the ADR index before changing anything; a change that contradicts an ADR needs a new ADR that supersedes it.
- Every downloaded artifact goes through `resources.yaml` with a sha256 per architecture. Never add `curl | bash`, `ADD`, floating tags, or `sudo` to an image.
- Images run as a numeric non-root user, contain no sudo binary, write nothing into the image at runtime, and must pass `docker run --read-only -u 1000`.
- Never commit secrets, kubeconfigs, `.env` files, or CyVerse/OSN/GitHub credentials; `live/` directories with real endpoints stay gitignored.
- Multi-arch: build natively (ADR-0013); do not enable QEMU emulation in CI.
- Record measured facts (cluster versions, driver versions, timings) as dated `[measured]` notes in the relevant ADR; unverified claims are marked UNVERIFIED.
- Commit messages: imperative subject, body explains why, `Co-Authored-By` trailer for AI-assisted commits.
