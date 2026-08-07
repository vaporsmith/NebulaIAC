# dnsmasq_lan_dns

Installs and configures `dnsmasq` as a lightweight LAN DNS resolver for the NebulaIAC homelab.

This role provides local name resolution for application hostnames that should route through the Kubernetes Istio ingress gateway. It is intended to run on a small VM outside the Kubernetes cluster so DNS remains available even when the cluster is being rebuilt, upgraded, or debugged.

This README intentionally uses documentation/example IP addresses and hostnames. Do not commit real home network ranges, router details, DHCP scopes, VM allocation pools, service IPs, public IPs, VPN addresses, or remote-access details to a public repository unless there is a specific reason to do so.

## Current target environment

- Small Rocky Linux 9.x DNS VM
- VM provisioned by OpenNebula
- Inventory group: `dns_servers`
- `dnsmasq` installed and managed by Ansible
- Kubernetes ingress provided by Istio
- Istio ingress gateway exposed through MetalLB
- Homelab DNS names resolving to the Istio ingress gateway IP

## What this role does

The role performs the following actions on hosts in the `dns_servers` group:

1. Installs `dnsmasq`.
2. Ensures `/etc/dnsmasq.d` exists.
3. Renders a NebulaIAC LAN DNS configuration file.
4. Validates the `dnsmasq` configuration with `dnsmasq --test`.
5. Enables and starts the `dnsmasq` service.
6. Restarts `dnsmasq` when its managed configuration changes.

The intended behavior is:

```text
*.example.test  ->  Istio ingress gateway IP
everything else ->  upstream DNS resolvers
```

## Requirements

Required prior state:

- DNS VM provisioned and reachable by Ansible.
- DNS VM present in the `dns_servers` inventory group.
- Kubernetes cluster already has a working Istio ingress gateway.
- Istio ingress gateway has a MetalLB-assigned `LoadBalancer` IP.
- Port 53 TCP/UDP is reachable from LAN clients.
- Upstream DNS resolvers are reachable from the DNS VM.

This role currently assumes a Red Hat-family operating system.

## Inventory example

```yaml
all:
  children:
    dns_servers:
      hosts:
        dns_server_01:
          ansible_host: 192.0.2.50
```

> Note: `192.0.2.0/24` is a documentation-only address range. Replace example values with valid addresses from your own lab network.

## Role Variables

Default variables are defined in:

```text
roles/dnsmasq_lan_dns/defaults/main.yml
```

### `dnsmasq_domain`

Local lab domain served by dnsmasq.

```yaml
dnsmasq_domain: "example.test"
```

### `dnsmasq_ingress_ip`

The Istio ingress gateway `LoadBalancer` IP. Wildcard records for the lab domain point to this address.

```yaml
dnsmasq_ingress_ip: "192.0.2.221"
```

This should be the external IP of the `istio-ingressgateway` service, not the IP of an individual application service.

### `dnsmasq_listen_address`

Address where dnsmasq should listen for DNS queries.

```yaml
dnsmasq_listen_address: "{{ ansible_host | default(ansible_default_ipv4.address) }}"
```

This usually resolves to the DNS VM's LAN IP.

### `dnsmasq_upstream_servers`

Upstream DNS resolvers used for all non-local domains.

```yaml
dnsmasq_upstream_servers:
  - "1.1.1.1"
  - "9.9.9.9"
```

Adjust these values to match local preference or policy.

### `dnsmasq_cache_size`

dnsmasq cache size.

```yaml
dnsmasq_cache_size: 1000
```

## Templates

This role uses the following template:

```text
roles/dnsmasq_lan_dns/templates/nebula-lan.conf.j2
```

The template renders a dnsmasq configuration file at:

```text
/etc/dnsmasq.d/nebula-lan.conf
```

The key DNS behavior is:

```text
address=/.<lab-domain>/<istio-ingress-ip>
address=/<lab-domain>/<istio-ingress-ip>
```

This means:

```text
anything.example.test -> 192.0.2.221
example.test          -> 192.0.2.221
```

## Dependencies

This role does not depend on other Ansible Galaxy roles.

It does depend on the broader platform being available if you want local names to resolve to working applications:

- `kube_metallb`
- `kube_istio`
- Istio ingress gateway service with an external IP
- Istio `Gateway` and `VirtualService` resources for the hostnames being tested

## Example Playbook

```yaml
---
- name: Configure LAN DNS servers
  hosts: dns_servers
  become: true
  roles:
    - dnsmasq_lan_dns
```

Example with overridden values:

```yaml
---
- name: Configure LAN DNS servers
  hosts: dns_servers
  become: true
  vars:
    dnsmasq_domain: "example.test"
    dnsmasq_ingress_ip: "192.0.2.221"
    dnsmasq_upstream_servers:
      - "1.1.1.1"
      - "9.9.9.9"
  roles:
    - dnsmasq_lan_dns
```

## Validation

Run the DNS playbook:

```bash
ansible-playbook playbooks/dns.yml
```

Verify dnsmasq is running:

```bash
ansible dns_servers -b -a "systemctl status dnsmasq --no-pager"
```

Verify dnsmasq is listening on port 53:

```bash
ansible dns_servers -b -m shell -a "ss -lntup | grep ':53'"
```

Test resolution from a LAN client:

```bash
dig @192.0.2.50 smoke.example.test
dig @192.0.2.50 grafana.example.test
dig @192.0.2.50 anything.example.test
```

Expected answer:

```text
192.0.2.221
```

Test the Istio ingress route after the client is using the DNS server:

```bash
curl http://smoke.example.test
```

Expected response should include:

```text
Welcome to nginx!
```

## Client DNS configuration

For initial testing, configure a single workstation to use the DNS VM.

On systems using `systemd-resolved`, a temporary per-interface configuration can be tested with:

```bash
sudo resolvectl dns <interface> 192.0.2.50
sudo resolvectl domain <interface> '~example.test'
resolvectl query smoke.example.test
```

The `~example.test` domain route sends only that domain to the lab DNS server.

Once validated, configure the home router or DHCP server to hand out the DNS VM as a DNS resolver for LAN clients.

## Design notes

This role intentionally runs DNS outside Kubernetes.

Running LAN DNS inside Kubernetes is possible, but it creates a dependency loop:

```text
Clients need DNS to reach the cluster.
DNS depends on the cluster being healthy.
```

Keeping DNS on a small external VM makes cluster rebuilds, upgrades, and debugging easier.

Kubernetes still has its own internal CoreDNS service for pod and service discovery. That is separate from LAN DNS.

```text
Kubernetes CoreDNS:
  internal pod/service DNS

dnsmasq_lan_dns:
  LAN client DNS for app hostnames
```

## Security Notes

This role exposes DNS on the LAN.

This role does not currently configure:

- Host firewall rules
- DNS over TLS
- DNS over HTTPS
- Authentication
- Query logging policy
- Split-horizon beyond the configured local domain
- Router DHCP integration

Future hardening should include:

- Installing and enabling `firewalld`
- Allowing only TCP/UDP 53 from trusted LAN ranges
- Confirming the resolver is not exposed to the internet
- Reviewing query logging behavior
- Documenting upstream resolver choices
- Avoiding accidental wildcard records for public domains

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
