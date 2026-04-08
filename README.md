
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
    Internet[Internet] --> IGW[Internet Gateway\nigw-0e11e3dc4d7a73914]

    subgraph VPC[VPC vpc-0661ad9886c7d135f]
        subgraph SubnetB[Subnet linkless-subnet-private2-us-east-1b\nsubnet-02084b58d14d91ea7\n10.0.144.0/20]
            Front[Frontend EC2\nName: Front\nPrivate: 10.0.154.173\nPublic: 44.212.221.75\nIAM: bucket-muncher]
            Back[Backend EC2\nName: Back\nPrivate: 10.0.149.9\nPublic: 54.236.240.185\nIAM: bucket-muncher]
            Worker[Worker EC2\nName: Worker\nPrivate: 10.0.157.192\nPublic: 44.197.188.137\nIAM: bucket-muncher]
        end

        subgraph SubnetA[Subnet linkless-subnet-private1-us-east-1a\nsubnet-009f8ce8c5da4bd1c\n10.0.128.0/20]
            RDS[(RDS PostgreSQL\nIdentifier: dodb2\nEndpoint: dodb2.celu8oms0zc2.us-east-1.rds.amazonaws.com\nPort: 5432\nPublicly accessible: true)]
        end
    end

    S3[S3 Bucket\nquick-demo-058264247987-us-east-1-an]
    SNS[SNS Topic\nDOAworker]

    Internet -->|HTTP/80| Front
    Front -->|nginx proxy -> backend| Back
    Back -->|HTTP/8000| Worker
    Worker -->|PostgreSQL/5432| RDS
    Worker -->|Upload instances.json| S3
    Worker -->|Publish notifications| SNS

    SG1[SG cetem-sg-01\nssh 22 from 109.67.153.215/32\negres all]
    SG2[SG http\nhttp 80 from 0.0.0.0/0\negres all]
    SG3[SG worker-listen\n8000 from 10.0.157.192/32]
    SG4[SG worker-perms\n5432 from 0.0.0.0/0\n8000 from 10.0.149.9/32\negres all]

    SG1 -.attached.- Front
    SG2 -.attached.- Front
    SG1 -.attached.- Back
    SG2 -.attached.- Back
    SG3 -.attached.- Back
    SG1 -.attached.- Worker
    SG4 -.attached.- Worker
```

## Deployment notes

- Public frontend entry point: `http://44.212.221.75/`
- Frontend nginx config: `src/frontend/nginx.conf`
- Backend validation lives in `src/backend/`
- Worker persistence/integration logic lives in `src/worker/`
- PostgreSQL CA bundle is expected at `src/worker/global-bundle.pem`

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