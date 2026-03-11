import json
from enum import Enum
from pydantic import BaseModel, IPvAnyAddress, ValidationError, create_model, fields
import scheme
from ipaddress import IPv4Address


def validate_one_field(model_cls: type[BaseModel], field_name: str, raw_value):
    field = model_cls.model_fields[field_name]

    TempModel = create_model(
        "TempModel",
        **{field_name: (field.annotation, field)}
    )

    obj = TempModel.model_validate({field_name: raw_value})
    return getattr(obj, field_name)


# prompt users for input only on fields that have a prompt written
def fill_model(model_name: str, model: type[BaseModel]):
    data = {}
    print(model_name + " nested") #debug

    for field in model.model_fields.items():
                if field[1].description == None:
                     continue
                data[field[0]] = get_field_input(field, model)
                if model_name == "VirtualMachine" and data[field[0]] == "done":
                     return "done"
                
    return data


def get_field_input(field: tuple[str, fields.FieldInfo], parent_model):

    if isinstance(field[1].annotation, type) and issubclass(field[1].annotation, BaseModel):
            data = fill_model(field[0], field[1].annotation) #return None instead of "done" so next 3 lines can be re[laced by direct return OR use try catch to terminate input
            if data == "done":
                 return None
            
            return data
    
    print(field[0] + " simple") #debug

    while True:
        if isinstance(field[1].annotation, type) and issubclass(field[1].annotation, Enum): # TODO: put this in a separate function for handling enums?
            print("Choose " + field[1].description + ":")
            for option in field[1].annotation:
                print(str(option.value) + " - " + option.name)
            raw = input().lower()
            
        else:
            raw = input("Enter " + field[1].description + ": ")
        try:
            value = validate_one_field(parent_model, field[0], raw)
            print("ok")
            break
        except ValidationError as e:
            print(e.errors()[0]["msg"])

    return value


def new_vm():

     data = fill_model("VirtualMachine", scheme.VirtualMachine)

     return scheme.VirtualMachine.model_validate(data)


if __name__ == "__main__":
    #  for m in scheme.CPUConfig.model_fields["architecture"].annotation:
    #        print("[" + m.value + "]  " + m.name)
    vm = new_vm()
    with open("configs/vm.json", "w") as file:
         file.write(vm.model_dump_json(indent=2))
    scheme.validate_json_file("configs/vm.json")
         