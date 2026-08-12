# kube_rook_ceph

Installs Rook-Ceph into the Kubernetes cluster and creates Kubernetes StorageClasses backed by Ceph.

This role turns the raw `/dev/vdb` disks on `kube_workers` into a Kubernetes-native persistent storage layer.

## Target hosts

```yaml
hosts: kube_controllers
become: true
```

The role runs from the Kubernetes controller because it uses `kubectl` and the controller-local kubeconfig.

## What it creates

- Rook-Ceph CRDs
- Rook-Ceph common resources
- Rook-Ceph CSI operator resources
- Rook-Ceph operator
- `CephCluster`
- `CephBlockPool`
- RBD StorageClass
- optional CephFS filesystem
- optional CephFS StorageClass
- optional PVC smoke tests

## Default StorageClasses

```text
ceph-rbd (default)   rook-ceph.rbd.csi.ceph.com
cephfs               rook-ceph.cephfs.csi.ceph.com
```

Use `ceph-rbd` for most single-writer application PVCs, such as databases.

Use `cephfs` for shared filesystem workloads that need `ReadWriteMany`.

## Key defaults

```yaml
rook_ceph_version: "v1.19.6"
rook_ceph_namespace: "rook-ceph"
rook_ceph_kubeconfig: "/etc/kubernetes/admin.conf"

rook_ceph_osd_device: "/dev/vdb"
rook_ceph_data_dir_host_path: "/var/lib/rook"

rook_ceph_replication_size: 3
rook_ceph_expected_osd_count: "{{ groups['kube_workers'] | length }}"

rook_ceph_ceph_image: "quay.io/ceph/ceph:v19.2.4"

rook_ceph_rbd_pool_name: "replicapool"
rook_ceph_rbd_storageclass_name: "ceph-rbd"
rook_ceph_rbd_make_default: true

rook_ceph_cephfs_enabled: true
rook_ceph_cephfs_name: "cephfs"
rook_ceph_cephfs_storageclass_name: "cephfs"

rook_ceph_smoke_test_enabled: true
rook_ceph_smoke_image: "quay.io/ceph/ceph:v19.2.4"
```

## Capacity model for this lab

With five workers and one 250G OSD disk per worker:

```text
5 × 250G = ~1.25T raw
```

Approximate usable capacity:

```text
replication size 2: ~625G usable
replication size 3: ~416G usable
```

This role defaults to replication size `3` for a more production-like lab posture.

## Placement model

The role renders an explicit `spec.storage.nodes` list from the Ansible `kube_workers` group.

Example:

```yaml
storage:
  useAllNodes: false
  useAllDevices: false
  nodes:
    - name: kube-worker-1
      devices:
        - name: vdb
```

This is intentional. It prevents Rook from discovering and consuming unintended disks.

## Required preconditions

Before this role runs:

- Kubernetes control plane is initialized.
- All workers have joined the cluster.
- Every host in the Ansible `kube_workers` group exists as a Kubernetes node.
- Every worker has a clean raw `/dev/vdb`.
- The Rook worker prep role has passed.
- The controller has `/etc/kubernetes/admin.conf`.

## Important lesson learned

Rook v1.19 needs the CSI operator resources applied during installation.

The working install order is:

```text
crds.yaml
common.yaml
csi-operator.yaml
operator.yaml
CephCluster
```

Without `csi-operator.yaml`, the cluster can stall with errors such as:

```text
no matches for kind "CephConnection" in version "csi.ceph.io/v1"
no matches for kind "OperatorConfig" in version "csi.ceph.io/v1"
```

## Final validation commands

```bash
kubectl get storageclass
kubectl get pvc
kubectl -n rook-ceph get pods -o wide
kubectl -n rook-ceph get cephcluster rook-ceph -o wide
```

Expected StorageClass output:

```text
NAME                 PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION
ceph-rbd (default)   rook-ceph.rbd.csi.ceph.com      Delete          WaitForFirstConsumer   true
cephfs               rook-ceph.cephfs.csi.ceph.com   Delete          Immediate              true
```

Expected smoke pods:

```text
rook-ceph-rbd-smoke   1/1   Running
rook-cephfs-smoke     1/1   Running
```

Expected smoke file checks:

```bash
kubectl exec rook-ceph-rbd-smoke -- cat /data/smoke.txt
kubectl exec rook-cephfs-smoke -- cat /data/smoke.txt
```

Expected output:

```text
rook-ceph-rbd-smoke
rook-cephfs-smoke
```

## Cleanup notes

Do not delete the `rook-ceph` namespace or wipe OSD devices casually. Rook/Ceph stores cluster identity and OSD state on the devices and under `rook_ceph_data_dir_host_path`.

For a full lab rebuild, clean up deliberately and wipe only the intended OSD devices.

