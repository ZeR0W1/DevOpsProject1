from typing import Dict, List

from pydantic import BaseModel, Field

from schema import CPUConfig, DiskConfig, NetworkInterface, OSConfig, VMStatus


class MachineInput(BaseModel):
    name: str = Field(min_length=1)
    cpu: CPUConfig
    memory_gb: int = Field(gt=0)
    os: OSConfig
    disks: List[DiskConfig]
    network_interfaces: List[NetworkInterface]
    tags: Dict[str, str] = Field(default_factory=dict)


class Machine(MachineInput):
    id: int
    status: VMStatus = VMStatus.stopped
    metadata: Dict[str, str] = Field(default_factory=dict)

    @classmethod
    def from_input_data(cls, data: dict, machine_id: int):
        payload = dict(data)
        payload["id"] = machine_id
        return cls.model_validate(payload)