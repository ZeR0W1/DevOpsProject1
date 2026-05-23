from enum import Enum, IntEnum
from typing import Annotated, Optional

from pydantic import BaseModel, Field, IPvAnyAddress, StringConstraints


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


class OSName(IntEnum):
    ubuntu = 1
    centos = 2


class CPUConfig(BaseModel):
    cores: int = Field(gt=0)
    threads_per_core: int = Field(gt=0)
    architecture: CPUArchitecture


class OSConfig(BaseModel):
    name: OSName
    version: str


class DiskConfig(BaseModel):
    name: str
    size_gb: float = Field(gt=0)
    type: DiskType
    boot: bool = False


MacAddress = Annotated[
    str,
    StringConstraints(pattern=r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"),
]


class NetworkInterface(BaseModel):
    name: str
    private_ip: IPvAnyAddress
    mac_address: Optional[MacAddress] = None
    public_ip: Optional[IPvAnyAddress] = None