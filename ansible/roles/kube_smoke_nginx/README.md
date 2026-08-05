# kube_smoke_nginx

Deploys an nginx smoke test workload and routes it through the Istio ingress gateway.

This role validates the end-to-end Kubernetes ingress path for the NebulaIAC homelab cluster:

```text
LAN client
  ↓
MetalLB-assigned ingress IP
  ↓
istio-ingressgateway
  ↓
Istio Gateway
  ↓
Istio VirtualService
  ↓
smoke-nginx ClusterIP service
  ↓
nginx pods
```

This role is intentionally simple. It is not meant to deploy a production application. Its purpose is to prove that MetalLB, Istio ingress, Kubernetes Services, and pod networking are all working together.

This README intentionally uses documentation/example IP addresses and hostnames. Do not commit real home network ranges, router details, DHCP scopes, VM allocation pools, service IPs, public IPs, VPN addresses, or remote-access details to a public repository unless there is a specific reason to do so.

## Current target environment

- Kubernetes deployed with `kubeadm`
- Rocky Linux 9.x nodes
- OpenNebula-backed VMs on a bridged LAN
- Flannel CNI using `host-gw`
- MetalLB running in Layer 2 mode
- Istio installed with an ingress gateway
- Istio ingress gateway exposed through a MetalLB-assigned `LoadBalancer` IP
- No DNS dependency required for the smoke test

## What this role does

The role performs the following actions from the Kubernetes control plane node:

1. Renders an nginx smoke test manifest.
2. Applies an nginx `Deployment`.
3. Applies an nginx `Service`.
4. Applies an Istio `Gateway`.
5. Applies an Istio `VirtualService`.
6. Waits for the nginx deployment to roll out.
7. Looks up the Istio ingress gateway external IP.
8. Prints a `curl` command that can be used to validate routing.

The service deployed by this role should normally be `ClusterIP`. The app itself does not need a dedicated MetalLB IP because traffic should enter through the Istio ingress gateway.

## Requirements

This role assumes the Kubernetes cluster, MetalLB, and Istio are already functional.

Required prior cluster state:

- Kubernetes control plane initialized.
- Worker nodes joined and `Ready`.
- CNI installed and working.
- Pod-to-pod networking confirmed.
- ClusterIP service networking confirmed.
- MetalLB installed and configured.
- Istio installed.
- `istio-ingressgateway` service has a MetalLB-assigned external IP.
- `kubectl` available on the control plane.
- `/etc/kubernetes/admin.conf` present on the control plane.

This role is intended to run against the `kube_controllers` Ansible group.

## Role Variables

Default variables are defined in:

```text
roles/kube_smoke_nginx/defaults/main.yml
```

### `smoke_nginx_namespace`

Namespace where the smoke test workload and Istio routing resources are deployed.

```yaml
smoke_nginx_namespace: "default"
```

### `smoke_nginx_name`

Base name for the Deployment, Service, and VirtualService.

```yaml
smoke_nginx_name: "smoke-nginx"
```

### `smoke_nginx_replicas`

Number of nginx pod replicas.

```yaml
smoke_nginx_replicas: 3
```

### `smoke_nginx_image`

Container image used for the smoke test.

```yaml
smoke_nginx_image: "nginx:stable"
```

### `smoke_nginx_host`

Hostname matched by the Istio `Gateway` and `VirtualService`.

```yaml
smoke_nginx_host: "smoke.example.test"
```

This hostname does not need to exist in DNS for the first validation. The route can be tested with an explicit HTTP `Host` header:

```bash
curl -H "Host: smoke.example.test" http://192.0.2.221
```

> Note: `192.0.2.0/24` is a documentation-only address range. Replace example values with valid addresses from your own lab network.

### `smoke_nginx_service_type`

Kubernetes Service type for the smoke nginx workload.

```yaml
smoke_nginx_service_type: "ClusterIP"
```

For the Istio ingress pattern, `ClusterIP` is preferred. The application should be reachable through the Istio ingress gateway, not through its own MetalLB `LoadBalancer` IP.

### `smoke_nginx_service_port`

Service port exposed by the nginx service.

```yaml
smoke_nginx_service_port: 80
```

### `smoke_nginx_container_port`

Container port exposed by the nginx pod.

```yaml
smoke_nginx_container_port: 80
```

### `istio_ingress_gateway_name`

Name of the Istio `Gateway` resource created for the smoke test.

```yaml
istio_ingress_gateway_name: "smoke-nginx-gateway"
```

### `istio_ingress_gateway_selector`

Selector used by the Istio `Gateway` resource to bind to the Istio ingress gateway deployment.

```yaml
istio_ingress_gateway_selector:
  istio: ingressgateway
```

This selector must match the labels on the Istio ingress gateway service/deployment.

