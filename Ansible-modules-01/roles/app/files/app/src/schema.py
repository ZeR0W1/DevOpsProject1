import json
from enum import Enum, IntEnum
from typing import Annotated, Optional

from pydantic import BaseModel, Field, IPvAnyAddress, StringConstraints, ValidationError


# -------------------------
# Enums
# -------------------------

class VMStatus(str, Enum):
    running = "running"
    stopped = "stopped"
    suspended = "suspended"
    terminated = "terminated"


class CPUArchitecture(IntEnum):
    x86_64 = 1
    arm64 = 2


class DiskType(IntEnum):
    ssd = 1
    hdd = 2
    nvme = 3


class OSType(IntEnum):
    linux = 1
    windows = 2
    bsd = 3

class OSName(IntEnum):
    ubuntu = 1
    centos = 2


# -------------------------
# Nested Models
# -------------------------

class CPUConfig(BaseModel):
    cores: int = Field(gt=0, description="number of cores", json_schema_extra={"is_numeric": True})
    threads_per_core: int = Field(gt=0, description="number of threads per core", json_schema_extra={"is_numeric": True})
    architecture: CPUArchitecture = Field(description="CPU architecture", json_schema_extra={"is_numeric": False})


class OSConfig(BaseModel):
    name: OSName = Field(description="OS", json_schema_extra={"is_numeric": False})
    version: str = Field(description="version", json_schema_extra={"is_numeric": False})
    distribution: OSType = Field(default=OSType.linux, json_schema_extra={"is_numeric": False})


class DiskConfig(BaseModel):
    name: str = Field(description="disk name", json_schema_extra={"is_numeric": False})
    size_gb: float = Field(gt=0, description="size(in GB)", json_schema_extra={"is_numeric": True})
    type: DiskType = Field(description="disk type", json_schema_extra={"is_numeric": False})
    boot: bool = Field(default=False, json_schema_extra={"is_numeric": False})

MacAddress = Annotated[
    str,
    StringConstraints(pattern=r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")
]

class NetworkInterface(BaseModel):
    name: str = Field(description="network interface name", json_schema_extra={"is_numeric": False})
    private_ip: IPvAnyAddress = Field(description="private ip", json_schema_extra={"is_numeric": False})
    mac_address: Optional[MacAddress] = Field(default=None, description="mac address", json_schema_extra={"is_numeric": False})
    public_ip: Optional[IPvAnyAddress] = Field(default=None, description="public ip", json_schema_extra={"is_numeric": False})


# -------------------------
# Validation Logic
# -------------------------

def validate_json_file(filepath: str):
    from machine import Machine

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
        for machine in data:
            vm = Machine.model_validate(machine)
            print("JSON is valid!")
            print("\nParsed VM object:")
            print(vm.model_dump_json(indent=2))

        print("JSON file validation successful")

    except ValidationError as e:
        print("Validation failed!")
        print(e.json(indent=2))

    except FileNotFoundError:
        print(f"File not found: {filepath}")

    except json.JSONDecodeError as e:
        print("Invalid JSON format!")
        print(str(e))


if __name__ == "__main__":
    validate_json_file("configs/ex2.json")