import json
from typing import List, Optional, Dict, Annotated
from enum import Enum
from pydantic import BaseModel, Field, IPvAnyAddress, ValidationError, StringConstraints, create_model, fields
import scheme
from dotty_dict import Dotty
from ipaddress import IPv4Address


# TODO: remove unnecessary imports
# TODO: readability

def validate_one_field(model_cls: type[BaseModel], field_name: str, raw_value):
    field = model_cls.model_fields[field_name]

    TempModel = create_model(
        "TempModel"
        **{field_name: (field.annotation, field)}
    )

    obj = TempModel.model_validate({field_name: raw_value})
    return getattr(obj, field_name)



def fill_model(model_name: str, annotation: type[BaseModel]):
    data = {}
    print(model_name + " nested")
    for subfield in annotation.model_fields.items():
                if subfield[1].description is None:
                     continue
                data[subfield[0]] = get_field_input(subfield, annotation)
                if model_name is "VirtualMachine" and data[subfield[0]] is "done":
                     return "done"
    return data


def get_field_input(field: tuple[str, fields.FieldInfo], parent_model):

    if isinstance(field[1].annotation, type) and issubclass(field[1].annotation, BaseModel):
            data = fill_model(field[0], field[1].annotation) #return None instead of "done" so next 3 lines can be re[laced by direct return OR use try catch to terminate input
            if data is "done":
                 return None
            return data
    
    print(field[0] + " simple")
    while True:
        if isinstance(field[1].annotation, Enum):
            print("Enter " + field[1].description + ":")
            for option in field[1].annotation:
                print(option.value + " - " + option.name)
            raw = input()
        else:
            raw = input("Enter " + field[1].description + ": ")
        try:
            value = validate_one_field(parent_model, field[0], raw)
            print("ok")
            break
        except ValidationError as e:
            print(e.errors()[0]["msg"])
    return value


def get_user_input():

     data = {}

     data = fill_model("VirtualMachine", scheme.VirtualMachine)

     return data


if __name__ == "__main__":
    #  for m in scheme.CPUConfig.model_fields["architecture"].annotation:
    #        print("[" + m.value + "]  " + m.name)
    vm = get_user_input()