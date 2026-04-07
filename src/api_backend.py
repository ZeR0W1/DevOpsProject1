import logging

from fastapi import FastAPI, HTTPException
import httpx

from config import API_HOST, API_PORT, WORKER_HOST, WORKER_PORT
from machine import Machine, MachineInput
from provisioning import get_next_machine_id
from schema import CPUArchitecture, DiskType, OSName  # , OSType


logger = logging.getLogger(__name__)
WORKER_MACHINES_URL = f"http://{WORKER_HOST}:{WORKER_PORT}/machines"

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
    # os_distribution = os_config.get("distribution")
    if os_name is not None:
        try:
            os_config["name"] = OSName(os_name).name
        except ValueError:
            pass
    # if os_distribution is not None:
    #     try:
    #         os_config["distribution"] = OSType(os_distribution).name
    #     except ValueError:
    #         pass
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


def fetch_worker_machines() -> list[dict]:
    response = httpx.get(WORKER_MACHINES_URL, timeout=10.0)
    response.raise_for_status()
    machines = response.json()
    if not isinstance(machines, list):
        raise ValueError("Worker returned a non-list machines response")
    return machines


def get_next_machine_id_from_worker() -> int:
    numeric_ids = []

    for machine in fetch_worker_machines():
        try:
            machine_id = machine.get("id")
            if machine_id is None:
                continue
            numeric_ids.append(int(machine_id))
        except (TypeError, ValueError):
            continue

    return max(numeric_ids, default=0) + 1


@app.get("/health")
def healthcheck():
    return {"status": "ok", "service": "backend-api"}


@app.get("/machines")
def list_machines():
    try:
        machines = fetch_worker_machines()
        return [translate_machine_for_display(machine) for machine in machines]
    except Exception as exc:
        logger.exception("Failed to fetch machines from worker")
        raise HTTPException(status_code=502, detail=f"Worker machines fetch failed: {exc}")


@app.post("/machines", response_model=Machine, status_code=201)
def create_machine(machine_input: MachineInput):
    machine = Machine.from_input_data(
        machine_input.model_dump(mode="json"),
        get_next_machine_id_from_worker(),
    )

    try:
        response = httpx.post(
            f"{WORKER_MACHINES_URL}/process",
            json=machine.model_dump(mode="json"),
            timeout=10.0,
        )
        response.raise_for_status()
    except Exception as exc:
        logger.exception("Failed to deliver machine %s to worker", machine.id)
        raise HTTPException(status_code=502, detail=f"Worker processing failed: {exc}")

    return machine


@app.post("/machines/reassign", response_model=Machine)
def reassign_machine(machine: Machine):
    reassigned_machine = Machine.from_input_data(
        machine.model_dump(mode="json", exclude={"id", "status", "metadata"}),
        get_next_machine_id_from_worker(),
    )
    reassigned_machine.status = machine.status
    reassigned_machine.metadata = machine.metadata
    return reassigned_machine


@app.get("/schema/machine")
def machine_schema():
    return Machine.model_json_schema()


def main():
    import uvicorn

    logger.info("Starting backend API on %s:%s", API_HOST, API_PORT)
    uvicorn.run("api_backend:app", host=API_HOST, port=API_PORT, reload=False)


if __name__ == "__main__":
    main()