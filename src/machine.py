import logging
from typing import Dict, List

from pydantic import BaseModel, Field

from scheme import CPUConfig, DiskConfig, NetworkInterface, OSConfig, VMStatus


logger = logging.getLogger(__name__)


class Machine(BaseModel):
    """Machine domain model with logging and dict conversion support."""

    id: str = "1"
    name: str = Field(description="machine name", json_schema_extra={"is_numeric": False})
    status: VMStatus = VMStatus.stopped
    cpu: CPUConfig = Field(description="CPU config parameters")
    memory_gb: int = Field(description="RAM(in GB, numeric only)", gt=0, json_schema_extra={"is_numeric": True})
    os: OSConfig = Field(description="OS details")
    disks: List[DiskConfig] = Field(description="disk details")
    network_interfaces: List[NetworkInterface] = Field(description="network interface details")
    tags: List[str] = Field(default_factory=list)
    metadata: Dict[str, str] = Field(default_factory=dict)

    def model_post_init(self, __context):
        logger.info("Machine created: %s", self.name)

    def to_dict(self) -> Dict:
        """Return a dictionary representation of the machine."""
        return self.model_dump(mode="json")
