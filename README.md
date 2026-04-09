
## Overview

This repository is organized around three AWS-hosted services:

- **Frontend**: public nginx entry point
- **Backend**: validation and orchestration API
- **Worker**: persistence, S3 sync, and SNS notification service

The intended layout is under `src/`.

## Service documentation

- Frontend: `src/frontend/README.md`
- Backend: `src/backend/README.md`
- Worker: `src/worker/README.md`

## Project structure

```text
configs/
scripts/
src/
  backend/
  worker/
  frontend/
  legacy/
```

`src/legacy/` keeps the previous single-source/local-testing implementation during the migration to the per-service layout. It is retained for reference and fallback, but the intended active structure is `src/backend/`, `src/worker/`, and `src/frontend/`.

## Architecture diagram

```mermaid
flowchart TD
    Internet((Internet)) --> IGW[Internet Gateway]

    subgraph VPC[ ]
        direction TB
        VPCTitle[VPC:<br/>vpc-0661ad9886c7d135f]
        VPCPadLeft[ ]
        VPCPadRight[ ]

        subgraph Net1[ ]
            direction LR
            Net1Title[Subnet: us-east-1b<br/>10.0.144.0/20 public routing]
            Net1PadLeft[ ]
            Front[Frontend EC2:<br/>role: nginx entrypoint]
            nginx((nginx))
            Back[Backend EC2:<br/>role: validation API]
            Worker[Worker EC2:<br/>role: persistence and integration]
            Net1PadRight[ ]
            Net1PadFarRight[ ]
        end

        subgraph Net2[ ]
            direction LR
            Net2Title[Subnet: us-east-1a<br/>10.0.128.0/20]
            Net2PadLeft[ ]
            RDS[(RDS: PostgreSQL<br/>dodb2)]
            Net2PadRight[ ]
        end

        VPCPadBottom[ ]
    end

    S3[S3:<br/>quick-demo-058264247987-us-east-1-an]
    SNS[SNS:<br/>DOAworker]
    Email[Email]
    SGHttp[SG: http]
    SGBack[SG: backend-api]
    SGWorker[SG: worker-app]
    SGRds[SG: default]

    IGW --> Front
    Front -.runs.- nginx
    nginx -->|proxy| Back
    Back -->|API| Worker
    Worker -->|DB| RDS
    Worker -->|upload| S3
    Worker -->|notify| SNS
    SNS --> Email

    SGHttp -.attached.- Front
    SGBack -.attached.- Back
    SGWorker -.attached.- Worker
    SGRds -.attached.- RDS

    classDef invis fill:none,stroke:none,color:transparent;
    classDef label fill:none,stroke:none,color:#ffffff,font-weight:bold,font-size:20px;
    class VPCPadLeft,VPCPadRight,VPCPadBottom,Net1PadLeft,Net1PadRight,Net1PadFarRight,Net2PadLeft,Net2PadRight invis;
    class VPCTitle,Net1Title,Net2Title label;
    style VPCTitle fill:none,stroke:none,color:#ffffff,font-size:28px,font-weight:bold;
    style Net1Title fill:none,stroke:none,color:#ffffff,font-size:24px,font-weight:bold;
    style Net2Title fill:none,stroke:none,color:#ffffff,font-size:24px,font-weight:bold;
```

## Deployment notes

- Public frontend entry point: `http://44.212.221.75/`
- Frontend nginx config: `src/frontend/nginx.conf`
- Backend validation lives in `src/backend/`
- Worker persistence/integration logic lives in `src/worker/`
- PostgreSQL CA bundle is expected at `src/worker/global-bundle.pem`
- Active EC2 security groups:
  - Front: `http`
  - Back: `backend-api`
  - Worker: `worker-app`
- Active security-group flow:
  - `http` allows inbound `80/tcp` from the internet
  - `backend-api` allows inbound `8000/tcp` from SG `http`
  - `worker-app` allows inbound `8000/tcp` from SG `backend-api`
  - RDS SG `default` allows `5432/tcp` from SG `worker-app` and from the admin IP used for pgAdmin
- RDS remains publicly accessible intentionally so direct pgAdmin access continues to work.

## Local development

```bash
python -m venv venv
source venv/bin/activate  # Linux
# or: venv\Scripts\Activate  # Windows
pip install -r requirements-backend.txt
pip install -r requirements-worker.txt
```


## Manual evidence to capture

- screenshots of running EC2 instances
- screenshots of RDS, S3, SNS, and the nginx-exposed frontend
- notes for any non-minimal IAM or security group rules