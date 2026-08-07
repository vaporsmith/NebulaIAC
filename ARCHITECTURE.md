# NebulaIAC Architecture

NebulaIAC is a homelab infrastructure-as-code project for provisioning and configuring a Kubernetes-based platform on OpenNebula-managed virtual machines.

This document intentionally uses documentation/example IP addresses and hostnames. Do not commit real home network ranges, router details, DHCP scopes, VM allocation pools, service IPs, public IPs, VPN addresses, or remote-access details to a public repository unless there is a specific reason to do so.

## Current platform milestone

The current platform milestone includes:

- OpenNebula-provisioned Rocky Linux VMs
- Terraform/OpenTofu-managed infrastructure definitions
- Generated Ansible inventory
- kubeadm Kubernetes cluster
- Flannel CNI using `host-gw`
- MetalLB Layer 2 LoadBalancer IPs
- Istio ingress gateway
- Istio `Gateway` and `VirtualService` routing
- dnsmasq LAN DNS for ingress hostnames

## High-level architecture

```text
LAN client / browser
  ↓
LAN DNS
  ↓
Application hostname
  ↓
Istio ingress gateway IP
  ↓
MetalLB LoadBalancer advertisement
  ↓
Kubernetes node
  ↓
istio-ingressgateway
  ↓
Istio Gateway / VirtualService
  ↓
ClusterIP service
  ↓
Application pods
```

## Infrastructure layer

OpenNebula provides the VM substrate for the lab.

Terraform/OpenTofu definitions create and manage the VM instances. An inventory generation workflow then produces an Ansible inventory that maps provisioned VMs into functional groups.

Example inventory shape:

```yaml
all:
  children:
    dns_servers:
      hosts:
        dns_server_01:
          ansible_host: 192.0.2.50

    kube_controllers:
      hosts:
        kube-controller:
          ansible_host: 192.0.2.51

    kube_workers:
      hosts:
        kube-worker-1:
          ansible_host: 192.0.2.54
        kube-worker-2:
          ansible_host: 192.0.2.55
        kube-worker-3:
          ansible_host: 192.0.2.52
        kube-worker-4:
          ansible_host: 192.0.2.53
```

> Note: `192.0.2.0/24` is a documentation-only address range. Replace example values with valid addresses from your own lab network.

## Kubernetes layer

The Kubernetes cluster is deployed with `kubeadm`.

Current cluster pattern:

```text
1 control plane node
4 worker nodes
containerd runtime
Rocky Linux 9.x
SELinux enforcing
```

The primary Kubernetes roles are:

- `kube_common`
- `kube_control_plane`
- `kube_cni`
- `kube_worker`

## CNI layer

Flannel provides pod networking.

The current homelab uses the `host-gw` backend because all Kubernetes nodes are on the same Layer 2 network.

This avoids VXLAN-related complexity and provides direct node-to-node pod routing on the LAN.

## LoadBalancer layer

MetalLB provides `LoadBalancer` service support for the bare-metal / homelab cluster.

MetalLB runs in Layer 2 mode and advertises service IPs from a reserved address pool.

Example address planning:

```text
192.0.2.50-192.0.2.98      VM allocation pool
192.0.2.100-192.0.2.199    Router DHCP pool
192.0.2.220-192.0.2.229    MetalLB LoadBalancer pool
```

The MetalLB pool must not overlap with:

- Router DHCP ranges
- VM allocation ranges
- Static infrastructure addresses
- Existing physical or virtual hosts

## Ingress layer

Istio provides the platform ingress gateway and host-based routing.

The Istio ingress gateway is exposed as a Kubernetes `LoadBalancer` service. MetalLB assigns a LAN-routable IP to that service.

Applications should generally remain behind internal `ClusterIP` services. External clients should reach them through the Istio ingress gateway.

Desired pattern:

```text
Client
  ↓
DNS hostname
  ↓
Istio ingress gateway LoadBalancer IP
  ↓
Istio Gateway / VirtualService
  ↓
ClusterIP application service
  ↓
Pods
```

## DNS layer

LAN DNS is provided by a small VM running `dnsmasq`.

DNS is intentionally outside the Kubernetes cluster so cluster rebuilds, upgrades, and failures do not break name resolution for LAN clients.

Current DNS behavior:

```text
*.example.test  ->  Istio ingress gateway IP
everything else ->  upstream DNS resolvers
```

Kubernetes still has internal CoreDNS for pod and service discovery. That is separate from LAN DNS.

```text
Kubernetes CoreDNS:
  internal pod/service DNS

dnsmasq LAN DNS:
  LAN client DNS for application hostnames
```

## Smoke test path

The smoke test validates the full ingress path.

```text
Client
  ↓
smoke.example.test
  ↓
LAN DNS
  ↓
Istio ingress gateway IP
  ↓
Gateway / VirtualService
  ↓
smoke-nginx ClusterIP service
  ↓
nginx pods
```

Validation:

```bash
curl http://smoke.example.test
```

Expected response:

```text
Welcome to nginx!
```

## Current Ansible playbooks

Current playbook structure:

```text
playbooks/kube.yml
playbooks/dns.yml
```

The Kubernetes playbook configures the cluster and platform ingress layers.

The DNS playbook configures LAN DNS on the external DNS VM.

## Recommended role order

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

- name: Deploy nginx Istio smoke test
  hosts: kube_controllers
  become: true
  roles:
    - kube_smoke_nginx
```

DNS is configured separately:

```yaml
- name: Configure LAN DNS servers
  hosts: dns_servers
  become: true
  roles:
    - dnsmasq_lan_dns
```

## Security notes

This lab is currently focused on building a working platform foundation.

Known future hardening work includes:

- Installing and configuring host firewalls
- Explicitly allowing Kubernetes, MetalLB, Istio, and DNS ports
- Reviewing SELinux AVC logs
- Adding TLS to ingress
- Reviewing Istio mTLS and authorization policies
- Documenting DNS exposure and upstream resolver choices
- Avoiding direct `LoadBalancer` exposure for application services
- Adding monitoring and logging
- Adding backup and restore processes

## Next planned platform layer

The next major platform capability should be persistent storage.

This is required before moving stateful applications, such as project management tools or databases, into Kubernetes.

Initial storage candidates:

- `local-path-provisioner` for a simple first pass
- Longhorn for a richer homelab storage platform later

## Public repository hygiene

Avoid committing real internal infrastructure details to public repositories.

Do not commit:

- Real home LAN CIDRs
- Real router DHCP ranges
- Real hypervisor or VM allocation pools
- Real static host IP addresses
- Screenshots containing internal network configuration
- Public IPs
- VPN or Tailscale addresses
- Remote-access details
- Secrets, tokens, passwords, private keys, or kubeconfigs

Use documentation ranges such as:

```text
192.0.2.0/24
198.51.100.0/24
203.0.113.0/24
```

for public-facing examples.

## License

Internal homelab project.

## Author Information

NebulaIAC homelab automation project.
