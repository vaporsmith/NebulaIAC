#!/usr/bin/env python3
import os
import yaml

ROOT_DIR = os.path.abspath(os.path.dirname(__file__))
INFRA_DIR = os.path.join(ROOT_DIR, "..", "infrastructure")
INVENTORY_FILE = os.path.join(ROOT_DIR, "..", "ansible", "inventory", "inventory.yaml")

inventory = {
    "all": {
        "children": {}
    }
}

for root, _, files in os.walk(INFRA_DIR):
    for file in files:
        if file == "inventory-hosts.yaml":
            filepath = os.path.join(root, file)
            with open(filepath, "r") as f:
                data = yaml.safe_load(f)

            group = data.get("group_name", "ungrouped")
            if group not in inventory["all"]["children"]:
                inventory["all"]["children"][group] = {"hosts": {}}

            hosts = data.get("hosts", {})

            if not isinstance(hosts, dict):
                print(f"⚠️  Skipping file '{filepath}' - 'hosts' is not a dict")
                continue

            for name, host in hosts.items():
                ip = host.get("ip")
                if ip:
                    inventory["all"]["children"][group]["hosts"][name] = {
                        "ansible_host": ip
                    }

with open(INVENTORY_FILE, "w") as f:
    yaml.dump(inventory, f, default_flow_style=False)

print(f"✅ Inventory written to '{INVENTORY_FILE}' with {len(inventory['all']['children'])} host group(s).")
