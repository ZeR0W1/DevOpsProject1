import json
import logging
from pathlib import Path

from fastapi import FastAPI, HTTPException
import httpx
from psycopg import sql

from config import (
    API_PORT,
    AWS_REGION,
    BACKEND_HOST,
    BACKEND_PORT,
    BASE_DIR,
    POSTGRES_DB,
    POSTGRES_DSN,
    POSTGRES_ENABLED,
    POSTGRES_HOST,
    POSTGRES_PASSWORD,
    POSTGRES_PORT,
    POSTGRES_SSLMODE,
    POSTGRES_SSLROOTCERT,
    POSTGRES_TABLE,
    POSTGRES_USER,
    S3_BUCKET_NAME,
    S3_INSTANCES_OBJECT_KEY,
    S3_SYNC_ENABLED,
    SNS_NOTIFICATIONS_ENABLED,
    SNS_TOPIC_ARN,
)


logger = logging.getLogger(__name__)
WORKER_INSTANCES_FILEPATH = BASE_DIR / "configs" / "instances.json"
BACKEND_REASSIGN_URL = f"http://{BACKEND_HOST}:{BACKEND_PORT}/machines/reassign"

app = FastAPI(
    title="Infrastructure Automation Worker API",
    version="1.0.0",
    description="Worker service for persistence, S3 sync, and notifications.",
)


def ensure_supported_python():
    import sys

    minimum = (3, 11)
    if sys.version_info < minimum:
        required = ".".join(str(part) for part in minimum)
        current = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
        raise RuntimeError(f"Python {required}+ is required. Current version: {current}")


def get_postgres_connection():
    import psycopg

    if POSTGRES_DSN:
        return psycopg.connect(POSTGRES_DSN)

    return psycopg.connect(
        host=POSTGRES_HOST,
        port=POSTGRES_PORT,
        dbname=POSTGRES_DB,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        sslmode=POSTGRES_SSLMODE,
        sslrootcert=POSTGRES_SSLROOTCERT,
    )


