# kube_helm

Installs a pinned Helm 3 binary on the Kubernetes control-plane host. The
published archive checksum is verified before installation.

This role owns only the Helm client. Individual platform roles own their Helm
repositories, releases, values, and readiness checks.


