#!/usr/bin/env python3

import argparse
import subprocess
from pathlib import Path
import sys

ROOT_DIR = Path(__file__).resolve().parent.parent
INFRA_DIR = ROOT_DIR / "infrastructure"
SCRIPTS_DIR = ROOT_DIR / "scripts"
INVENTORY_SCRIPT = SCRIPTS_DIR / "generate_inventory.py"

def list_services():
    return [d.name for d in INFRA_DIR.iterdir() if d.is_dir()]

def apply_service(service_dir: Path):
    print(f"🚀 Applying infrastructure in: {service_dir}")
    subprocess.run(["tofu", "init"], cwd=service_dir, check=True)
    subprocess.run(["tofu", "apply", "-auto-approve"], cwd=service_dir, check=True)
    subprocess.run(["python3", str(INVENTORY_SCRIPT)], check=True)
    print("✅ Inventory updated after apply.")

def destroy_service(service_dir: Path):
    print(f"🔻 Destroying infrastructure in: {service_dir}")
    try:
        subprocess.run(["tofu", "destroy", "-auto-approve"], cwd=service_dir, check=True)
        print("🧹 Cleaning up Ansible inventory...")
        subprocess.run(["python3", str(INVENTORY_SCRIPT)], check=True)
        print("✅ Inventory regenerated after destroy.")
    except subprocess.CalledProcessError as e:
        print(f"❌ Error during destroy: {e}")

def main():
    parser = argparse.ArgumentParser(description="Manage OpenTofu services and regenerate Ansible inventory.")
    parser.add_argument("service", choices=list_services(), help="Service directory name")
    parser.add_argument("action", choices=["apply", "destroy"], help="Action to perform")

    args = parser.parse_args()
    service_dir = INFRA_DIR / args.service

    if args.action == "apply":
        apply_service(service_dir)
    elif args.action == "destroy":
        destroy_service(service_dir)

if __name__ == "__main__":
    main()
