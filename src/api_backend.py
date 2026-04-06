import logging

from fastapi import FastAPI

from config import API_HOST, API_PORT
from machine import Machine, MachineInput
from provisioning import append_vm_to_instances_file, get_next_machine_id, load_instances
from schema import CPUArchitecture, DiskType, OSName, OSType


logger = logging.getLogger(__name__)

app = FastAPI(
    title="Infrastructure Automation Backend API",
    version="1.0.0",
    description="Backend API for creating and listing machine configurations.",
)


def translate_machine_for_display(machine: dict) -> dict:
    translated = dict(machine)

    cpu = dict(translated.get("cpu", {}))
    architecture = cpu.get("architecture")
    if architecture is not None:
        try:
            cpu["architecture"] = CPUArchitecture(architecture).name
        except ValueError:
            pass
    translated["cpu"] = cpu

    os_config = dict(translated.get("os", {}))
    os_name = os_config.get("name")
    os_distribution = os_config.get("distribution")
    if os_name is not None:
        try:
            os_config["name"] = OSName(os_name).name
        except ValueError:
            pass
    if os_distribution is not None:
        try:
            os_config["distribution"] = OSType(os_distribution).name
        except ValueError:
            pass
    translated["os"] = os_config

    disks = []
    for disk in translated.get("disks", []):
        disk_copy = dict(disk)
        disk_type = disk_copy.get("type")
        if disk_type is not None:
            try:
                disk_copy["type"] = DiskType(disk_type).name
            except ValueError:
                pass
        disks.append(disk_copy)
    translated["disks"] = disks

    return translated


@app.get("/health")
def healthcheck():
    return {"status": "ok", "service": "backend-api"}


@app.get("/machines")
def list_machines():
    return [translate_machine_for_display(machine) for machine in load_instances()]


@app.post("/machines", response_model=Machine, status_code=201)
def create_machine(machine_input: MachineInput):
    machine = Machine.from_input_data(
        machine_input.model_dump(mode="json"),
        get_next_machine_id(),
    )
    append_vm_to_instances_file(machine)
    return machine


@app.get("/schema/machine")
def machine_schema():
    return Machine.model_json_schema()


def main():
    import uvicorn

    logger.info("Starting backend API on %s:%s", API_HOST, API_PORT)
    uvicorn.run("api_backend:app", host=API_HOST, port=API_PORT, reload=False)


if __name__ == "__main__":
    main()