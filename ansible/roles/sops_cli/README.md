# Ansible Role: `sops_cli`

Installs a pinned [SOPS](https://github.com/getsops/sops) binary after
verifying its SHA-256 checksum.

SOPS is a shared administration capability in NebulaIAC. The role installs the
CLI but does not own encrypted documents, generate private keys, or distribute
age identities. Product roles such as `kube_openbao` consume the installed CLI.

## Role ownership

This role owns:

- The installed SOPS binary.
- The pinned SOPS version.
- Download checksum verification.
- SOPS version validation after installation.

This role does not own:

- The operator's private age identity.
- OpenBao initialization or unseal operations.
- Application secrets.
- Kubernetes Secrets or ExternalSecret resources.

## Why SOPS and age are needed

The OpenBao role can initialize an uninitialized OpenBao cluster and reconcile
sealed members during later playbook runs. Initialization produces Shamir
unseal shares and an initial root token. Those values must never be written to
Git or left unencrypted on a Kubernetes node.

The `kube_openbao` role therefore:

1. Checks OpenBao's current initialization and seal state.
2. Initializes OpenBao only when it reports `initialized=false`.
3. Encrypts the initialization response with SOPS and an age public recipient.
4. Retains an encrypted copy on the Kubernetes controller.
5. Fetches an encrypted recovery copy to the Ansible control machine.
6. Uses that encrypted artifact to unseal sealed OpenBao members on later runs.

The age public recipient may be stored in project configuration. The matching
private identity must remain outside the repository and outside the Kubernetes
cluster.

## Install `age` on the Ansible control machine

The role installs SOPS, but the `age-keygen` utility is supplied by the `age`
package. On Pop!_OS or Ubuntu, install it with:

```bash
sudo apt update
sudo apt install age
```

## Create the operator age identity

Run the project helper on the machine from which Ansible is executed. Run it as
your normal operator account; it will use `sudo` only to prepare `/data/.age`:

```bash
./scripts/setup_age.sh
```

The script is idempotent. It creates the directory with mode `0700`, creates
the private identity with mode `0600`, assigns both to the invoking user, and
does not replace an existing identity. Its final output includes the exact
public configuration value to add to `ansible/vars/global.yml`:

```yaml
openbao_age_recipient: "age1..."
```

The `age1...` recipient is public. NebulaIAC uses it to encrypt OpenBao recovery
material.

Do not display, copy into Git, or place on Kubernetes nodes the private identity
contained in:

```text
/data/.age/keys.txt
```

Back up that file to a second encrypted or physically secured location. Losing
both the private identity and the unseal shares can make an OpenBao recovery
impossible.

## Configure NebulaIAC

Place only the public recipient in the appropriate Ansible variables:

```yaml
openbao_age_recipient: "age1..."
```

NebulaIAC currently keeps shared variables in:

```text
ansible/vars/global.yml
```

Ansible does not automatically load arbitrary files from `ansible/vars/`. The
play that invokes `kube_openbao` must explicitly load it:

```yaml
- name: Install OpenBao secrets management
  hosts: kube_controllers
  become: true
  serial: 1

  vars_files:
    - ../vars/global.yml

  roles:
    - sops_cli
    - kube_helm
    - kube_openbao
```

An alternative long-term layout is:

```text
ansible/inventory/group_vars/all.yml
```

Variables in `group_vars/all.yml` adjacent to the active inventory are loaded
automatically. Do not define the same variable in both locations; choose one
authoritative source.

## SOPS use of the private identity

The `kube_openbao` role explicitly supplies this identity path to SOPS:

```text
/data/.age/keys.txt
```

For manual SOPS commands, export the same path:

```bash
export SOPS_AGE_KEY_FILE=/data/.age/keys.txt
```

To use a different absolute directory, run the helper with
`NEBULAIAC_AGE_DIR=/secure/path` and override `openbao_age_directory` with the
same value. Never put the directory inside the repository.

## Playbook usage

SOPS is required in two places:

- On the Ansible control machine to decrypt the off-cluster recovery artifact.
- On the Kubernetes controller to encrypt the initial OpenBao response without
  placing plaintext recovery material on disk.

The main Kubernetes playbook therefore installs the shared CLI locally:

```yaml
- name: Install local secret-administration tools
  hosts: localhost
  connection: local
  become: true
  gather_facts: false
  roles:
    - sops_cli
```

The OpenBao play installs the same pinned CLI on the Kubernetes controller:

```yaml
roles:
  - sops_cli
  - kube_helm
  - kube_openbao
```

## Verify the local setup

After the role has installed SOPS, confirm the versions and identity:

```bash
sops --version
age-keygen -y /data/.age/keys.txt
```

You can perform a round-trip encryption test without creating a plaintext file:

```bash
export SOPS_AGE_KEY_FILE=/data/.age/keys.txt
AGE_RECIPIENT="$(age-keygen -y "$SOPS_AGE_KEY_FILE")"

printf '{"bootstrap_test":"ok"}' \
  | sops --encrypt \
      --age "$AGE_RECIPIENT" \
      --input-type json \
      --output-type json \
      /dev/stdin \
  | sops --decrypt \
      --input-type json \
      --output-type json \
      /dev/stdin
```

The final output should contain:

```json
{"bootstrap_test":"ok"}
```

## Recovery artifact location

By default, the encrypted off-cluster OpenBao initialization artifact is stored
on the Ansible control machine at:

```text
/data/.age/openbao-init.sops.json
```

The Kubernetes controller retains an encrypted copy at:

```text
/var/lib/nebulaiac/bootstrap/openbao-init.sops.json
```

Both files are encrypted. The off-cluster copy is the authoritative disaster
recovery artifact because the Kubernetes controller may be destroyed during a
cluster rebuild.

The OpenBao role refuses to:

- Initialize an uninitialized cluster when an old recovery artifact exists.
- Overwrite existing recovery material automatically.
- Continue managing an initialized cluster when no non-empty encrypted
  off-cluster recovery artifact is available.

These failures require deliberate operator reconciliation rather than an
automatic destructive decision.

## Remaining OpenBao prerequisites

The age recipient alone is not enough to deploy OpenBao. Before enabling the
OpenBao portion of `kube.yml`, the cluster also requires:

- The `ceph-rbd` StorageClass.
- A NetworkPolicy-enforcing CNI. Flannel alone does not enforce NetworkPolicy.
- `kube_network_policy_enforced: true` only after enforcement has been tested.
- The `openbao-server-tls` Secret in the `openbao` namespace.
- At least three schedulable Kubernetes workers for the three Raft members.

Do not bypass these checks merely to make the role run. They define the minimum
security and availability contract for the OpenBao deployment.

## Role variables

See `defaults/main.yml` for the pinned version, architecture, installation path,
download URL, and checksum. Override them only as a coordinated version update;
the binary version and checksum must match.

