# kube_rook_ceph_worker_prep

Prepares Kubernetes worker nodes for Rook-Ceph OSD placement.

This role is intentionally small and defensive. It does **not** format, mount, partition, or wipe disks. It verifies that the expected raw OSD block device exists and is safe for Rook to consume.

## Target hosts

```yaml
hosts: kube_workers
become: true
```

## What it does

- Installs worker-side packages useful for Rook/Ceph OSD handling.
- Verifies the expected OSD device exists.
- Verifies the device is a block device.
- Verifies the device has no filesystem signatures.
- Verifies the device is at least the configured minimum size.
- Displays the worker disk layout with `lsblk`.

## Defaults

```yaml
rook_ceph_osd_device: "/dev/vdb"
rook_ceph_min_osd_size_gb: 240

rook_ceph_worker_packages:
  - lvm2
  - cryptsetup
```

## Expected worker layout

For this lab, each kube worker should look roughly like this:

```text
vda      20G disk
├─vda1
├─vda2
├─vda3
└─vda4       /
vdb     250G disk
```

`/dev/vdb` should have:

- no partitions
- no filesystem type
- no mountpoint
- no `wipefs` signatures

## Manual validation

```bash
ansible kube_workers -m command -a "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS"
ansible kube_workers -m command -a "sudo wipefs -n /dev/vdb"
```

The `wipefs` command should produce no filesystem signatures for `/dev/vdb`.

## Why this role exists

Rook can consume raw devices directly, but it is very easy to accidentally point it at the wrong device or a device with stale signatures. This role gives the playbook a fail-fast checkpoint before the Ceph cluster is created.

