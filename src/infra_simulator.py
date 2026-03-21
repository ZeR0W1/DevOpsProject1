import logging

from provisioning import get_user_input


def configure_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )


def main():
    configure_logging()
    get_user_input()


if __name__ == "__main__":
    main()