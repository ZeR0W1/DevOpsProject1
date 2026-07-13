import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent.parent
API_PORT = int(os.getenv("API_PORT", "8000"))
BACKEND_HOST = os.getenv("BACKEND_HOST", "backend")
BACKEND_PORT = int(os.getenv("BACKEND_PORT", "8000"))
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")
S3_INSTANCES_OBJECT_KEY = os.getenv("S3_INSTANCES_OBJECT_KEY", "instances.json")
SNS_NOTIFICATIONS_ENABLED = os.getenv("SNS_NOTIFICATIONS_ENABLED", "true").strip().lower() in {"1", "true", "yes", "on"}
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN")
POSTGRES_ENABLED = os.getenv("POSTGRES_ENABLED", "true").strip().lower() in {"1", "true", "yes", "on"}
POSTGRES_DSN = os.getenv("POSTGRES_DSN", "")
POSTGRES_HOST = os.getenv("POSTGRES_HOST")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_DB = os.getenv("POSTGRES_DB", "postgres")
POSTGRES_USER = os.getenv("POSTGRES_USER")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")
POSTGRES_PASSWORD_SECRET_NAME = os.getenv("POSTGRES_PASSWORD_SECRET_NAME")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
POSTGRES_TABLE = os.getenv("POSTGRES_TABLE", "machines")
POSTGRES_SSLMODE = os.getenv("POSTGRES_SSLMODE", "verify-full")
POSTGRES_SSLROOTCERT = os.getenv("POSTGRES_SSLROOTCERT", str(BASE_DIR / "src" / "worker" / "global-bundle.pem"))

if not BACKEND_HOST:
    raise RuntimeError("BACKEND_HOST must be provided by Ansible app_environment")

if not S3_BUCKET_NAME:
    raise RuntimeError("S3_BUCKET_NAME must be provided by Ansible app_environment")

if SNS_NOTIFICATIONS_ENABLED and not SNS_TOPIC_ARN:
    raise RuntimeError("SNS_TOPIC_ARN must be provided when SNS_NOTIFICATIONS_ENABLED=true")

if POSTGRES_ENABLED and not POSTGRES_DSN and not all([POSTGRES_HOST, POSTGRES_USER, POSTGRES_PASSWORD]):
    raise RuntimeError(
        "POSTGRES_HOST/POSTGRES_USER/POSTGRES_PASSWORD must be provided when POSTGRES is enabled (or set POSTGRES_DSN)"
    )