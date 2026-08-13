# Frontend service

Project overview: [../../../README.md](../../../README.md) · Helm chart:
[../../../helm/frontend](../../../helm/frontend)

## Functional intent

The frontend is the public browser entry point for the Kubernetes application.

- serves the static user interface through nginx;
- exposes only the frontend externally;
- proxies API requests to the internal backend Service.

## Structure

```text
src/frontend/
  index.html
  nginx/
    default.conf.template
  README.md
```

## Container and Kubernetes deployment

`Dockerfile.frontend` copies `src/frontend/index.html` into the nginx image as a
safe image default and uses `src/frontend/nginx/default.conf.template` for runtime
service discovery. CI validates this repository default and seeds the private,
versioned application S3 object `index.html` only when it is missing, unless an
operator explicitly requests a reset.

At runtime, standalone CD downloads the S3 object and owns Kubernetes ConfigMap
`frontend-runtime-content`. The production `helm/frontend` chart only references
that external ConfigMap and mounts it read-only at `/usr/share/nginx/html` in the
frontend Deployment. A `CONTENT_ONLY` CD run changes no image or Helm release: it
updates the ConfigMap, verifies the SHA-256, and rolls only frontend replicas.
Backend and worker never mount this content.

`scripts/manage_frontend_content.sh` implements the one-file validation and
synchronization mechanics used by CI/CD.

Because the frontend is static and nginx-based, it has no Python dependency file.

The `helm/frontend` `LoadBalancer` Service is the only public application entry
point. Backend, worker, Jenkins, RDS, S3, and SNS remain non-public. Derive the
current load-balancer hostname from Kubernetes status; do not hard-code an
ephemeral hostname or restore the retired EC2/systemd deployment path.