import json
from typing import List, Optional, Dict, Annotated
from enum import Enum
from pydantic import BaseModel, Field, IPvAnyAddress, ValidationError, StringConstraints


# -------------------------
# Enums
# -------------------------

class VMStatus(str, Enum):
    running = "running"
    stopped = "stopped"
    suspended = "suspended"
    terminated = "terminated"


class CPUArchitecture(str, Enum):
    x86_64 = "1"
    arm64 = "2"


class DiskType(str, Enum):
    ssd = "ssd"
    hdd = "hdd"
    nvme = "nvme"


class OSType(str, Enum):
    linux = "linux"
    windows = "windows"
    bsd = "bsd"

class OSName(str, Enum):
    ubuntu = "ubuntu"
    centos = "centos"


# -------------------------
# Nested Models
# -------------------------

class CPUConfig(BaseModel):
    cores: int = Field(gt=0, description="number of cores")
    threads_per_core: int = Field(gt=0, description="number of threads per core", json_schema_extra={"is_numeric" : True})
    architecture: CPUArchitecture = Field(description="CPU architecture", json_schema_extra={"is_numeric" : False})


class OSConfig(BaseModel):
    name: OSName = Field(description="OS", json_schema_extra={"is_numeric" : False})
    version: Optional[str] = Field(description="version", json_schema_extra={"is_numeric" : False})
    distribution: OSType = "linux"


class DiskConfig(BaseModel):
    name: str = Field(description="disk name", json_schema_extra={"is_numeric" : False})
    size_gb: float = Field(gt=0, description="size(in GB)", json_schema_extra={"is_numeric" : True})
    type: DiskType = Field(description="disk type", json_schema_extra={"is_numeric" : False})
    boot: bool = False

MacAddress = Annotated[
    str,
    StringConstraints(pattern=r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")
]

class NetworkInterface(BaseModel):
    name: str = Field(description="network interface name", json_schema_extra={"is_numeric" : False})
    mac_address: MacAddress = Field(description="mac address", json_schema_extra={"is_numeric" : False})
    private_ip: IPvAnyAddress = Field(description="private ip", json_schema_extra={"is_numeric" : False})
    public_ip: Optional[IPvAnyAddress] = None


# -------------------------
# Main VM Model
# -------------------------

class VirtualMachine(BaseModel):

    #TODO: add metadata to all user inputted fields that stores an is_numeric bool to check user input before validation

    id: str
    name: str = Field(description="machine name", json_schema_extra={"is_numeric" : False})
    status: VMStatus
    cpu: CPUConfig = Field(description="CPU config parameters")
    memory_gb: int = Field(description="RAM(in GB, numeric only)", gt=0, json_schema_extra={"is_numeric" : True})
    os: OSConfig = Field(description="OS details")
    disks: DiskConfig = Field(description="disk details")
    network_interfaces: NetworkInterface
    tags: List[str] = []
    metadata: Dict[str, str] = {}


# -------------------------
# Validation Logic
# -------------------------

def validate_json_file(filepath: str):
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)

        vm = VirtualMachine.model_validate(data)

        print("JSON is valid!")
        print("\nParsed VM object:")
        print(vm.model_dump_json(indent=2))

    except ValidationError as e:
        print("Validation failed!")
        print(e.json(indent=2))

    except FileNotFoundError:
        print(f"File not found: {filepath}")

    except json.JSONDecodeError as e:
        print("Invalid JSON format!")
        print(str(e))


if __name__ == "__main__":
    validate_json_file("infra-automation/configs/ex2.json")