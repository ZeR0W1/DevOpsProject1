import json
import sys
from pathlib import Path
from unittest.mock import Mock

import pytest
from fastapi import HTTPException


WORKER_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(WORKER_DIR))

import os

os.environ.setdefault("BACKEND_HOST", "backend")
os.environ.setdefault("POSTGRES_DSN", "postgresql://test.invalid/postgres")
os.environ.setdefault("S3_BUCKET_NAME", "test-application-bucket")
os.environ.setdefault("SNS_TOPIC_ARN", "arn:aws:sns:us-east-1:111122223333:test-topic")

import api


def test_postgres_healthy_empty_catalog_does_not_fall_back_to_json(monkeypatch, tmp_path):
    catalog = tmp_path / "instances.json"
    catalog.write_text('[{"id": 99, "name": "stale"}]', encoding="utf-8")
    monkeypatch.setattr(api, "POSTGRES_ENABLED", True)
    monkeypatch.setattr(api, "load_instances_from_postgres", Mock(return_value=[]))

    assert api.load_authoritative_instances(catalog) == []


def test_postgres_read_failure_is_not_hidden(monkeypatch):
    monkeypatch.setattr(api, "POSTGRES_ENABLED", True)
    monkeypatch.setattr(
        api,
        "load_instances_from_postgres",
        Mock(side_effect=RuntimeError("database unavailable")),
    )

    with pytest.raises(RuntimeError, match="database unavailable"):
        api.load_authoritative_instances()


def test_process_machine_persists_exports_uploads_then_notifies(monkeypatch, tmp_path):
    catalog = tmp_path / "instances.json"
    machine = {"id": 7, "name": "private-machine-name"}
    calls = []

    monkeypatch.setattr(api, "WORKER_INSTANCES_FILEPATH", catalog)
    monkeypatch.setattr(api, "POSTGRES_ENABLED", True)
    monkeypatch.setattr(api, "load_authoritative_instances", Mock(return_value=[]))
    monkeypatch.setattr(
        api,
        "backup_machine_to_postgres",
        lambda saved: calls.append(("postgres", saved["id"])),
    )
    monkeypatch.setattr(
        api,
        "load_instances_from_postgres",
        lambda: calls.append(("reload", None)) or [machine],
    )
    monkeypatch.setattr(
        api,
        "sync_instances_file_to_s3",
        lambda filepath: calls.append(("s3", Path(filepath).name)),
    )
    monkeypatch.setattr(
        api,
        "publish_sns_notification",
        lambda event, count: calls.append(("sns", event, count)),
    )

    result = api.process_machine(machine)

    assert result == {"status": "accepted", "machine_id": 7}
    assert json.loads(catalog.read_text(encoding="utf-8")) == [machine]
    assert calls == [
        ("postgres", 7),
        ("reload", None),
        ("s3", "instances.json"),
        ("sns", "catalog.machine_processed", 1),
    ]


def test_process_machine_does_not_notify_after_s3_failure(monkeypatch):
    notification = Mock()
    monkeypatch.setattr(api, "append_machine", Mock(return_value=({"id": 3}, 1)))
    monkeypatch.setattr(
        api,
        "sync_instances_file_to_s3",
        Mock(side_effect=RuntimeError("upload failed")),
    )
    monkeypatch.setattr(api, "publish_sns_notification", notification)

    with pytest.raises(HTTPException) as exc_info:
        api.process_machine({"id": 3})

    assert exc_info.value.status_code == 503

    notification.assert_not_called()


def test_s3_sync_uses_fixed_catalog_key(monkeypatch, tmp_path):
    catalog = tmp_path / "instances.json"
    catalog.write_text("[]", encoding="utf-8")
    s3_client = Mock()
    boto3_client = Mock(return_value=s3_client)
    monkeypatch.setattr(api, "S3_SYNC_ENABLED", True)
    monkeypatch.setattr(api, "S3_BUCKET_NAME", "application-bucket")
    monkeypatch.setattr(api, "S3_INSTANCES_OBJECT_KEY", "instances.json")
    monkeypatch.setattr("boto3.client", boto3_client)

    api.sync_instances_file_to_s3(str(catalog))

    boto3_client.assert_called_once_with("s3", region_name=api.AWS_REGION)
    s3_client.upload_file.assert_called_once_with(
        str(catalog),
        "application-bucket",
        "instances.json",
    )


def test_sns_notification_contains_metadata_only(monkeypatch):
    sns_client = Mock()
    monkeypatch.setattr(api, "SNS_NOTIFICATIONS_ENABLED", True)
    monkeypatch.setattr(api, "SNS_TOPIC_ARN", "arn:aws:sns:us-east-1:111122223333:catalog")
    monkeypatch.setattr(api, "S3_INSTANCES_OBJECT_KEY", "instances.json")
    monkeypatch.setattr("boto3.client", Mock(return_value=sns_client))

    api.publish_sns_notification("catalog.machine_processed", 4)

    publish_call = sns_client.publish.call_args.kwargs
    assert json.loads(publish_call["Message"]) == {
        "event": "catalog.machine_processed",
        "machine_count": 4,
        "object_key": "instances.json",
    }
    message = json.loads(publish_call["Message"])
    assert set(message) == {"event", "machine_count", "object_key"}
    assert "private-machine-name" not in publish_call["Message"]


def test_disabled_aws_integrations_are_noops(monkeypatch, tmp_path):
    boto3_client = Mock()
    monkeypatch.setattr(api, "S3_SYNC_ENABLED", False)
    monkeypatch.setattr(api, "SNS_NOTIFICATIONS_ENABLED", False)
    monkeypatch.setattr("boto3.client", boto3_client)

    api.sync_instances_file_to_s3(str(tmp_path / "missing.json"))
    api.publish_sns_notification("catalog.machine_processed", 0)

    boto3_client.assert_not_called()
