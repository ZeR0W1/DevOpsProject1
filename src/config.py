import logging
import os
from pathlib import Path



logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parent.parent
LOG_FILE = BASE_DIR / "logs" / "provisioning.log"
SETUP_SCRIPT = BASE_DIR / "scripts" / "inst_service.sh"
INSTANCES_FILEPATH = BASE_DIR / "configs" / "instances.json"
API_HOST = os.getenv("API_HOST", "127.0.0.1")
API_PORT = int(os.getenv("API_PORT", "8000"))


def combined_output(message: str) -> None:
    print(message)
    logger.info(message)