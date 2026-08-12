# 🌌 NebulaIAC

NebulaIAC is a personal infrastructure-as-code lab for building and operating a small private cloud and Kubernetes platform on top of OpenNebula.

It combines OpenTofu/Terraform, Ansible, Kubernetes, MetalLB, Istio, local DNS, and Rook-Ceph into a reproducible homelab platform. The project is not a turnkey product. It is a working reference implementation for learning, experimentation, and demonstrating practical infrastructure engineering patterns.

## What this project demonstrates

NebulaIAC focuses on the kind of infrastructure work that sits between classic systems administration, platform engineering, DevOps, and private-cloud operations:

- OpenNebula-backed VM provisioning
- Dynamic Ansible inventory generation from infrastructure stacks
- Kubernetes cluster bootstrap on Rocky Linux nodes
- Container runtime and node preparation with Ansible
- CNI installation and cluster networking
- MetalLB-based `LoadBalancer` support on a homelab LAN
- Istio ingress for HTTP service exposure
- Local wildcard DNS for lab service names
- Rook-Ceph persistent storage using raw worker disks
- Reusable Ansible roles organized around platform capabilities

The current implementation is opinionated for a homelab/private-cloud environment, but the patterns are intentionally portable.

## Current platform stack

```text
OpenNebula
  └── Rocky Linux VMs
      └── Kubernetes
          ├── Flannel CNI
          ├── MetalLB
          ├── Istio ingress
          ├── Rook-Ceph
          │   ├── ceph-rbd StorageClass
          │   └── cephfs StorageClass
          └── Application/service workloads
```

## Repository layout

```text
NebulaIAC/
├── ansible/
│   ├── inventory/
│   ├── playbooks/
│   │   ├── kube.yml
│   │   └── dns.yml
│   ├── roles/
│   │   ├── dnsmasq_lan_dns/
│   │   ├── kube_cni/
│   │   ├── kube_common/
│   │   ├── kube_control_plane/
│   │   ├── kube_istio/
│   │   ├── kube_metallb/
│   │   ├── kube_rook_ceph/
│   │   ├── kube_rook_ceph_worker_prep/
│   │   ├── kube_smoke_nginx/
│   │   └── kube_worker/
│   └── ansible.cfg
├── infrastructure/
│   └── <stack>/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       ├── outputs.tf
│       └── inventory-hosts.yaml
├── packer/
├── scripts/
│   └── generate_inventory.py
├── README.md
└── LICENSE
```

## Infrastructure workflow

Each infrastructure stack lives under `infrastructure/<stack>/`.

A stack provisions its own resources and writes an `inventory-hosts.yaml` file containing host metadata. The inventory generator merges these stack-level files into the central Ansible inventory.

Typical workflow:

```bash
cd infrastructure/<stack>
tofu init
tofu plan
tofu apply
```

Then regenerate inventory if needed:

```bash
python3 scripts/generate_inventory.py
```

Or use the project helper script when appropriate:

```bash
./scripts/manage.py <stack-name> apply
```

## Kubernetes workflow

The Kubernetes playbook builds the cluster and then layers platform services on top.

```bash
ansible-playbook ansible/playbooks/kube.yml
```

The intended role order is:

```text
kube_common
  ↓
kube_control_plane
  ↓
kube_cni
  ↓
kube_worker
  ↓
kube_rook_ceph_worker_prep
  ↓
kube_metallb
  ↓
kube_istio
  ↓
kube_rook_ceph
  ↓
kube_smoke_nginx
```

### Why storage runs after worker join

Rook-Ceph consumes raw block devices from Kubernetes worker nodes. Every worker that appears in the Ansible `kube_workers` group must also exist as a Kubernetes node before the Ceph cluster is created.

The `kube_rook_ceph_worker_prep` role verifies the OSD disk layout first. The `kube_rook_ceph` role then creates the Rook-Ceph resources from the controller.

## Persistent storage

Rook-Ceph provides Kubernetes-native persistent storage.

The current lab profile uses one raw data disk per Kubernetes worker:

```text
vda = operating system disk
vdb = raw Rook/Ceph OSD disk
```

The Rook-Ceph role creates:

```text
ceph-rbd (default)   rook-ceph.rbd.csi.ceph.com
cephfs               rook-ceph.cephfs.csi.ceph.com
```

Use `ceph-rbd` for normal single-writer application storage, including most database workloads.

Use `cephfs` for shared filesystem workloads that need `ReadWriteMany`.

Example validation:

