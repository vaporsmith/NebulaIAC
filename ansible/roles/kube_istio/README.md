# kube_istio

Installs Istio for the NebulaIAC Kubernetes homelab cluster.

This role installs the Istio control plane and the default Istio ingress gateway using `istioctl`. The ingress gateway is exposed as a Kubernetes `LoadBalancer` service, which is fulfilled by MetalLB in this bare-metal / OpenNebula-backed homelab environment.

This README intentionally uses documentation/example IP addresses and hostnames. Do not commit real home network ranges, router details, DHCP scopes, VM allocation pools, service IPs, public IPs, VPN addresses, or remote-access details to a public repository unless there is a specific reason to do so.

## Current target environment

- Kubernetes deployed with `kubeadm`
- Rocky Linux 9.x nodes
- OpenNebula-backed VMs on a bridged LAN
- Flannel CNI using `host-gw`
- MetalLB running in Layer 2 mode
- Istio installed with `istioctl`
- Istio ingress gateway exposed through a MetalLB-assigned `LoadBalancer` IP

## What this role does

The role performs the following actions from the Kubernetes control plane node:

1. Creates the local Istio installation directory.
2. Downloads a pinned Istio release archive if `istioctl` is not already present.
3. Extracts the Istio release archive.
4. Installs Istio using `istioctl install`.
5. Waits for the `istiod` deployment to become available.
6. Waits for the `istio-ingressgateway` deployment to become available.
7. Displays the Istio ingress gateway service details.

After this role runs successfully, the cluster should have:

- Istio control plane running in `istio-system`
- Istio ingress gateway running in `istio-system`
- Istio ingress gateway service exposed as `LoadBalancer`
- MetalLB-assigned external IP on the ingress gateway service

Example service output:

```text
NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)
istio-ingressgateway   LoadBalancer   10.100.102.231   192.0.2.221    15021:30614/TCP,80:32685/TCP,443:30676/TCP
```

> Note: `192.0.2.0/24` is a documentation-only address range. Replace example values with valid, reserved addresses from your own lab network.

## Requirements

This role assumes the Kubernetes cluster and MetalLB are already functional before Istio is installed.

Required prior cluster state:

- Kubernetes control plane initialized.
- Worker nodes joined and `Ready`.
- CNI installed and working.
- Pod-to-pod networking confirmed.
- ClusterIP service networking confirmed.
- MetalLB installed and configured.
- MetalLB `IPAddressPool` and `L2Advertisement` present.
- A test `LoadBalancer` service can receive a MetalLB external IP.
- `kubectl` available on the control plane.
- `/etc/kubernetes/admin.conf` present on the control plane.

This role is intended to run against the `kube_controllers` Ansible group.

## Role Variables

Default variables are defined in:

```text
roles/kube_istio/defaults/main.yml
```

### `istio_version`

Pinned Istio version to install.

```yaml
istio_version: "1.30.0"
```

### `istio_arch`

Architecture suffix used by the Istio release archive.

```yaml
istio_arch: "linux-amd64"
```

### `istio_install_dir`

Base directory where the Istio release is extracted.

```yaml
istio_install_dir: "/opt/istio"
```

### `istio_release_dir`

Version-specific Istio release directory.

```yaml
istio_release_dir: "{{ istio_install_dir }}/istio-{{ istio_version }}"
```

### `istioctl_path`

Path to the `istioctl` binary used by this role.

```yaml
istioctl_path: "{{ istio_release_dir }}/bin/istioctl"
```

### `istio_profile`

Istio install profile.

```yaml
istio_profile: "default"
```

The `default` profile installs the Istio control plane and an ingress gateway, which is the desired starting point for this homelab.

### `istio_kubeconfig`

Kubeconfig used by `istioctl` and `kubectl` commands.

```yaml
istio_kubeconfig: "/etc/kubernetes/admin.conf"
```

This is important because `istioctl` may otherwise fall back to trying `localhost:8080`, which will fail on a kubeadm control plane unless a default kubeconfig is configured for the running user.

### `istio_system_namespace`

Namespace where Istio is installed.

```yaml
istio_system_namespace: "istio-system"
```

### `istio_ingress_service_name`

Name of the Istio ingress gateway service and deployment.

```yaml
istio_ingress_service_name: "istio-ingressgateway"
```

