import json
from enum import Enum
from typing import Annotated, get_args, get_origin

from pydantic import BaseModel, ValidationError, Field, TypeAdapter

from machine import Machine
import scheme


def validate_one_field(model_cls: type[BaseModel], field_name: str, raw_value):
    """Validate one field value using the field's full Pydantic metadata."""
    field = model_cls.model_fields[field_name]
    field_definition = field.asdict()

    annotated_type = Annotated[
        field_definition["annotation"],
        *field_definition["metadata"],
        Field(**field_definition["attributes"]),
    ]

    adapter = TypeAdapter(annotated_type)
    return adapter.validate_python(raw_value)


def get_list_item_model(annotation):
    """Return the nested model type when the annotation is List[BaseModel]."""
    origin = get_origin(annotation)
    if origin is not list:
        return None

    item_types = get_args(annotation)
    if len(item_types) != 1:
        return None

    item_model = item_types[0]
    if isinstance(item_model, type) and issubclass(item_model, BaseModel):
        return item_model

    return None


def is_numeric_field(field_info):
    """Check whether a field should be treated as numeric during input."""
    schema_extra = field_info.json_schema_extra or {}
    if "is_numeric" in schema_extra:
        return schema_extra["is_numeric"]

    return field_info.annotation in (int, float)


def fill_model(model_name: str, model: type[BaseModel]):
    """Prompt the user for all described fields in a Pydantic model."""
    data = {}
    #print(model_name + " nested")

    for field_name, field_info in model.model_fields.items():
        if field_info.description is None:
            continue

        data[field_name] = get_field_input(field_name, field_info, model)
        if model_name == "VirtualMachine" and data[field_name] == "done":
            return None

    return data


def get_field_input(field_name, field_info, parent_model):
    """Collect and validate user input for one field."""
    list_item_model = get_list_item_model(field_info.annotation)

    if list_item_model is not None:
        items = []
        index = 1

        while True:
            items.append(fill_model(f"{field_name}[{index}]", list_item_model))
            add_another = input(f"Add another {field_name[:-1]}? [y/N]: ").strip().lower()
            if add_another not in ("y", "yes"):
                break
            index += 1

        return items

    if isinstance(field_info.annotation, type) and issubclass(field_info.annotation, BaseModel):
        return fill_model(field_name, field_info.annotation)

    #print(field_name + " simple")
    prompt = str(field_info.description) + ": "

    while True:
        if isinstance(field_info.annotation, type) and issubclass(field_info.annotation, Enum):
            print("Choose " + prompt)
            for option in field_info.annotation:
                print(str(option.value) + " - " + option.name)
            raw = input().lower()
        else:
            raw = input("Enter " + prompt)

        if is_numeric_field(field_info):
            raw = raw.strip()

        try:
            value = validate_one_field(parent_model, field_name, raw)
            print("ok")
            break
        except ValidationError as e:
            print(e.errors()[0]["msg"])

    return value


def new_vm():
    """Build and validate one VM object from interactive input."""
    data = fill_model("Machine", Machine)
    print(data)
    if data is None:
        return None

    return Machine.model_validate(data)


def append_vm_to_instances_file(vm: Machine, filepath: str = "configs/instances.json"):
    """Append a VM to the instances collection stored on disk."""
    try:
        with open(filepath, "r", encoding="utf-8") as file:
            instances = json.load(file)
            if not isinstance(instances, list):
                instances = []
    except (FileNotFoundError, json.JSONDecodeError):
        instances = []

    instances.append(vm.to_dict())

    with open(filepath, "w", encoding="utf-8") as file:
        json.dump(instances, file, indent=2)


def get_user_input():
    """Continuously collect VMs until the user ends input."""
    while True:
        vm = new_vm()
        if vm is None:
            print("--End of input--")
            return

        append_vm_to_instances_file(vm)
        print("VM added successfully")


if __name__ == "__main__":
    get_user_input()
