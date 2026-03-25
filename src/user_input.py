import logging
from enum import Enum
from typing import Annotated, cast, get_args, get_origin

from pydantic import BaseModel, ValidationError, Field, TypeAdapter, fields


logger = logging.getLogger(__name__)


def validate_field(model_cls: type[BaseModel], field_name: str, raw_value):
    """Validate a single field in a model"""
    field = model_cls.model_fields[field_name]
    field_definition = field.asdict()

    annotated_type = Annotated[
        field_definition["annotation"],
        *field_definition["metadata"],
        Field(**field_definition["attributes"]),
    ]

    adapter = TypeAdapter(annotated_type)
    return adapter.validate_python(raw_value)


def get_list_item_model(field_annotation):
    """Given the annotation of a field in a model, if it's a list then return the type of model stored by the list"""
    origin = get_origin(field_annotation)
    if origin is not list:
        return None

    item_types = get_args(field_annotation)
    if len(item_types) != 1:
        return None

    item_model = item_types[0]
    if isinstance(item_model, type) and issubclass(item_model, BaseModel):
        return item_model

    return None


def is_numeric_field(field_info):
    schema_extra = field_info.json_schema_extra or {}
    if "is_numeric" in schema_extra:
        return schema_extra["is_numeric"]

    return field_info.annotation in (int, float)


def get_item_prompt_name(field_name: str) -> str:
    return field_name[:-1] if field_name.endswith("s") else f"{field_name} item"


def fill_model(model_name: str, model: type[BaseModel]):
    """Prompt the user for input of all the fields in a Pydantic model that have a description"""
    data = {}
    logger.debug(model_name + " nested")

    for field_name, field_info in model.model_fields.items():
        if field_info.description is None:
            continue

        data[field_name] = get_field_input(field_name, field_info, model)
        if model_name == "Machine" and data[field_name] == "done": # end user input if "done" is entered into the machine name
            return None

    return data


def get_model_list_input(field_name: str, list_item_model: type[BaseModel]):
    items = []
    index = 1

    while True:
        items.append(fill_model(f"{field_name}[{index}]", list_item_model))
        add_another = input(f"Add another {field_name[:-1]}? [y/N]: ").strip().lower()
        if add_another not in ("y", "yes"):
            break
        index += 1

    return items


def get_list_input(field_name: str, annotation):
    list_item_model = get_list_item_model(annotation)

    if list_item_model is not None:
        return get_model_list_input(field_name, list_item_model)

    items = []
    item_name = get_item_prompt_name(field_name)

    while True:
        raw = input(f"Enter {item_name} (leave blank to finish): ").strip()
        if raw == "":
            break
        items.append(raw)

    return items


def get_dict_input(field_name: str):
    data = {}

    while True:
        key = input(f"Enter {field_name} key (leave blank to finish): ").strip()
        if key == "":
            break

        value = input(f"Enter value for {key}: ").strip()
        data[key] = value

    return data


def get_scalar_input(field_name, field_info: fields.FieldInfo, parent_model: type[BaseModel]):
    """Take and validate user input for a single item"""
    prompt = str(field_info.description) + ": "
    is_enum = isinstance(field_info.annotation, type) and issubclass(field_info.annotation, Enum)

    while True:
        if is_enum:
            enum_type = cast(type[Enum], field_info.annotation)
            print("Choose " + prompt)
            for option in enum_type:
                print(str(option.value) + " - " + option.name)
            raw = input().lower()
        else:
            raw = input("Enter " + prompt)

        if is_numeric_field(field_info):
            raw = raw.strip()

        try:
            value = validate_field(parent_model, field_name, raw)
            print("ok")
            return value
        except ValidationError as e:
            print(e.errors()[0]["msg"])


def get_field_input(field_name: str, field_info: fields.FieldInfo, parent_model: type[BaseModel]):
    """Determine a field's type and take user input accordingly"""
    annotation = field_info.annotation
    origin = get_origin(annotation)

    if isinstance(annotation, type) and issubclass(annotation, BaseModel):
        return fill_model(field_name, annotation)

    if origin is list:
        return get_list_input(field_name, annotation)

    if origin is dict:
        return get_dict_input(field_name)

    return get_scalar_input(field_name, field_info, parent_model)