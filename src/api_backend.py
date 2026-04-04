import logging

from fastapi import FastAPI

from config import API_HOST, API_PORT
from machine import Machine, MachineInput
from provisioning import append_vm_to_instances_file, get_next_machine_id, load_instances


logger = logging.getLogger(__name__)

app = FastAPI(
    title="Infrastructure Automation Backend API",
    version="1.0.0",
    description="Backend API for creating and listing machine configurations.",
)


@app.get("/health")
def healthcheck():
    return {"status": "ok", "service": "backend-api"}


@app.get("/machines")
def list_machines():
    return load_instances()


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