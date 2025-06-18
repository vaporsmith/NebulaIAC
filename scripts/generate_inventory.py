#!/usr/bin/env python3

import yaml
from pathlib import Path
import shutil

# Find the project root (looks for 'infrastructure' directory)
def find_project_root(start: Path) -> Path:
    for parent in [start] + list(start.parents):
        if (parent / "infrastructure").exists():
            return parent
    raise FileNotFoundError("Could not find project root with 'infrastructure/' directory.")

def collect_host_entries(infra_dir: Path):
    host_groups = {}
    for path in infra_dir.glob("**/inventory-hosts.yaml"):
        with open(path) as f:
            data = yaml.safe_load(f)
            group = data.get("group_name")
            hosts = data.get("hosts", [])
            if group and hosts:
                host_groups[group] = {
                    "hosts": {
                        h["ip"]: {
                            "ansible_user": h.get("ansible_user", "ansible"),
                            "ansible_ssh_private_key_file": h.get("ansible_ssh_private_key_file", "../ssh/id_ansible")
                        } for h in hosts
                    }
                }
    return host_groups

def write_inventory_file(inventory_path: Path, host_groups: dict):
    if inventory_path.exists():
        backup_path = inventory_path.with_suffix(".yaml.bak")
        shutil.copy(inventory_path, backup_path)
    inventory = {
        "all": {
            "children": host_groups
        }
    }
    with open(inventory_path, "w") as f:
        yaml.dump(inventory, f, default_flow_style=False)

if __name__ == "__main__":
    root = find_project_root(Path(__file__).resolve())
    infra = root / "infrastructure"
    inventory_path = root / "ansible" / "inventory" / "inventory.yaml"

    host_groups = collect_host_entries(infra)
    write_inventory_file(inventory_path, host_groups)
    print(f"✅ Inventory written to '{inventory_path}' with {len(host_groups)} host groups.")
