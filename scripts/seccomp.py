#!/usr/bin/env python3
"""seccomp.py — generate k8s/seccomp/vice-sandbox.json from Docker's default profile.

The VICE profile equals the moby/containerd default (defaultAction ERRNO plus
the standard allowlist) with ONE change: the namespace and mount syscalls that
unprivileged user-namespace sandboxes need (bubblewrap for Claude Code and
Codex, Landlock/userns for Cursor, Anthropic sandbox-runtime) are allowed
without CAP_SYS_ADMIN. Everything else stays as in the default, so the profile
is still Restricted-PSS compatible (seccompProfile.type: Localhost). See ADR-0002
(R1) and docs/research/runtime-isolation.md.

Usage: scripts/seccomp.py <moby-default.json> > k8s/seccomp/vice-sandbox.json
"""
import hashlib, json, sys
USERNS_SYSCALLS = ["unshare", "clone", "clone3", "setns", "mount", "umount2", "pivot_root",
                   "mount_setattr", "open_tree", "move_mount", "fsopen", "fsconfig", "fsmount", "fspick"]
src = sys.argv[1]; raw = open(src, "rb").read(); d = json.loads(raw)
kept = []
for g in d["syscalls"]:
    names = [n for n in g["names"] if n not in USERNS_SYSCALLS]
    # drop rules that only exist to gate these syscalls on CAP_SYS_ADMIN (or to ERRNO clone3)
    if not names: continue
    g = dict(g); g["names"] = names; kept.append(g)
kept.append({"names": USERNS_SYSCALLS, "action": "SCMP_ACT_ALLOW",
             "comment": "mesa-sandbox: unprivileged user namespaces + mounts inside them (bubblewrap, Landlock sandboxes); host is protected by the pod's own userns/capability bounding set"})
out = dict(d); out["syscalls"] = kept
out["_generated"] = {"by": "scripts/seccomp.py", "from": "moby/profiles seccomp/default.json", "source_sha256": hashlib.sha256(raw).hexdigest()}
json.dump(out, sys.stdout, indent=1); print()
