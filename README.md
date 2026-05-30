# 🌌 NebulaIAC

NebulaIAC is a personal homelab Infrastructure-as-Code project for experimenting with reusable automation patterns across private-cloud infrastructure, Linux systems, Ansible configuration management, and OpenTofu/Terraform-based provisioning.

This repository is not a turnkey product or mature platform. It is an active engineering lab used to explore how modular infrastructure code, generated inventory, stack-isolated service definitions, and reusable automation can make small-scale infrastructure easier to reproduce, extend, and operate.

## What This Demonstrates

NebulaIAC reflects my approach to platform engineering:

* Prefer reusable infrastructure patterns over one-off manual setup.
* Keep service stacks isolated while allowing them to contribute to shared operational state.
* Generate configuration and inventory from source-controlled definitions instead of manually maintaining static files.
* Use wrapper scripts to simplify common infrastructure workflows without hiding the underlying tools.
* Organize infrastructure code so it can evolve toward on-prem, private-cloud, cloud, or hybrid deployment models.

## Project Goals

* Build a practical homelab framework for provisioning VMs and platform services.
* Use OpenTofu/Terraform for infrastructure provisioning.
* Use Ansible for configuration management and post-deployment automation.
* Support modular service stacks that can be reused, combined, or extended.
* Generate centralized Ansible inventory from per-stack host definitions.
* Explore patterns that could later support stronger security, image hardening, secrets management, observability, and enterprise service integration.

## Features

* OpenTofu/Terraform-powered infrastructure provisioning.
* Ansible-driven configuration management and post-deployment automation.
* Dynamic inventory generation from stack-local host definitions.
* Location-aware scripts for managing infrastructure from different working directories.
* Stack-isolated IaC directories for managing multiple service environments.
* Centralized Ansible structure for roles, inventory, configuration, variables, and SSH material.
* Designed with future flexibility for air-gapped, on-premises, private-cloud, public-cloud, or hybrid lab environments.

## Directory Overview

```text
nebula/
├── ansible/              # Roles, inventory, config, vars, and SSH material
├── infrastructure/       # Per-stack OpenTofu/Terraform code and host definitions
├── packer/               # Image build templates planned for future use
├── scripts/              # CLI wrappers for infrastructure workflows
├── generate_inventory.py # Merges stack host YAML into central Ansible inventory
└── README.md             # Project documentation
```

## Usage

Provision a stack:

```bash
./scripts/manage.py <stack-name> apply
```

Generate the central Ansible inventory manually:

```bash
./generate_inventory.py
```

Run an Ansible playbook against provisioned hosts:

```bash
ansible-playbook -i ansible/inventory/inventory.yaml playbook.yaml
```

Each stack defines its own host group and machine metadata under:

```text
infrastructure/<stack>/inventory-hosts.yaml
```

## Current Status

NebulaIAC is under active development and should be treated as a prototype/reference implementation, not a production-ready platform.

Current limitations include:

* Security hardening is planned but incomplete.
* Certificate and SSL/TLS management are not yet implemented.
* Hardened Packer-built images are planned but not complete.
* No integrated secrets manager is currently wired in.
* Enterprise services such as DNS, identity management, logging, monitoring, and service discovery are not yet fully implemented.
* The project currently assumes Linux and operator familiarity with CLI tooling, OpenTofu/Terraform, Ansible, and systems administration.

## Security Direction

NebulaIAC is being structured with future security and compliance automation in mind, but current deployments should not be considered secure by default.

Planned or envisioned work includes:

* Hardened VM image builds with Packer.
* Secrets management using Vault, OpenBao, SOPS, or a similar tool.
* Certificate-based trust and automated certificate management.
* HTTPS-enabled service endpoints.
* Security compliance automation aligned to benchmarks such as STIG or CIS.
* Logging, monitoring, and identity integration patterns for reusable service stacks.

## Relationship to OpenNebula

This project uses OpenNebula as one possible VM orchestration target, but it is not affiliated with or contributing to OpenNebula core development.

## Contributing / Feedback

Suggestions, forks, and feedback are welcome. This is primarily a personal engineering lab, but I am happy to discuss patterns, tradeoffs, and improvements with others working on similar infrastructure automation problems.

## License

MIT License — use freely, attribute respectfully.