def init_postgres_storage():
    if not POSTGRES_ENABLED:
        return

    with get_postgres_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                sql.SQL(
                    """
                CREATE TABLE IF NOT EXISTS {} (
                    id INTEGER PRIMARY KEY,
                    machine_data JSONB NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
                ).format(sql.Identifier(POSTGRES_TABLE))
            )
            cursor.execute(
                sql.SQL(
                    "ALTER TABLE {} ADD COLUMN IF NOT EXISTS "
                    "updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()"
                ).format(sql.Identifier(POSTGRES_TABLE))
            )
        connection.commit()


def load_instances(filepath: Path = WORKER_INSTANCES_FILEPATH):
    try:
        with open(filepath, "r", encoding="utf-8") as file:
            data = json.load(file)
            if isinstance(data, list):
                return data
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    return []


def export_instances_to_json(instances, filepath: Path = WORKER_INSTANCES_FILEPATH):
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, "w", encoding="utf-8") as file:
        json.dump(instances, file, indent=2)


def load_instances_from_postgres():
    if not POSTGRES_ENABLED:
        return []

    init_postgres_storage()
    with get_postgres_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                sql.SQL("SELECT machine_data FROM {} ORDER BY id").format(
                    sql.Identifier(POSTGRES_TABLE)
                )
            )
            rows = cursor.fetchall()

    machines = []
    for (machine_data,) in rows:
        if isinstance(machine_data, str):
            machine_data = json.loads(machine_data)
        if not isinstance(machine_data, dict):
            raise ValueError("PostgreSQL contains an invalid machine record")
        machines.append(machine_data)
    return machines


def load_authoritative_instances(filepath: Path = WORKER_INSTANCES_FILEPATH):
    if POSTGRES_ENABLED:
        return load_instances_from_postgres()
    return load_instances(filepath)


def publish_sns_notification(event: str, machine_count: int):
    if not SNS_NOTIFICATIONS_ENABLED or not SNS_TOPIC_ARN:
        return

    import boto3

    message = {
        "event": event,
        "machine_count": machine_count,
        "object_key": S3_INSTANCES_OBJECT_KEY,
    }
    boto3.client("sns", region_name=AWS_REGION).publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="Machine catalog synchronized",
        Message=json.dumps(message, sort_keys=True),
    )


def backup_machine_to_postgres(machine: dict):
    if not POSTGRES_ENABLED:
        return

    machine_id = machine.get("id")
    if machine_id is None:
        raise ValueError("Worker requires machine payloads with an id")

    init_postgres_storage()
    with get_postgres_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                sql.SQL(
                    """
                INSERT INTO {} (id, machine_data)
                VALUES (%s, %s::jsonb)
                ON CONFLICT (id)
                DO UPDATE SET
                    machine_data = EXCLUDED.machine_data,
                    updated_at = NOW()
                """
                ).format(sql.Identifier(POSTGRES_TABLE)),
                (machine_id, json.dumps(machine)),
            )
        connection.commit()


def sync_instances_file_to_s3(filepath: str):
    if not S3_SYNC_ENABLED:
        return

    import boto3

    boto3.client("s3", region_name=AWS_REGION).upload_file(
        filepath,
        S3_BUCKET_NAME,
        S3_INSTANCES_OBJECT_KEY,
    )


def sync_json_instances_to_postgres(filepath: Path = WORKER_INSTANCES_FILEPATH):
    if not POSTGRES_ENABLED:
        return

    file_instances = load_instances(filepath)
    if not file_instances:
        return

    postgres_instances = load_instances_from_postgres()
    postgres_ids = {
        instance.get("id")
        for instance in postgres_instances
        if isinstance(instance, dict)
    }

    for instance in file_instances:
        if not isinstance(instance, dict):
            continue
        if instance.get("id") in postgres_ids:
            continue
        backup_machine_to_postgres(instance)


def append_machine(machine: dict, filepath: Path | None = None):
    if filepath is None:
        filepath = WORKER_INSTANCES_FILEPATH

    machine_id = machine.get("id")
    if machine_id is None:
        raise ValueError("Worker requires machine payloads with an id")

    instances = load_authoritative_instances(filepath)
    existing_ids = {
        instance.get("id")
        for instance in instances
        if isinstance(instance, dict)
    }

    if machine_id in existing_ids:
        response = httpx.post(BACKEND_REASSIGN_URL, json=machine, timeout=10.0)
        response.raise_for_status()
        machine = response.json()

    if POSTGRES_ENABLED:
        backup_machine_to_postgres(machine)
        instances = load_instances_from_postgres()
    else:
        instances.append(machine)

    export_instances_to_json(instances, filepath)
    return machine, len(instances)


def replace_all_postgres_instances(instances: list[dict]):
    if not POSTGRES_ENABLED:
        return

    init_postgres_storage()
    with get_postgres_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                sql.SQL("DELETE FROM {}").format(sql.Identifier(POSTGRES_TABLE))
            )
            for instance in instances:
                cursor.execute(
                    sql.SQL(
                        "INSERT INTO {} (id, machine_data) VALUES (%s, %s::jsonb)"
                    ).format(sql.Identifier(POSTGRES_TABLE)),
                    (instance["id"], json.dumps(instance)),
                )
        connection.commit()


def recatalogue_instances(filepath: Path = WORKER_INSTANCES_FILEPATH):
    instances = load_authoritative_instances(filepath)
    recatalogued = []

    for index, instance in enumerate(instances, start=1):
        if not isinstance(instance, dict):
            continue
        updated = dict(instance)
        updated["id"] = index
        recatalogued.append(updated)

    replace_all_postgres_instances(recatalogued)
    if POSTGRES_ENABLED:
        recatalogued = load_instances_from_postgres()
    export_instances_to_json(recatalogued, filepath)
    sync_instances_file_to_s3(str(filepath))

    publish_sns_notification("catalog.recatalogued", len(recatalogued))

    return {
        "status": "recatalogued",
        "count": len(recatalogued),
        "ids": [instance["id"] for instance in recatalogued],
    }


@app.get("/health")
def healthcheck():
    return {"status": "ok", "service": "worker-api"}


@app.get("/machines")
def list_machines():
    try:
        return load_authoritative_instances()
    except Exception:
        logger.exception("Worker failed to load the authoritative machine catalog")
        raise HTTPException(status_code=503, detail="Machine catalog unavailable")


@app.post("/machines/process")
def process_machine(machine: dict):
    try:
        saved, machine_count = append_machine(machine)
        sync_instances_file_to_s3(str(WORKER_INSTANCES_FILEPATH))
        publish_sns_notification("catalog.machine_processed", machine_count)
        return {"status": "accepted", "machine_id": saved.get("id")}
    except (ValueError, httpx.HTTPError) as exc:
        logger.warning("Worker rejected a machine payload: %s", exc)
        raise HTTPException(status_code=422, detail="Machine payload could not be processed")
    except Exception:
        logger.exception("Worker failed to persist and synchronize a machine")
        raise HTTPException(status_code=503, detail="Machine persistence unavailable")


@app.post("/machines/recatalogue")
def recatalogue_machines():
    try:
        return recatalogue_instances()
    except Exception:
        logger.exception("Worker failed to recatalogue and synchronize machines")
        raise HTTPException(status_code=503, detail="Machine recatalogue unavailable")


def main():
    import uvicorn

    ensure_supported_python()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    if POSTGRES_ENABLED:
        init_postgres_storage()

    logger.info("Worker API started on %s:%s", "0.0.0.0", API_PORT)
    uvicorn.run("api:app", host="0.0.0.0", port=API_PORT, reload=False)


if __name__ == "__main__":
    main()