# 🌌 NebulaIAC

**NebulaIAC** is a modular, reproducible, and automation-friendly Infrastructure as Code (IaC) framework designed for secure, cloud-portable, and scalable service deployments. It balances real-world practicality with enterprise-grade architectural vision.

This project was created to explore, refine, and demonstrate modern infrastructure automation principles—not to provide a turnkey product. It's a working prototype and a public-facing example of how structured infrastructure engineering can evolve toward robust, secure systems.

---

## 🚀 Project Goals

- **Showcase professional IaC techniques** using real-world tooling and automation workflows
- **Provide a working base** for deploying VMs, managing services, and orchestrating infrastructure securely and reproducibly
- **Enable modular service stacks** that can be reused, combined, or extended without bloating shared configuration
- **Illustrate a path** toward enterprise-ready, zero-trust-compliant infrastructure
- **Support learning and demonstration** for others interested in modern infrastructure practices

---

## 🛠 Features

- ✅ **Terraform/OpenTofu-powered infrastructure provisioning**
- ✅ **Ansible-driven configuration management and post-deployment automation**
- ✅ **Dynamic inventory generation** with host group definitions embedded in each stack
- ✅ **Location-aware scripting** for regenerating Ansible inventory from all infrastructure components
- ✅ **Stack-isolated IaC directories** to cleanly manage multi-service environments
- ✅ **Centralized Ansible directory** with reusable roles, SSH keys, and global variables
- ✅ Designed with flexibility for **airgapped**, **on-prem**, **cloud**, or **hybrid** lab environments

---

## 📂 Directory Overview

```bash
nebula/
├── ansible/              # Roles, inventory, config, vars, and SSH keys
├── infrastructure/       # Per-stack Terraform modules and host definitions
├── packer/               # Image build templates (planned/optional)
├── scripts/              # CLI wrappers for Terraform/Tofu and orchestration
├── generate_inventory.py # Merges host YAMLs into Ansible inventory
├── README.md             # Project documentation (you're here!)
```

---

## 📦 Usage

1. **Provision a stack:**

   ```bash
   ./scripts/manage.py <stack-name> apply
   ```

2. **Generate the central Ansible inventory:**
manage.py automatically executes this, but you can re-generate the ansible inventory at any time for any reason. 
   ```bash
   ./generate_inventory.py
   ```

3. **Run a playbook against provisioned hosts:**

   ```bash
   ansible-playbook -i ansible/inventory/inventory.yaml playbook.yaml
   ```

Stacks define their own host group and machine metadata under `infrastructure/<stack>/inventory-hosts.yaml`.

---

## 📌 Limitations

- **This is a work in progress**: NebulaIAC is under iterative development and should be treated as a prototype or reference, not a mature platform.
- **Security is a priority—but not fully implemented**: While the structure anticipates hardened, compliant builds, current deployments do _not_ reflect zero-trust standards or production-grade security practices. For example:
  - Deployments do not yet include certificate and ssl/tls management
  - Hardened images are not yet built using Packer.
  - No integrated secrets manager (e.g., Vault, sops) is wired up.
  - No integrated enterprise services have been implemented yet (DNS, Identity Management, Log Aggregation/Analysis, service monitoring, etc.)
- **Not OpenNebula itself**: This project **uses** OpenNebula for VM orchestration, but is not affiliated with or contributing to OpenNebula core development.
- **Not a polished, maintained product**: NebulaIAC is not a formal project under active maintenance. It’s a personal, exploratory effort to build and demonstrate something useful and well-architected.
- **Linux-centric and expects operator experience**: Assumes familiarity with CLI tooling, Linux, Terraform/OpenTofu, and Ansible.

---

## 🔒 Security Posture

NebulaIAC is built with a long-term vision of **zero-trust compliance**, but the current implementation should **not be considered secure by default**.

Planned or envisioned security features include:

- As-code security compliance (STIG, CIS, and other benchmarks)
- Hardened Packer-built VM images
- Pluggable secrets and identity management (Vault, OpenBao, etc.)
- HTTPS-enabled service endpoints
- Certificate-based trust and automated certificate management

This project represents the architectural groundwork, not the destination. Contributions or forks focused on building out these layers are welcome.

---

## 🙌 Contributing / Feedback

Suggestions, discussions, and feedback are encouraged. Forks are welcome. If you find value in this setup or want to shape its future, feel free to open issues or share your use cases.

---

## 📄 License

MIT License — use freely, attribute respectfully.

---

> _NebulaIAC is not a product. It’s a platform for learning, growth, and showcasing sound, scalable infrastructure practices. Treat it as a starting point for building systems that respect modern security, operational, and design principles._

