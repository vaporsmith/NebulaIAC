# kube_rook_ceph_worker_prep

Prepares Kubernetes worker nodes for Rook-Ceph OSD placement.

This role is intentionally small and defensive. It does **not** format, mount,
partition, or wipe disks. It verifies that the expected OSD block device exists
and is either clean for first use or already contains a recognized Rook/Ceph
signature from an earlier run.

## Target hosts

```yaml
hosts: kube_workers
become: true
```

## What it does

- Installs worker-side packages useful for Rook/Ceph OSD handling.
- Verifies the expected OSD device exists.
- Verifies the device is a block device.
- Allows a clean device on the first run.
- Treats an existing `ceph_bluestore` signature as an idempotent Rook/Ceph state.
- Fails closed when any unknown filesystem or storage signature is present.
- Verifies the device is at least the configured minimum size.
- Displays the worker disk layout with `lsblk`.

## Defaults

```yaml
rook_ceph_osd_device: "/dev/vdb"
rook_ceph_min_osd_size_gb: 240

rook_ceph_allowed_existing_signatures:
  - ceph_bluestore

rook_ceph_worker_packages:
  - lvm2
  - cryptsetup
```

## Expected worker layout

For this lab, each kube worker should look roughly like this:

```text
vda      20G disk
â”œâ”€vda1
â”œâ”€vda2
â”œâ”€vda3
â””â”€vda4       /
vdb     250G disk
```

Before the initial Rook deployment, `/dev/vdb` should have:

- no partitions
- no filesystem type
- no mountpoint
- no `wipefs` signatures

After Rook initializes the OSD, `wipefs` is expected to report
`ceph_bluestore`. Subsequent playbook runs accept that signature and continue.
Any other signature still stops the playbook for manual investigation.

## Manual validation

```bash
ansible kube_workers -m command -a "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS"
ansible kube_workers -m command -a "sudo wipefs -n /dev/vdb"
```

Before first use, `wipefs` should produce no signatures. After successful OSD
initialization, `ceph_bluestore` is expected. The role never wipes a device;
removing an unexpected or stale signature remains an explicit operator action.

## Why this role exists

Rook can consume raw devices directly, but it is very easy to accidentally point it at the wrong device or a device with stale signatures. This role gives the playbook a fail-fast checkpoint before the Ceph cluster is created.

