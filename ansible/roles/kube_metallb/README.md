# kube_metallb

Installs and configures MetalLB for the NebulaIAC Kubernetes homelab cluster.

This role enables `LoadBalancer` services in a bare-metal / OpenNebula-backed Kubernetes environment. Since this cluster does not run in a cloud provider with a native load balancer implementation, MetalLB provides LAN-routable service IPs from a reserved address pool.

This README intentionally uses documentation/example IP ranges instead of real homelab addresses. Do not commit real home network ranges, router details, DHCP scopes, VM allocation pools, or service IPs to a public repository unless there is a specific reason to do so.

Current target environment:

- Kubernetes deployed with `kubeadm`
- Rocky Linux 9.x nodes
- OpenNebula-backed VMs on a bridged LAN
- Flannel CNI using `host-gw`
- MetalLB running in Layer 2 mode
- Dedicated non-overlapping address ranges for DHCP, VM allocation, and Kubernetes `LoadBalancer` services

## What this role does

The role performs the following actions from the Kubernetes control plane node:

1. Applies the upstream MetalLB native manifest.
2. Waits for the MetalLB controller deployment to become available.
3. Waits for the MetalLB speaker DaemonSet to roll out across the cluster.
4. Renders a MetalLB `IPAddressPool` and `L2Advertisement`.
5. Applies the MetalLB address pool configuration.

After this role runs successfully, Kubernetes services of type `LoadBalancer` can receive an external IP from the configured MetalLB pool.

Example result:

```text
NAME          TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)
smoke-nginx   LoadBalancer   10.105.72.163   192.0.2.220    80:30080/TCP
```

A client on the LAN can then access the service directly:

```bash
curl http://192.0.2.220
```

> Note: `192.0.2.0/24` is a documentation-only address range. Replace example values with valid, reserved addresses from your own lab network.

## Requirements

This role assumes the Kubernetes cluster is already functional before MetalLB is installed.

Required prior cluster state:

- Kubernetes control plane initialized.
- Worker nodes joined and `Ready`.
- CNI installed and working.
- Pod-to-pod networking confirmed.
- ClusterIP service networking confirmed.
- `kubectl` available on the control plane.
- `/etc/kubernetes/admin.conf` present on the control plane.

This role is intended to run against the `kube_controllers` Ansible group.

The current NebulaIAC Kubernetes role flow expects inventory groups similar to:

```yaml
kube_controllers:
  hosts:
    kube-controller:

kube_workers:
  hosts:
    kube-worker-1:
    kube-worker-2:
    kube-worker-3:
    kube-worker-4:
```

## Network assumptions

MetalLB needs a pool of IP addresses that are free on the LAN.

For a homelab, reserve non-overlapping address ranges for:

- Router DHCP clients
- Hypervisor or cloud management VM allocation
- Static infrastructure
- MetalLB `LoadBalancer` services

Example only:

```text
192.0.2.50-192.0.2.98      VM allocation pool
192.0.2.100-192.0.2.199    Router DHCP pool
192.0.2.220-192.0.2.229    MetalLB LoadBalancer pool
```

The MetalLB pool must not overlap with:

- Router DHCP range
- OpenNebula or other VM allocation pools
- Static infrastructure addresses
- Existing physical or virtual hosts

Using overlapping ranges can cause ARP conflicts and unpredictable traffic routing.

## Address planning guidance

MetalLB does not assign IPs to VMs. In Layer 2 mode, MetalLB advertises a service IP on the LAN using the cluster nodes.

A safe address plan should follow this pattern:

```text
<LAN subnet>.<reserved VM range>       VM allocation pool
<LAN subnet>.<reserved DHCP range>     Router DHCP pool
<LAN subnet>.<reserved LB range>       MetalLB LoadBalancer pool
```

Before setting `metallb_address_pool`, verify that the selected range is outside any router DHCP scope and outside any hypervisor or VM manager allocation pool.

