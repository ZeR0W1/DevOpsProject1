## Terraform infrastructure layer

This directory defines the AWS infrastructure for the project using Terraform modules.

Main project documentation: [../README.md](../README.md)

## Scope (what Terraform creates)

- VPC, subnets, route tables, internet gateway
- Security groups for frontend, backend, worker, DB, and admin SSH access
- EC2 instances for frontend/backend/worker
- RDS PostgreSQL instance + DB subnet group
- S3 bucket for catalog/object storage
- SNS topic + email subscription
- IAM role + instance profile + policies for EC2 runtime access
- CloudWatch billing alarm

## Module map

- `modules/networking` → network primitives + security groups
- `modules/iam` → IAM role/profile/policies
- `modules/ec2` → compute instances + launch template
- `modules/rds_postgresql` → PostgreSQL database resources
- `modules/s3_bucket` → object storage
- `modules/sns_topic` → notifications
- `modules/services` → operational monitoring resources

## Inputs and outputs

- Inputs are defined in `variables.tf`
- Active environment values go in local `terraform.tfvars` (intentionally not tracked)
- Example values are provided in `terraform.tfvars.example`. Rename to terraform.tfvars after replacing example values.
- Useful outputs are exposed in `outputs.tf` (IPs, endpoints, ARNs, etc.)

S3 toggle:
- `create_s3_bucket = true`: Terraform creates/manages the S3 bucket module.
- `create_s3_bucket = false` (recommended when reusing an existing bucket): Terraform skips bucket creation, but still uses `bucket_name` for app/IAM wiring.

## State management

Current mode: **local state** (`terraform/terraform.tfstate`).

Reasoning for this decision:
- single operator workflow from one control machine
- easier offline demonstration
- no additional backend bootstrap complexity

Production/team recommendation:
- migrate to remote backend (for example S3 + DynamoDB locking)
- enforce access control and state versioning

## Prerequisites

- Terraform installed
- AWS credentials configured (`aws configure` or environment-based auth)
- Region/account permissions for VPC, EC2, IAM, RDS, S3, SNS, CloudWatch, Secrets Manager

## Standard workflow

```bash
cd terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output
```

## Destroy workflow

```bash
cd terraform
terraform destroy
```

If using a custom var file:

```bash
terraform destroy -var-file=terraform.fresh.tfvars
```

## Security notes

- Never commit secrets, private keys, or state files.
