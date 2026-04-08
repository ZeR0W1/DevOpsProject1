import os


API_HOST = os.getenv("API_HOST", "127.0.0.1")
API_PORT = int(os.getenv("API_PORT", "8000"))
WORKER_HOST = os.getenv("WORKER_HOST", "10.0.157.192")
WORKER_PORT = int(os.getenv("WORKER_PORT", "8000"))