For a small homelab, a pool of five to ten IPs is usually enough. One IP can front an ingress gateway, and that ingress gateway can route many applications by hostname or path.

## Role Variables

Default variables are defined in:

```text
roles/kube_metallb/defaults/main.yml
```

### `metallb_version`

MetalLB version to install.

```yaml
metallb_version: "v0.16.1"
```

### `metallb_namespace`

Namespace where MetalLB is installed.

```yaml
metallb_namespace: "metallb-system"
```

### `metallb_manifest_url`

URL for the upstream MetalLB native manifest.

```yaml
metallb_manifest_url: "https://raw.githubusercontent.com/metallb/metallb/{{ metallb_version }}/config/manifests/metallb-native.yaml"
```

### `metallb_address_pool_name`

Name of the MetalLB `IPAddressPool` and base name for the related `L2Advertisement`.

```yaml
metallb_address_pool_name: "homelab-lan-pool"
```

### `metallb_address_pool`

List of LAN address ranges MetalLB may assign to `LoadBalancer` services.

Example only:

```yaml
metallb_address_pool:
  - "192.0.2.220-192.0.2.229"
```

Replace this example with a reserved range from your own lab network.

## Templates

This role uses the following template:

```text
roles/kube_metallb/templates/metallb-pool.yaml.j2
```

The template renders:

- `IPAddressPool`
- `L2Advertisement`

These resources tell MetalLB which IP addresses it can assign and that those addresses should be advertised on the local Layer 2 network.

## Dependencies

This role depends on a functioning Kubernetes cluster created by the earlier Kubernetes roles:

- `kube_common`
- `kube_control_plane`
- `kube_cni`
- `kube_worker`

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
```

## Example Playbook

```yaml
---
- name: Install MetalLB
  hosts: kube_controllers
  become: true
  roles:
    - kube_metallb
```

Example with an overridden IP range:

```yaml
---
- name: Install MetalLB
  hosts: kube_controllers
  become: true
  vars:
    metallb_address_pool:
      - "192.0.2.220-192.0.2.224"
  roles:
    - kube_metallb
```

## Validation

After running the role, verify MetalLB pods:

```bash
ansible kube_controllers -a "kubectl get pods -n metallb-system -o wide"
```

Expected result:

- One MetalLB controller pod running.
- One MetalLB speaker pod running on each Kubernetes node.

Verify the address pool and Layer 2 advertisement:

```bash
ansible kube_controllers -a "kubectl get ipaddresspool,l2advertisement -n metallb-system"
```

Expected result:

```text
ipaddresspool.metallb.io/homelab-lan-pool
l2advertisement.metallb.io/homelab-lan-pool-l2
```

Test with a `LoadBalancer` service:

```bash
ansible kube_controllers -a "kubectl patch svc smoke-nginx -p '{\"spec\":{\"type\":\"LoadBalancer\"}}'"
ansible kube_controllers -a "kubectl get svc smoke-nginx -o wide"
```

Expected result:

```text
EXTERNAL-IP: <address from the MetalLB pool>
```

Then test from a LAN client:

```bash
curl http://<metal-lb-service-ip>
```

## Notes

A Kubernetes `LoadBalancer` service may still show a NodePort internally, for example:

```text
80:30080/TCP
```

That is normal. The important difference is that clients can use the MetalLB-assigned external IP instead of directly targeting node IPs and high NodePort values.

## Security Notes

MetalLB is currently configured in Layer 2 mode for homelab use.

This role does not configure host firewalls. Firewalld hardening for Kubernetes nodes is intentionally deferred to a future node security role.

Future hardening should include:

- Installing and enabling `firewalld`
- Explicitly allowing required Kubernetes, Flannel, MetalLB, and ingress ports
- Documenting allowed LAN exposure
- Reviewing SELinux state and AVC logs
- Restricting exposed services to intentional `LoadBalancer` or ingress endpoints

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
