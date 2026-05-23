import json
import logging
from config import INSTANCES_FILEPATH, combined_output
from user_input import fill_model

from machine import Machine


logger = logging.getLogger(__name__)


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
    data = fill_model("Machine", Machine)
    if data is None:
        combined_output("--END OF USER INPUT--")
        return None

    data["id"] = get_next_machine_id()
    vm = Machine.model_validate(data)
    vm.output_on_init()

    return vm


def append_vm_to_instances_file(vm: Machine, filepath=INSTANCES_FILEPATH):
    instances = load_instances(filepath)
    instances.append(vm.to_dict())

    filepath.parent.mkdir(parents=True, exist_ok=True)

    with open(filepath, "w", encoding="utf-8") as file:
        json.dump(instances, file, indent=2)

    logger.info("Machine saved to %s: %s", filepath, vm.name)


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
