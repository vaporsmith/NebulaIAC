# Kubernetes Image / Node Security TODO

Deferred during first kubeadm homelab bootstrap.

## Current known gaps

- firewalld is not installed on Rocky Linux kube images.
- Kubernetes node firewall rules are not managed yet.
- Node image hardening has not been reviewed after kube package/runtime installation.
- SELinux should remain enforcing unless a real AVC denial requires investigation.
- Kubernetes control-plane and worker node ports need an explicit firewall policy.
- CNI-specific ports need to be documented and opened intentionally.
- SSH access and sudo policy should be reviewed for kube nodes.
- Container runtime security defaults should be reviewed after cluster bootstrap.

## Later remediation target

Create a dedicated role, likely:

- `kube_node_security`
- or `rocky_kube_hardening`

That role should install and configure firewalld, manage Kubernetes ports by node role, validate SELinux enforcing mode, and document any exceptions.
