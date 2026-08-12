import os
from pathlib import Path


TRUE_VALUES = {"1", "true", "yes", "on"}


def env_flag(name: str, default: bool = False) -> bool:
    """Return a boolean environment value using common truthy spellings."""
    fallback = "true" if default else "false"
    return os.getenv(name, fallback).strip().lower() in TRUE_VALUES


BASE_DIR = Path(__file__).resolve().parent.parent.parent
API_PORT = int(os.getenv("API_PORT", "8000"))
BACKEND_HOST = os.getenv("BACKEND_HOST", "backend")
BACKEND_PORT = int(os.getenv("BACKEND_PORT", "8000"))

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")

S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")
S3_SYNC_ENABLED = env_flag("S3_SYNC_ENABLED", default=True)
S3_INSTANCES_OBJECT_KEY = os.getenv("S3_INSTANCES_OBJECT_KEY", "instances.json")

SNS_NOTIFICATIONS_ENABLED = env_flag("SNS_NOTIFICATIONS_ENABLED", default=True)
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN")

POSTGRES_ENABLED = env_flag("POSTGRES_ENABLED", default=True)
POSTGRES_DSN = os.getenv("POSTGRES_DSN", "")
POSTGRES_HOST = os.getenv("POSTGRES_HOST")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_DB = os.getenv("POSTGRES_DB", "postgres")
POSTGRES_USER = os.getenv("POSTGRES_USER")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")
POSTGRES_TABLE = os.getenv("POSTGRES_TABLE", "machines")
POSTGRES_SSLMODE = os.getenv("POSTGRES_SSLMODE", "require")
POSTGRES_SSLROOTCERT = os.getenv(
    "POSTGRES_SSLROOTCERT",
    str(BASE_DIR / "src" / "worker" / "global-bundle.pem"),
)

if not BACKEND_HOST:
    raise RuntimeError("BACKEND_HOST must be provided by Ansible app_environment")

if S3_SYNC_ENABLED and not S3_BUCKET_NAME:
    raise RuntimeError("S3_BUCKET_NAME must be provided when S3_SYNC_ENABLED=true")

if SNS_NOTIFICATIONS_ENABLED and not SNS_TOPIC_ARN:
    raise RuntimeError("SNS_TOPIC_ARN must be provided when SNS_NOTIFICATIONS_ENABLED=true")

postgres_fields_present = all((POSTGRES_HOST, POSTGRES_USER, POSTGRES_PASSWORD))
if POSTGRES_ENABLED and not POSTGRES_DSN and not postgres_fields_present:
    raise RuntimeError(
        "POSTGRES_HOST, POSTGRES_USER, and POSTGRES_PASSWORD are required "
        "when PostgreSQL is enabled without POSTGRES_DSN"
    )