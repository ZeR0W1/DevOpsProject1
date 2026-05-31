# Ansible deployment layer

This directory contains the Ansible control-node automation used to configure instances provisioned by Terraform.

Main project documentation: [../README.md](../README.md)

## Assumptions

- control node is Linux-based (commands/examples are Linux-first)
- `ansible` is installed locally and `ANSIBLE_CONFIG=ansible.cfg` is used when running playbooks
- AWS credentials for Terraform/Ansible orchestration are already configured on the control node
- `vault/staging.yml` is present with environment-specific values
- SSH private key file used for EC2 access exists locally and has restrictive permissions (`chmod 600 <key>.pem`)

## What this Ansible layer does

- applies Terraform from Ansible orchestration (`playbooks/apply_terraform.yml`)
- syncs Terraform outputs into runtime inventory/vars (`playbooks/sync_from_terraform.yml`)
- installs/configures frontend nginx (`playbooks/install-nginx.yml`)
- deploys backend and worker app services (`playbooks/deploy_app.yml`)

## Main playbooks

- `playbooks/site.yml` — full end-to-end orchestrator
- `playbooks/apply_terraform.yml` — runs Terraform lifecycle tasks
- `playbooks/sync_from_terraform.yml` — generates inventory/runtime vars from Terraform outputs
- `playbooks/install-nginx.yml` — frontend nginx + content sync
- `playbooks/deploy_app.yml` — backend/worker deployment

## Useful run commands

```bash
cd Ansible-modules-01

# Full end-to-end run
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/site.yml

# Only sync outputs -> inventory/group_vars
ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/sync_from_terraform.yml

# Skip generated group_vars writes when you want cleaner diffs
SKIP_GROUP_VARS_WRITE=true ANSIBLE_CONFIG=ansible.cfg ansible-playbook playbooks/sync_from_terraform.yml
```


## Vault and Secrets Manager responsibilities

- **Ansible Vault (`vault/staging.yml`)**: deployment-time values for playbooks (for example SSH private key path).
- **AWS Secrets Manager**: runtime application secrets (for example DB password consumed by worker via IAM).

This separation keeps runtime DB credentials out of generated Ansible app environment files while still allowing automated deployments.

## Notes

- This is a control-node workflow; do not run these playbooks on target EC2 instances directly.
- SSH key path and vault-backed values are sourced from `vault/staging.yml`.
- Generated files (`inventory.ini`, some `group_vars/*.yml`) can change per environment.
- `group_vars/backend.example.yml` and `group_vars/worker.example.yml` are optional templates/examples only (not required by the active site flow).