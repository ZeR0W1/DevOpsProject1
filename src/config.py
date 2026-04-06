import logging
import os
import sys
from pathlib import Path



logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parent.parent
LOG_FILE = BASE_DIR / "logs" / "provisioning.log"
SETUP_SCRIPT = BASE_DIR / "scripts" / "inst_service.sh"
INSTANCES_FILEPATH = BASE_DIR / "configs" / "instances.json"
API_HOST = os.getenv("API_HOST", "127.0.0.1")
API_PORT = int(os.getenv("API_PORT", "8000"))
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME", "quick-demo-058264247987-us-east-1-an")
S3_INSTANCES_OBJECT_KEY = os.getenv("S3_INSTANCES_OBJECT_KEY", "instances.json")
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