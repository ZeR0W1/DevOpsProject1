import logging
from typing import Dict, List
from config import combined_output
from pydantic import BaseModel, Field
from schema import CPUConfig, DiskConfig, NetworkInterface, OSConfig, VMStatus


logger = logging.getLogger(__name__)


class Machine(BaseModel):

    id: int
    name: str = Field(min_length=1, description="machine name", json_schema_extra={"is_numeric": False})
    status: VMStatus = VMStatus.stopped
    cpu: CPUConfig = Field(description="CPU config parameters")
    memory_gb: int = Field(description="RAM(in GB, numeric only)", gt=0, json_schema_extra={"is_numeric": True})
    os: OSConfig = Field(description="OS details")
    disks: List[DiskConfig] = Field(description="disk details")
    network_interfaces: List[NetworkInterface] = Field(description="network interface details")
    tags: List[str] = Field(default_factory=list, description="tags")
    metadata: Dict[str, str] = Field(default_factory=dict, description="metadata")

    def output_on_init(self):
        combined_output(f"Machine created: {self.name}")

    def to_dict(self) -> Dict:
        return self.model_dump(mode="json")
