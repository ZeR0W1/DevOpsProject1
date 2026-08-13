# Worker service

Project overview: [../../../README.md](../../../README.md) · Helm chart:
[../../../helm/worker](../../../helm/worker)

## Functional intent

The worker is the persistence and integration layer.

- receives verified machine payloads from the backend
- writes and reads machine records through PostgreSQL/RDS as the primary datastore
- exports the current catalog to a local JSON file and synchronizes fixed object
  `instances.json` to the Terraform-owned application S3 bucket
- sends metadata-only SNS notifications after a successful synchronization

## Structure

```text
src/worker/
  api.py
  config.py
  README.md
```

## Local checks

From `app/src/worker`, create an isolated environment and install the runtime and
test dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt -r ../requirements-test.txt
python -m pytest -q test_api.py
```

For a local API smoke run without AWS or PostgreSQL integrations:

```bash
export POSTGRES_ENABLED=false
export S3_SYNC_ENABLED=false
export SNS_NOTIFICATIONS_ENABLED=false
export BACKEND_HOST=localhost
python ./api.py
```

The production defaults enable PostgreSQL, S3, and SNS. Do not use real passwords
or cloud credentials in shell history; the Kubernetes deployment supplies its
runtime configuration through ConfigMaps, Secrets, and Pod Identity.

## Container and EKS deployment

`Dockerfile.worker` runs the API on port `8000`. The `helm/worker` chart deploys
two replicas behind an internal `ClusterIP` Service in namespace `devops-app`.
The backend reaches it through Kubernetes Service DNS name `worker`; the worker
is not a public endpoint.

The chart supplies non-secret runtime values through its ConfigMap:

- PostgreSQL host, port, database, user, table, and TLS mode;
- AWS region and Terraform-owned application bucket/SNS identifiers;
- fixed S3 object key `instances.json`; and
- integration enablement flags.

Ansible synchronizes the generated RDS password from AWS Secrets Manager into
namespace Secret `worker-db-secret` with suppressed output. The Deployment reads
only key `password` through `secretKeyRef`; the password must never appear in
Helm values, ConfigMaps, logs, examples, or repository files.

The worker ServiceAccount `worker-sa` receives short-lived AWS credentials through
Terraform-owned EKS Pod Identity. Its policy is limited to the required catalog
object operations and SNS publication. It does not read Terraform state or AWS
Secrets Manager.

RDS is private and permits PostgreSQL traffic from the EKS node security group
plus the reviewed administrator CIDR. The current worker image uses TLS mode
`require`; moving to `verify-full` requires deliberately packaging or mounting the
AWS RDS CA bundle in a rebuilt image.

## Maintenance endpoint

- `POST /machines/recatalogue` renumbers the existing machine catalog so IDs become sequential starting from `1`
- the recatalogue process updates PostgreSQL first, then regenerates the local
  JSON export and synchronized S3 `instances.json` backup