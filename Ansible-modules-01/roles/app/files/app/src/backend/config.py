import os


API_HOST = os.getenv("API_HOST", "127.0.0.1")
API_PORT = int(os.getenv("API_PORT", "8000"))
WORKER_HOST = os.getenv("WORKER_HOST")
WORKER_PORT = int(os.getenv("WORKER_PORT", "8000"))

if not WORKER_HOST:
    raise RuntimeError("WORKER_HOST must be provided by Ansible app_environment")