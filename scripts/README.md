# README: `scripts/` Directory

This directory contains utility scripts used to manage and automate your OpenTofu + Ansible infrastructure workflows.

## `setup_age.sh`

**Purpose:** Creates and validates the operator age identity used to encrypt
and recover OpenBao initialization material.

Run it as the normal user that executes Ansible:

```bash
./scripts/setup_age.sh
```

The script:

- Ensures `/data/.age` exists, is owned by the invoking user, and has mode
  `0700`.
- Creates `/data/.age/keys.txt` with mode `0600` when it does not exist.
- Preserves and validates an existing identity instead of replacing it.
- Prints the public `openbao_age_recipient` YAML value for
  `ansible/vars/global.yml`.
- Reports the future encrypted recovery artifact location:
  `/data/.age/openbao-init.sops.json`.

The private `keys.txt` file must never be committed to Git. Back it up to a
separate encrypted or physically secured location. To select another absolute
directory, set `NEBULAIAC_AGE_DIR` and configure `openbao_age_directory` to the
same path.

---

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


