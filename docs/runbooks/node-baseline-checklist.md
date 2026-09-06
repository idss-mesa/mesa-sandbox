# Node and cluster baseline discovery (hand-off to CyVerse ops and the Jetstream2 pilot)

Fill in per cluster; every profile above P0 depends on these answers.

| # | Question | Why | Answer (cluster / date) |
|---|---|---|---|
| 1 | Kubernetes version (control plane, kubelets) | user namespaces GA 1.36; DRA GA 1.34; ImageVolume stable 1.36; native sidecars 1.33 | |
| 2 | Container runtime and version (containerd ≥ 2.0? CRI-O?), runc/crun version | `hostUsers: false` needs containerd 2.x + runc 1.2/crun; containerd 1.6 ignores it silently | |
| 3 | Node OS and kernel (≥ 6.3 for idmap tmpfs; ≥ 6.2 Landlock v3 for Cursor; 6.7 for landjail) | userns, Landlock | |
| 4 | `kernel.apparmor_restrict_unprivileged_userns` value (Ubuntu 24.04 default 1) | bubblewrap/Landlock sandboxes | |
| 5 | Can nodes load `Localhost` seccomp and AppArmor profiles (path under `/var/lib/kubelet/seccomp`, `apparmor_parser`)? | VICE profiles | |
| 6 | Pod Security Admission labels on `vice-apps` today; LimitRange/ResourceQuota | enforcement plan | |
| 7 | `vice.use_csi_driver` in production app-exposer; CSI driver version and auth mode (`clientUser` proxy vs password) | Data Store access for agents | |
| 8 | Does `/dev/fuse` exist in analysis pods? Are s3fs mounts actually working today? | OSN strategy | |
| 9 | CNI (Cilium? Calico? kube-router?) and whether FQDN egress policies are available | N1–N3 implementation | |
| 10 | Ingress path: Traefik Gateway API HTTPRoutes; can a second (agent) analysis be exposed or hidden? | agent pods | |
| 11 | GPU inventory: node labels (`gpu=true`, `nvidia.com/gpu.product`), driver versions, device plugin/GPU Operator version, time-slicing/MIG config | ADR-0006; nvproxy support | |
| 12 | Are worker nodes bare metal or VMs with nested virt? Is `/dev/kvm` present? | gVisor KVM platform, Kata | |
| 13 | Storage classes for RWX (NFS/Ceph) and idmap support | shared workspace, `hostUsers` | |
| 14 | Kyverno or another admission controller present? Image signature verification available? | ADR-0008/0011 | |
| 15 | OpenBao/Vault already deployed? Keycloak clients that can be registered for VICE (confidential broker, public PKCE)? | ADR-0003 | |
| 16 | AI Verde: LiteLLM version, is `/key/generate` exposable to app-exposer, Anthropic `/v1/messages` served? | ADR-0006 | |
| 17 | Harbor: OCI artifact support (ORAS/ModelKits) for model weights; robot accounts for CI on the AMD VM and DGX Sparks | ADR-0006/0013 | |
| 18 | Logging/audit sinks (Loki/ELK), Falco present? | audit, kill switch | |
