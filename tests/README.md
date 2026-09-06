# tests

`tests/smoke.sh <image> [port] [health-path]` runs an image read-only, non-root, and checks the plan's verification contract (no sudo, health, every tool answers, no secrets in env, configs installed). `make test` runs the tools image's build-time smoke stage.
