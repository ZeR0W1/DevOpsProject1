import os


# Container ingress must bind every interface; Kubernetes controls exposure.
API_HOST = os.getenv("API_HOST", "0.0.0.0")  # nosec B104
API_PORT = int(os.getenv("API_PORT", "8000"))
WORKER_HOST = os.getenv("WORKER_HOST")
WORKER_PORT = int(os.getenv("WORKER_PORT", "8000"))

if not WORKER_HOST:
    raise RuntimeError("WORKER_HOST must identify the internal worker service")
