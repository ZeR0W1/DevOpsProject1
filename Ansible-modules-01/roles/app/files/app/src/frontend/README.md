# Frontend service

### Functional intent

The frontend is the public browser entry point for the Kubernetes application.

- serves the static user interface through nginx;
- exposes only the frontend externally;
- proxies API requests to the internal backend Service.

### Structure

```text
src/frontend/
  index.html
  nginx/
    default.conf.template
  README.md
```

### Deployment setup

`Dockerfile.frontend` copies `src/frontend/index.html` into the nginx image and
uses `src/frontend/nginx/default.conf.template` for runtime service discovery.
The production Helm chart is `helm/frontend`; its ConfigMap-managed content will
be aligned with this canonical source during the remaining frontend refactor.

Because the frontend is static and nginx-based, it has no Python dependency file.

The final public entry point is still being completed. It must expose only the
frontend and keep backend, worker, RDS, S3, and SNS non-public. Do not restore the
retired EC2/systemd deployment path or hard-code instance IP addresses.