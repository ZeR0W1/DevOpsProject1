# Backend service

Project overview: [../../../README.md](../../../README.md) · Helm chart:
[../../../helm/backend](../../../helm/backend)

## Functional intent

The backend is the validation and orchestration layer.

- accepts machine requests from the frontend
- validates request payloads
- assigns machine IDs
- forwards verified machines to the worker
- exposes read and health endpoints

## Structure

```text
src/backend/
  api.py
  config.py
  machine.py
  schema.py
  README.md
```

## Local run

From `app/src/backend`, create an isolated environment and install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

The backend requires a reachable worker endpoint:

```bash
export WORKER_HOST=localhost
export WORKER_PORT=8000
python ./api.py
```

## Container and EKS deployment

`Dockerfile.backend` runs Uvicorn on immutable container endpoint
`0.0.0.0:8000`. The `helm/backend` Service is internal `ClusterIP` port `8000`
and the frontend nginx proxy reaches it through Kubernetes Service DNS name
`backend`.

The only non-secret backend runtime settings are the internal worker endpoint:

- `workerService.host` defaults to Kubernetes Service `worker`;
- `workerService.port` defaults to `8000`; and
- the Deployment maps those values to `WORKER_HOST` and `WORKER_PORT`.

The chart intentionally does not expose `API_HOST` or `API_PORT`: the image
command owns the fixed container bind contract, and the Service and probes remain
aligned to port `8000`. The backend has no AWS credentials and no direct RDS, S3,
or SNS access; those integrations belong to the internal worker.

## Maintenance endpoint

- `POST /machines/recatalogue` is exposed through the backend and forwarded to the worker
- use it when you need to renumber the existing machine catalog so IDs start from `1`