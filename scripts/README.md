# README: `scripts/` Directory

This directory contains utility scripts used to manage and automate your OpenTofu + Ansible infrastructure workflows.

## `manage.py`

**Purpose:** Wrapper for infrastructure lifecycle management using OpenTofu (Terraform fork).

**Usage:**

```bash
./scripts/manage.py <service_name> <action>
```

- `<service_name>`: The name of the directory under `infrastructure/` representing a Terraform-managed service.
- `<action>`: A valid OpenTofu command (e.g., `apply`, `plan`, `destroy`).

**Features:**

- Ensures execution from any directory by locating project root.
- Applies OpenTofu against the correct subdirectory.
- Automatically regenerates Ansible inventory after changes.

**Examples:**

```bash
./scripts/manage.py test_service apply
./scripts/manage.py open_project destroy
```

---

## `generate_inventory.py`

**Purpose:** Combines per-service `inventory-hosts.yaml` files into a single Ansible-compatible YAML inventory.

**Location of Output:**

```
ansible/inventory/inventory.yaml
```

**When It's Called:**

- Automatically triggered at the end of `manage.py apply` and `destroy` operations.
- Can also be run manually:

```bash
python3 scripts/generate_inventory.py
```

**Expected Input Files:** All `inventory-hosts.yaml` files found recursively under `infrastructure/` directories.

---

## Bash Completion Script (Optional)

If enabled in your shell, tab completion is available for `manage.py` via:

```bash
source scripts/manage-completion.bash
```

This script enables tab-completion for existing service directories and valid Tofu subcommands.

---

## Adding New Scripts

Place new automation or utility scripts into this directory and document them in this README for consistency.


