import json
import logging
from config import INSTANCES_FILEPATH, S3_BUCKET_NAME, S3_INSTANCES_OBJECT_KEY, combined_output
from user_input import fill_model

from machine import Machine, MachineInput


logger = logging.getLogger(__name__)


def sync_instances_file_to_s3(filepath=INSTANCES_FILEPATH):
    try:
        import boto3

        s3_client = boto3.client("s3")
        s3_client.upload_file(str(filepath), S3_BUCKET_NAME, S3_INSTANCES_OBJECT_KEY)
        logger.info(
            "Instances file uploaded to s3://%s/%s",
            S3_BUCKET_NAME,
            S3_INSTANCES_OBJECT_KEY,
        )
    except ImportError:
        logger.warning("boto3 is not installed, skipping S3 sync")
    except Exception:
        logger.exception("Failed to sync instances file to S3")


def load_instances(filepath=INSTANCES_FILEPATH):
    try:
        with open(filepath, "r", encoding="utf-8") as file:
            instances = json.load(file)
            if isinstance(instances, list):
                return instances
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    return []


def get_next_machine_id(filepath=INSTANCES_FILEPATH):
    numeric_ids = []

    for instance in load_instances(filepath):
        try:
            numeric_ids.append(int(instance.get("id")))
        except (TypeError, ValueError):
            continue

    return max(numeric_ids, default=0) + 1




def new_vm():
    """Build and validate one VM object from user input."""
    data = fill_model("Machine", MachineInput)
    if data is None:
        combined_output("--END OF USER INPUT--")
        return None

    vm = Machine.from_input_data(data, get_next_machine_id())
    vm.output_on_init()

    return vm


def append_vm_to_instances_file(vm: Machine, filepath=INSTANCES_FILEPATH):
    instances = load_instances(filepath)
    instances.append(vm.to_dict())

    filepath.parent.mkdir(parents=True, exist_ok=True)

    with open(filepath, "w", encoding="utf-8") as file:
        json.dump(instances, file, indent=2)

    logger.info("Machine saved to %s: %s", filepath, vm.name)
    sync_instances_file_to_s3(filepath)


def get_user_input():
    """Continuously collect VMs until the user ends input."""
    logger.info("Start of user input")

    while True:
        vm = new_vm()
        if vm is None:
            logger.info("Provisioning finished")
            return

        append_vm_to_instances_file(vm)
        print("VM saved successfully")


if __name__ == "__main__":
    get_user_input()
