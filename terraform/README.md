## Terraform infrastructure

This directory contains a Terraform starting point for expressing the AWS side of the project as code.

## Module structure

The root `main.tf` wires together the following modules:

- `modules/networking` – project security groups
- `modules/iam` – IAM role, inline policies, and instance profile
- `modules/s3_bucket` – S3 bucket for the machine catalog
- `modules/sns_topic` – SNS topic, email subscription, and billing alarm
- `modules/rds_postgresql` – PostgreSQL instance and DB subnet group
- `modules/ec2` – frontend, backend, worker instances, and worker launch template

## What is modeled

- VPC-aligned project security groups
- frontend, backend, and worker EC2 instances
- worker launch template `DOT1`
- RDS PostgreSQL instance `dodb2`
- DB subnet group
- S3 bucket
- SNS topic and email subscription
- IAM role and instance profile for the EC2 instances
- CloudWatch billing alarm over 20 USD

### Important note

This Terraform was written from the **current live AWS setup** as observed in the account. Some values are intentionally kept because they reflect the current environment, including:

- public RDS access for pgAdmin
- admin PostgreSQL access via `admin_cidr`
- EC2 instances placed in the currently used public subnet

### Before using

Create a `terraform.tfvars` file in this directory, for example:

```hcl
aws_region = "us-east-1"
admin_cidr = "109.67.153.215/32"
db_password = "postgres"
```

### Usage

```bash
cd terraform
terraform init
terraform fmt
terraform validate
terraform plan
```

If you want to import the already existing infrastructure instead of recreating it, import commands will need to be added per resource.

### Caution

This is a first Terraform representation of the current AWS estate. Do **not** apply it blindly against the live account before reviewing imports, lifecycle rules, and drift between manually created resources and Terraform-managed resources.