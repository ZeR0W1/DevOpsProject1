import logging
import os
import sys
from pathlib import Path



logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parent.parent.parent
LOG_FILE = BASE_DIR / "logs" / "provisioning.log"
SETUP_SCRIPT = BASE_DIR / "scripts" / "inst_service.sh"
INSTANCES_FILEPATH = BASE_DIR / "configs" / "instances.json"
API_HOST = os.getenv("API_HOST", "127.0.0.1")
API_PORT = int(os.getenv("API_PORT", "8000"))
BACKEND_HOST = os.getenv("BACKEND_HOST", "10.0.149.9")
BACKEND_PORT = int(os.getenv("BACKEND_PORT", "8000"))
WORKER_HOST = os.getenv("WORKER_HOST", "10.0.157.192")
WORKER_PORT = int(os.getenv("WORKER_PORT", "8000"))
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME", "quick-demo-058264247987-us-east-1-an")
S3_INSTANCES_OBJECT_KEY = os.getenv("S3_INSTANCES_OBJECT_KEY", "instances.json")
SNS_NOTIFICATIONS_ENABLED = os.getenv("SNS_NOTIFICATIONS_ENABLED", "true").strip().lower() in {"1", "true", "yes", "on"}
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN", "")
POSTGRES_ENABLED = os.getenv("POSTGRES_ENABLED", "true").strip().lower() in {"1", "true", "yes", "on"}
POSTGRES_DSN = os.getenv("POSTGRES_DSN", "")
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "127.0.0.1")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_DB = os.getenv("POSTGRES_DB", "postgres")
POSTGRES_USER = os.getenv("POSTGRES_USER", "postgres_master")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgres")
POSTGRES_TABLE = os.getenv("POSTGRES_TABLE", "machines")
POSTGRES_SSLMODE = os.getenv("POSTGRES_SSLMODE", "verify-full")
POSTGRES_SSLROOTCERT = os.getenv("POSTGRES_SSLROOTCERT", str(BASE_DIR / "global-bundle.pem"))
MIN_PYTHON_VERSION = (3, 11)


def combined_output(message: str) -> None:
    print(message)
    logger.info(message)


def ensure_supported_python() -> None:
    if sys.version_info < MIN_PYTHON_VERSION:
        required = ".".join(str(part) for part in MIN_PYTHON_VERSION)
        current = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
        raise RuntimeError(
            f"Python {required}+ is required for this project. Current version: {current}"
        )