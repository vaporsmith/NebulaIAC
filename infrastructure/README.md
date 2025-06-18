# README: `infrastructure/` Directory

This directory contains OpenTofu (Terraform) configurations for provisioning virtual machines and services in OpenNebula.

Each subdirectory (e.g., `test_service`, `open_project`) represents a standalone service or stack, with its own configuration files.

---

## Creating a New Service Directory

To create a new service from the `test_service` template:

```bash
cp -r infrastructure/test_service infrastructure/<new_service>
```

Then edit the following file:

### `terraform.tfvars`
Defines variable values to pass into the module. Example fields:
```hcl
ansible_group_name = "my_service"
vm_names           = ["host1", "host2"]
vm_template_name   = "Ubuntu Minimal 24.04"
network_id         = 1
```

Refer to `variables.tf` for a complete list of accepted variables and descriptions.

---

## Key Files in Each Service Directory

### `main.tf`
- Defines OpenNebula provider and VM resources.
- Uses variables to configure CPU, memory, template, and networking.

### `variables.tf`
- Declares all expected input variables.
- Centralizes control for host and resource behavior.

### `terraform.tfvars`
- Overrides default values and sets specific configurations for the service.

### `outputs.tf`
- Exposes output values (such as IPs) that may be referenced externally.

### `locals_inventory.tf`
- Generates the `inventory-hosts.yaml` used for Ansible integration.

---

## Inventory Integration

After a successful apply or destroy, `inventory-hosts.yaml` will be generated or removed. The master inventory is located at:
```
ansible/inventory/inventory.yaml
```
This file is updated automatically via the `generate_inventory.py` script.

---

## Managing Services
Use the provided wrapper script for lifecycle management:
```bash
./scripts/manage.py <service> <action>
```
Example:
```bash
./scripts/manage.py test_service apply
```


