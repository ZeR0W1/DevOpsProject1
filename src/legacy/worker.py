import logging
import json

from fastapi import FastAPI
import httpx
from psycopg import sql

from config import (
    API_PORT,
    BACKEND_HOST,
    BACKEND_PORT,
    BASE_DIR,
    SNS_NOTIFICATIONS_ENABLED,
    SNS_TOPIC_ARN,
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

    try:
        with get_postgres_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    sql.SQL(
                        """
                    CREATE TABLE IF NOT EXISTS {} (
                        id INTEGER PRIMARY KEY,
                        machine_data JSONB NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                    ).format(sql.Identifier(POSTGRES_TABLE))
                )
            connection.commit()
    except ImportError:
        logger.warning("psycopg is not installed on the worker, falling back to local JSON storage")
    except Exception:
        logger.exception("Worker failed to initialize PostgreSQL backup storage")


def load_instances_from_postgres():
    if not POSTGRES_ENABLED:
        return []

    try:
        init_postgres_storage()

        with get_postgres_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    sql.SQL(
                        """
                    SELECT machine_data
                    FROM {}
                    ORDER BY id
                    """
                    ).format(sql.Identifier(POSTGRES_TABLE))
                )
                rows = cursor.fetchall()

        machines = []
        for row in rows:
            machine_data = row[0]
            if isinstance(machine_data, str):
                machine_data = json.loads(machine_data)
            if isinstance(machine_data, dict):
                machines.append(machine_data)

        return machines
    except ImportError:
        logger.warning("psycopg is not installed on the worker, falling back to local JSON storage")
    except Exception:
        logger.exception("Worker failed to read machines from PostgreSQL")

    return []


def load_authoritative_instances(filepath=WORKER_INSTANCES_FILEPATH):
    postgres_instances = load_instances_from_postgres()
    if postgres_instances:
        return postgres_instances

    return load_instances(filepath)


def export_instances_to_json(instances, filepath=WORKER_INSTANCES_FILEPATH):
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, "w", encoding="utf-8") as file:
        json.dump(instances, file, indent=2)


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


def publish_sns_notification(subject: str, message: str):
    if not SNS_NOTIFICATIONS_ENABLED or not SNS_TOPIC_ARN:
        return

    try:
        import boto3

        sns_client = boto3.client("sns")
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject[:100],
            Message=message,
        )
        logger.info("Worker published SNS notification to %s", SNS_TOPIC_ARN)
    except ImportError:
        logger.warning("boto3 is not installed on the worker, skipping SNS notification")
    except Exception:
        logger.exception("Worker failed to publish SNS notification")


def load_instances(filepath=WORKER_INSTANCES_FILEPATH):
    try:
        with open(filepath, "r", encoding="utf-8") as file:
            instances = json.load(file)
            if isinstance(instances, list):
                return instances
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    return []


def backup_machine_to_postgres(machine: Machine):
    if not POSTGRES_ENABLED:
        return

    try:
        init_postgres_storage()

        with get_postgres_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    sql.SQL(
                        """
                    INSERT INTO {} (id, machine_data)
                    VALUES (%s, %s::jsonb)
                    ON CONFLICT (id)
                    DO UPDATE SET machine_data = EXCLUDED.machine_data
                    """
                    ).format(sql.Identifier(POSTGRES_TABLE)),
                    (machine.id, json.dumps(machine.to_dict())),
                )
            connection.commit()

        logger.info("Worker backed up machine %s to PostgreSQL", machine.id)
        publish_sns_notification(
            subject=f"Machine {machine.id} stored in database",
            message=(
                f"A machine record was written to PostgreSQL.\n"
                f"Machine ID: {machine.id}\n"
                f"Machine Name: {machine.name}\n"
                f"Table: {POSTGRES_TABLE}"
            ),
        )
    except ImportError:
        logger.warning("psycopg is not installed on the worker, skipping PostgreSQL backup")
    except Exception:
        logger.exception("Worker failed to back up machine %s to PostgreSQL", machine.id)


def sync_json_instances_to_postgres(filepath=WORKER_INSTANCES_FILEPATH):
    if not POSTGRES_ENABLED:
        return

    file_instances = load_instances(filepath)
    if not file_instances:
        return

    postgres_instances = load_instances_from_postgres()
    postgres_ids = {
        instance.get("id")
        for instance in postgres_instances
        if isinstance(instance, dict) and instance.get("id") is not None
    }

    synced_count = 0

    for instance in file_instances:
        if not isinstance(instance, dict):
            continue

        instance_id = instance.get("id")
        if instance_id in postgres_ids:
            continue

        try:
            machine = Machine.model_validate(instance)
            backup_machine_to_postgres(machine)
            postgres_ids.add(machine.id)
            synced_count += 1
        except Exception:
            logger.exception("Worker failed to sync machine %s from JSON into PostgreSQL", instance_id)

    if synced_count:
        logger.info("Worker synchronized %s machine(s) from JSON into PostgreSQL", synced_count)


def append_vm_to_worker_instances_file(machine: Machine, filepath=WORKER_INSTANCES_FILEPATH):
    instances = load_authoritative_instances(filepath)

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

    export_instances_to_json(instances, filepath)
    backup_machine_to_postgres(machine)

    logger.info("Worker saved machine %s locally", machine.id)
    return machine


@app.get("/health")
def healthcheck():
    return {"status": "ok", "service": "worker-api"}


@app.get("/machines")
def list_machines():
    return load_authoritative_instances()


@app.post("/machines/process")
def process_machine(machine: Machine):
    machine = append_vm_to_worker_instances_file(machine)
    sync_instances_file_to_s3(str(WORKER_INSTANCES_FILEPATH))
    publish_sns_notification(
        subject=f"Machine {machine.id} synced to S3",
        message=(
            f"The instances file was uploaded to S3 after processing a machine.\n"
            f"Machine ID: {machine.id}\n"
            f"Machine Name: {machine.name}\n"
            f"Bucket: {S3_BUCKET_NAME}\n"
            f"Object Key: {S3_INSTANCES_OBJECT_KEY}"
        ),
    )
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

    if POSTGRES_ENABLED:
        init_postgres_storage()
        sync_json_instances_to_postgres()

    logger.info("Worker API started on %s:%s", "0.0.0.0", API_PORT)
    uvicorn.run("worker:app", host="0.0.0.0", port=API_PORT, reload=False)


if __name__ == "__main__":
    main()