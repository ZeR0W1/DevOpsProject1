import json
from enum import Enum
from typing import Annotated
from pydantic import BaseModel, IPvAnyAddress, ValidationError, create_model, Field, fields, TypeAdapter
import scheme
from ipaddress import IPv4Address


def validate_one_field(model_cls: type[BaseModel], field_name: str, raw_value):
    field = model_cls.model_fields[field_name]
    d = field.asdict()

    annotated_type = Annotated[
        d["annotation"],
        *d["metadata"],
        Field(**d["attributes"]),
    ]

    adapter = TypeAdapter(annotated_type)
    return adapter.validate_python(raw_value)


# prompt users for input only on fields that have a prompt written
def fill_model(model_name: str, model: type[BaseModel]):
    data = {}
    print(model_name + " nested") #debug

    for field_name, field_info in model.model_fields.items():
        if field_info.description == None:
                continue
        data[field_name] = get_field_input(field_name, field_info, model)
        if model_name == "VirtualMachine" and data[field_name] == "done":
                return None
                
    return data


def get_field_input(field_name, field_info, parent_model):

    if isinstance(field_info.annotation, type) and issubclass(field_info.annotation, BaseModel):
            data = fill_model(field_name, field_info.annotation) #return None instead of "done" so next 3 lines can be re[laced by direct return OR use try catch to terminate input
            return data
    
    print(field_name + " simple") #debug
    prompt = str(field_info.description) + ": "

    while True:
        if isinstance(field_info.annotation, type) and issubclass(field_info.annotation, Enum): # TODO: put this in a separate function for handling enums?
            print("Choose " + prompt)
            for option in field_info.annotation:
                print(str(option.value) + " - " + option.name)
            raw = input().lower()
            
        else:
            raw = input("Enter " + prompt)
        try:
            value = validate_one_field(parent_model, field_name, raw)
            print("ok")
            break
        except ValidationError as e:
            print(e.errors()[0]["msg"])

    return value


def new_vm():

     data = fill_model("VirtualMachine", scheme.VirtualMachine)
     print(data)
     if data == None:
        #   print("--End of input--")
          return
     return scheme.VirtualMachine.model_validate(data)


if __name__ == "__main__":
    #  for m in scheme.CPUConfig.model_fields["architecture"].annotation:
    #        print("[" + m.value + "]  " + m.name)
    vm = new_vm()
    print("--End of input--")
    if vm is not None:
        with open("configs/vm.json", "w") as file:
            file.write(vm.model_dump_json(indent=2))
        scheme.validate_json_file("configs/vm.json")
         