```bash
kubectl get storageclass
kubectl get pvc
kubectl -n rook-ceph get pods -o wide
kubectl -n rook-ceph get cephcluster rook-ceph -o wide
```

Expected StorageClass shape:

```text
NAME                 PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION
ceph-rbd (default)   rook-ceph.rbd.csi.ceph.com      Delete          WaitForFirstConsumer   true
cephfs               rook-ceph.cephfs.csi.ceph.com   Delete          Immediate              true
```

## Networking and ingress

The cluster uses:

- Flannel for pod networking
- MetalLB for LAN `LoadBalancer` IPs
- Istio for ingress routing
- dnsmasq for local lab DNS

A simple smoke workload validates the service path:

```text
browser/client
  ↓
local DNS
  ↓
Istio ingress gateway
  ↓
Kubernetes service
  ↓
nginx smoke pods
```

The repository avoids documenting real private network values in public examples. Use documentation-safe example ranges when writing public docs.

## Current Ansible roles

### `kube_common`

Prepares Rocky Linux nodes for Kubernetes.

Responsibilities include:

- common package installation
- kernel module configuration
- sysctl configuration
- swap disablement
- containerd installation/configuration
- Kubernetes package repository setup
- kubelet configuration
- SELinux posture management

### `kube_control_plane`

Initializes the Kubernetes control plane and prepares kubeconfig access.

### `kube_cni`

Installs and configures the Kubernetes CNI.

### `kube_worker`

Joins worker nodes to the Kubernetes cluster.

### `kube_metallb`

Installs MetalLB and configures the lab address pool.

### `kube_istio`

Installs Istio and waits for the ingress gateway.

### `kube_rook_ceph_worker_prep`

Preflights worker disks before Rook-Ceph consumes them.

This role verifies that the configured OSD device exists, is a block device, is large enough, and has no filesystem signatures.

### `kube_rook_ceph`

Installs Rook-Ceph, creates the Ceph cluster, configures RBD/CephFS storage classes, and runs PVC smoke tests.

Important implementation note: Rook v1.19 requires the CSI operator resources during install. The working install order is:

```text
crds.yaml
common.yaml
csi-operator.yaml
operator.yaml
CephCluster
```

### `kube_smoke_nginx`

Deploys a simple nginx workload to validate ingress and service routing.

### `dnsmasq_lan_dns`

Configures local DNS for lab service names.

## Security posture

NebulaIAC is a lab and reference implementation, not a hardened production platform.

The project is designed with security-conscious architecture in mind, but the current implementation should not be treated as secure by default.

Planned or future hardening areas include:

- hardened base images
- tighter host firewall policy
- certificate automation
- secrets management
- stronger identity integration
- policy-as-code
- image scanning
- audit logging
- backup and disaster recovery
- tighter supply-chain controls

Do not publish secrets, real credentials, sensitive inventory, private keys, or environment-specific values.

## Public repository hygiene

This repository is public-facing. Keep examples sanitized.

Avoid committing:

- real credentials
- private keys
- tokens
- real internal IP plans where unnecessary
- generated state files
- local inventory containing sensitive host details
- logs containing secrets or environment-specific identifiers

Prefer committing:

- reusable role code
- sanitized examples
- documentation-safe IP ranges
- templates
- defaults that are safe for public review

## Limitations

- This is an evolving homelab, not a commercial product.
- The automation assumes operator familiarity with Linux, OpenNebula, OpenTofu/Terraform, Ansible, Kubernetes, and Ceph.
- Some roles are intentionally opinionated for this lab.
- Destructive storage operations should be reviewed carefully before use.
- Rook-Ceph cleanup and OSD wiping should be deliberate and targeted only at intended devices.
- This project is not affiliated with OpenNebula, Kubernetes, Istio, MetalLB, Rook, or Ceph.

## Roadmap ideas

Near-term areas of interest:

- move more service configuration into reusable roles
- add OpenProject or similar application workloads using Ceph-backed PVCs
- add better Ceph toolbox/dashboard handling
- explicitly disable or document telemetry posture
- add backup/restore workflows for persistent workloads
- add certificate automation for ingress
- improve public-safe examples and sample variables
- add validation playbooks for cluster health

Longer-term areas of interest:

- hardened image builds
- GitOps-style deployment patterns
- secrets management
- observability stack
- policy-as-code
- better CI validation for role syntax and formatting

## License

GPL-3.0. See `LICENSE`.

## Status

NebulaIAC is a personal learning and demonstration platform. It is useful, reproducible, and actively evolving, but should be treated as a reference architecture and lab system rather than a supported product.

