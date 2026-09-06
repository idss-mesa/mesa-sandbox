# mesa-sandbox — build entry points (ADR-0008, ADR-0013). Requires docker buildx.
PY        ?= .venv/bin/python
REGISTRY  ?= harbor.cyverse.org/vice
TAG       ?= dev
GIT_SHA   := $(shell git rev-parse --short=12 HEAD 2>/dev/null || echo unknown)
EPOCH     := $(shell git log -1 --format=%ct 2>/dev/null || echo 0)
LOCAL_PLATFORM := $(shell docker version --format '{{.Server.Os}}/{{.Server.Arch}}' 2>/dev/null || echo linux/arm64)
BAKE      = docker buildx bake -f resources.hcl -f docker-bake.hcl
BAKEVARS  = REGISTRY=$(REGISTRY) TAG=$(TAG) GIT_SHA=$(GIT_SHA) SOURCE_DATE_EPOCH=$(EPOCH)

.PHONY: venv lock export check hcl python-lock build test build-all push push-arch builder ci

venv:            ## local venv with PyYAML for scripts/resources.py
	python3 -m venv .venv && .venv/bin/pip install -q pyyaml
lock:            ## compute sha256 for every artifact in resources.yaml (network)
	$(PY) scripts/resources.py lock
export:          ## write resources.lock and resources.hcl from resources.yaml
	$(PY) scripts/resources.py export && $(PY) scripts/resources.py hcl
check:           ## fail if resources.lock/resources.hcl are stale or unlocked
	$(PY) scripts/resources.py check
python-lock:     ## regenerate images/tools/python/requirements.txt with hashes
	docker run --rm -v "$(PWD)/images/tools/python:/w" -w /w $(shell $(PY) scripts/resources.py images | awk -F'\t' '$$1=="uv"{print $$2}') \
	  uv pip compile --generate-hashes --universal --python-version 3.13 requirements.in -o requirements.txt
build:           ## build target(s) for the local platform, load into docker (T=tools)
	$(BAKEVARS) PLATFORMS=$(LOCAL_PLATFORM) $(BAKE) --set '*.cache-from=' --set '*.cache-to=' --load $(or $(T),tools)
test:            ## run the build-time smoke test stage for the local platform
	$(BAKEVARS) PLATFORMS=$(LOCAL_PLATFORM) $(BAKE) --set '*.cache-from=' --set '*.cache-to=' tools-test
build-all:       ## multi-arch build of every image (needs a multi-node builder, see `builder`)
	$(BAKEVARS) PLATFORMS=linux/amd64,linux/arm64 ATTEST=true $(BAKE) all
push:            ## multi-arch build and push (manifest lists) of every image
	$(BAKEVARS) PLATFORMS=linux/amd64,linux/arm64 ATTEST=true $(BAKE) --push all
push-arch:       ## push single-arch images for the LOCAL platform as <TAG>-<arch> (T=targets; never touches :latest)
	$(BAKEVARS) TAG=$(TAG)-$(lastword $(subst /, ,$(LOCAL_PLATFORM))) PLATFORMS=$(LOCAL_PLATFORM) $(BAKE) --set '*.cache-from=' --set '*.cache-to=' --push $(or $(T),all)
builder:         ## create the multi-node builder: local node + AMD_VM (ssh://user@host) [+ SPARK]
	@[ -n "$(AMD_VM)" ] || { echo "usage: make builder AMD_VM=ssh://user@amd-vm [SPARK=ssh://user@sparky-1]"; exit 1; }
	docker buildx create --name mesa --driver docker-container --platform linux/arm64 --use || true
	docker buildx create --name mesa --append --driver docker-container --platform linux/amd64 $(AMD_VM)
	@[ -z "$(SPARK)" ] || docker buildx create --name mesa --append --driver docker-container --platform linux/arm64 $(SPARK)
	docker buildx inspect mesa --bootstrap
ci: check test   ## what CI runs before pushing
