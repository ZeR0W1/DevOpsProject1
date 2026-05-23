import logging
import subprocess

from config import LOG_FILE, SETUP_SCRIPT, combined_output
from provisioning import get_user_input


logger = logging.getLogger(__name__)


def configure_logging():
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    file_handler = logging.FileHandler(LOG_FILE, encoding="utf-8")
    stream_handler = logging.StreamHandler()
    stream_handler.setLevel(logging.WARNING)

    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s - [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=[
            file_handler,
            stream_handler,
        ],
    )


def main():
    configure_logging()
    print("Welcome!")
    logger.info("Provisioning started")

    try:
        get_user_input()
        logger.info("Provisioning finished successfully")
    except Exception:
        logger.exception("Provisioning failed")
        raise
    run_setup_script()
    
    logger.info("Exiting")

def run_setup_script():
    run_install = input("Run service installation script? (y/N)").strip().lower()
    if run_install not in ("y", "yes"):
        combined_output("Installation canceled by user")
        return

    try:
        combined_output(f"Starting service installation script: {SETUP_SCRIPT}")
        subprocess.run(["bash", str(SETUP_SCRIPT)], check=True)
        logger.info("Script finished")
    except FileNotFoundError:
        logger.exception("Bash executable or script was not found")
        raise
    except subprocess.CalledProcessError:
        logger.exception("Service installation script failed")
        raise



if __name__ == "__main__":
    main()