## Templates

This role uses the following template:

```text
roles/kube_smoke_nginx/templates/smoke-nginx.yaml.j2
```

The template renders:

- `Deployment`
- `Service`
- `Gateway`
- `VirtualService`

## Dependencies

This role depends on a functioning platform layer created by the earlier Kubernetes roles:

- `kube_common`
- `kube_control_plane`
- `kube_cni`
- `kube_worker`
- `kube_metallb`
- `kube_istio`

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

- name: Deploy nginx Istio smoke test
  hosts: kube_controllers
  become: true
  roles:
    - kube_smoke_nginx
```

## Example Playbook

```yaml
---
- name: Deploy nginx Istio smoke test
  hosts: kube_controllers
  become: true
  roles:
    - kube_smoke_nginx
```

Example with an overridden smoke hostname:

```yaml
---
- name: Deploy nginx Istio smoke test
  hosts: kube_controllers
  become: true
  vars:
    smoke_nginx_host: "smoke.example.test"
  roles:
    - kube_smoke_nginx
```

## Validation

After running the role, verify the smoke nginx deployment:

```bash
ansible kube_controllers -a "kubectl get deploy,pods,svc -n default -l app=smoke-nginx -o wide"
```

Verify the Istio routing resources:

```bash
ansible kube_controllers -a "kubectl get gateway,virtualservice -n default"
```

Verify the Istio ingress gateway external IP:

```bash
ansible kube_controllers -a "kubectl get svc -n istio-system istio-ingressgateway -o wide"
```

Example ingress gateway output:

```text
NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)
istio-ingressgateway   LoadBalancer   10.100.102.231   192.0.2.221    15021:30614/TCP,80:32685/TCP,443:30676/TCP
```

Test routing from a LAN client before DNS exists:

```bash
curl -H "Host: smoke.example.test" http://192.0.2.221
```

Expected response should include:

```text
Welcome to nginx!
```

This proves that traffic is entering through the Istio ingress gateway and routing to the internal nginx service.

## DNS Notes

DNS is not required to validate this role.

Before DNS exists, use:

```bash
curl -H "Host: smoke.example.test" http://192.0.2.221
```

After DNS is configured, the hostname can point to the Istio ingress gateway external IP:

```text
smoke.example.test  ->  192.0.2.221
```

Then the test becomes:

```bash
curl http://smoke.example.test
```

In a homelab, many hostnames can point to the same Istio ingress gateway IP. Istio can route requests by hostname using `Gateway` and `VirtualService` resources.

Example:

```text
app1.example.test     ->  192.0.2.221
grafana.example.test  ->  192.0.2.221
smoke.example.test    ->  192.0.2.221
```

## Notes

The smoke nginx service should usually remain `ClusterIP`.

If the smoke nginx service is accidentally left as `LoadBalancer`, it may receive its own MetalLB IP and bypass the Istio ingress path. That can be useful for testing MetalLB directly, but it is not the desired ingress validation path.

Desired model:

```text
Client
  ↓
Istio ingress gateway LoadBalancer IP
  ↓
Istio Gateway / VirtualService
  ↓
ClusterIP app service
  ↓
Pods
```

## Troubleshooting

### Curl returns a 404

A 404 from the Istio ingress gateway usually means the request reached Istio, but no route matched.

Check:

- The `Host` header matches `smoke_nginx_host`.
- The `Gateway` hosts list includes the requested hostname.
- The `VirtualService` hosts list includes the requested hostname.
- The `VirtualService` references the correct gateway name.

### Curl cannot connect

If curl cannot connect to the ingress IP:

- Verify the `istio-ingressgateway` service has an external IP.
- Verify MetalLB speaker pods are running.
- Verify the selected IP is inside the MetalLB address pool.
- Verify the selected IP does not overlap with DHCP, VM allocation, or static hosts.
- Verify the client is on the same LAN or has a route to the ingress IP.

### Route exists but nginx does not respond

Check the workload:

```bash
ansible kube_controllers -a "kubectl get pods -n default -l app=smoke-nginx -o wide"
ansible kube_controllers -a "kubectl get svc -n default smoke-nginx -o wide"
ansible kube_controllers -a "kubectl describe virtualservice smoke-nginx -n default"
```

## Security Notes

This role creates an HTTP ingress route for testing only.

This role does not configure:

- TLS
- Authentication
- Authorization policies
- Request authentication
- Rate limiting
- Production ingress hardening
- DNS
- Host firewall rules

Future hardening should include:

- Replacing HTTP-only test routes with TLS-enabled ingress
- Adding DNS intentionally
- Limiting exposed hostnames
- Reviewing Istio authorization policies
- Reviewing Istio telemetry and access logs
- Ensuring app services remain internal unless intentionally exposed
- Validating host firewall rules

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
