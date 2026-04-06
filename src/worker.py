import logging
import json
from pathlib import Path

from fastapi import FastAPI
import httpx

from config import (
    API_HOST,
    API_PORT,
    BACKEND_HOST,
    BACKEND_PORT,
    BASE_DIR,
    S3_BUCKET_NAME,
    S3_INSTANCES_OBJECT_KEY,
    ensure_supported_python,
)
from machine import Machine


logger = logging.getLogger(__name__)
WORKER_INSTANCES_FILEPATH = BASE_DIR / "configs" / "instances.json"
BACKEND_REASSIGN_URL = f"http://{BACKEND_HOST}:{BACKEND_PORT}/machines/reassign"

app = FastAPI(
    title="Infrastructure Automation Worker API",
    version="1.0.0",
    description="Worker service for post-processing verified machines.",
)


def sync_instances_file_to_s3(filepath: str):
    try:
        import boto3

        s3_client = boto3.client("s3")
        s3_client.upload_file(filepath, S3_BUCKET_NAME, S3_INSTANCES_OBJECT_KEY)
        logger.info(
            "Worker uploaded instances file to s3://%s/%s",
            S3_BUCKET_NAME,
            S3_INSTANCES_OBJECT_KEY,
        )
    except ImportError:
        logger.warning("boto3 is not installed on the worker, skipping S3 sync")
    except Exception:
        logger.exception("Worker failed to sync instances file to S3")
        raise


def load_instances(filepath=WORKER_INSTANCES_FILEPATH):
    try:
        with open(filepath, "r", encoding="utf-8") as file:
            instances = json.load(file)
            if isinstance(instances, list):
                return instances
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    return []


def append_vm_to_worker_instances_file(machine: Machine, filepath=WORKER_INSTANCES_FILEPATH):
    instances = load_instances(filepath)

    existing_ids = {instance.get("id") for instance in instances}
    if machine.id in existing_ids:
        response = httpx.post(
            BACKEND_REASSIGN_URL,
            json=machine.model_dump(mode="json"),
            timeout=10.0,
        )
        response.raise_for_status()
        machine = Machine.model_validate(response.json())

    instances.append(machine.to_dict())

    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, "w", encoding="utf-8") as file:
        json.dump(instances, file, indent=2)

    logger.info("Worker saved machine %s locally", machine.id)
    return machine


@app.get("/health")
def healthcheck():
    return {"status": "ok", "service": "worker-api"}


@app.get("/machines")
def list_machines():
    return load_instances()


@app.post("/machines/process")
def process_machine(machine: Machine):
    machine = append_vm_to_worker_instances_file(machine)
    sync_instances_file_to_s3(str(WORKER_INSTANCES_FILEPATH))
    logger.info("Worker processed machine %s", machine.id)
    return {"status": "accepted", "machine_id": machine.id}


def main():
    ensure_supported_python()
    import uvicorn

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    logger.info("Worker API started on %s:%s", API_HOST, API_PORT)
    uvicorn.run("worker:app", host=API_HOST, port=API_PORT, reload=False)


if __name__ == "__main__":
    main()