## Dependencies

This role depends on a functioning Kubernetes cluster created by the earlier Kubernetes roles:

- `kube_common`
- `kube_control_plane`
- `kube_cni`
- `kube_worker`
- `kube_metallb`

The recommended playbook order is:

```yaml
- name: Prepare all Kubernetes nodes
  hosts: kube_controllers:kube_workers
  become: true
  roles:
    - kube_common

- name: Initialize Kubernetes control plane
  hosts: kube_controllers
  become: true
  roles:
    - kube_control_plane

- name: Install Kubernetes CNI
  hosts: kube_controllers
  become: true
  roles:
    - kube_cni

- name: Join Kubernetes workers
  hosts: kube_workers
  become: true
  roles:
    - kube_worker

- name: Install MetalLB
  hosts: kube_controllers
  become: true
  roles:
    - kube_metallb

- name: Install Istio
  hosts: kube_controllers
  become: true
  roles:
    - kube_istio
```

## Example Playbook

```yaml
---
- name: Install Istio
  hosts: kube_controllers
  become: true
  roles:
    - kube_istio
```

Example with an overridden Istio version:

```yaml
---
- name: Install Istio
  hosts: kube_controllers
  become: true
  vars:
    istio_version: "1.30.0"
  roles:
    - kube_istio
```

## Validation

After running the role, verify Istio pods:

```bash
ansible kube_controllers -a "kubectl get pods -n istio-system -o wide"
```

Expected result:

- `istiod` pod running.
- `istio-ingressgateway` pod running.

Verify the ingress gateway service:

```bash
ansible kube_controllers -a "kubectl get svc -n istio-system istio-ingressgateway -o wide"
```

Expected result:

```text
NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)
istio-ingressgateway   LoadBalancer   10.100.102.231   192.0.2.221    15021:30614/TCP,80:32685/TCP,443:30676/TCP
```

The exact `CLUSTER-IP`, `EXTERNAL-IP`, and NodePort values will vary by cluster.

## Notes

The Istio ingress gateway receiving an external IP only proves that the gateway is exposed. It does not prove application routing by itself.

Application routing requires additional Istio resources such as:

- `Gateway`
- `VirtualService`

The `kube_smoke_nginx` role is used to validate that traffic can enter through the Istio ingress gateway and route to a workload.

## Troubleshooting

### `istioctl` tries to connect to `localhost:8080`

If `istioctl install` fails with an error similar to:

```text
Get "http://localhost:8080/version?timeout=15s": dial tcp [::1]:8080: connect: connection refused
```

then `istioctl` did not find a kubeconfig.

Ensure the install command includes:

```text
--kubeconfig=/etc/kubernetes/admin.conf
```

or set:

```yaml
istio_kubeconfig: "/etc/kubernetes/admin.conf"
```

### Ingress gateway service is stuck in `Pending`

If the `istio-ingressgateway` service is `LoadBalancer` but has no external IP, verify MetalLB first:

```bash
ansible kube_controllers -a "kubectl get pods -n metallb-system -o wide"
ansible kube_controllers -a "kubectl get ipaddresspool,l2advertisement -n metallb-system"
```

MetalLB must be running and configured before the Istio ingress gateway can receive a LAN-routable IP.

## Security Notes

This role installs Istio but does not enable or configure a complete service mesh security model.

This role does not currently configure:

- Automatic namespace sidecar injection
- Strict mesh-wide mTLS
- Authorization policies
- Request authentication
- TLS certificates for ingress
- External DNS
- Host firewalls

Future hardening should include:

- Reviewing Istio mTLS mode
- Adding ingress TLS
- Restricting exposed hostnames and services
- Adding authorization policies
- Reviewing Envoy access logs and metrics
- Validating host firewall rules
- Avoiding accidental exposure of internal services

For public repositories, avoid committing real network details, including:

- Real home LAN CIDRs
- Real router DHCP ranges
- Real hypervisor or VM allocation pools
- Real static host IP addresses
- Screenshots containing internal network configuration
- Public IPs, VPN/Tailscale addresses, or remote-access details

Use documentation ranges such as `192.0.2.0/24`, `198.51.100.0/24`, or `203.0.113.0/24` in public-facing examples.

## License

Internal homelab project.

## Author Information

NebulaIAC homelab automation role.
