import os
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent.parent
API_PORT = int(os.getenv("API_PORT", "8000"))
BACKEND_HOST = os.getenv("BACKEND_HOST", "10.0.149.9")
BACKEND_PORT = int(os.getenv("BACKEND_PORT", "8000"))
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME", "quick-demo-058264247987-us-east-1-an")
S3_INSTANCES_OBJECT_KEY = os.getenv("S3_INSTANCES_OBJECT_KEY", "instances.json")
SNS_NOTIFICATIONS_ENABLED = os.getenv("SNS_NOTIFICATIONS_ENABLED", "true").strip().lower() in {"1", "true", "yes", "on"}
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN", "arn:aws:sns:us-east-1:058264247987:DOAworker")
POSTGRES_ENABLED = os.getenv("POSTGRES_ENABLED", "true").strip().lower() in {"1", "true", "yes", "on"}
POSTGRES_DSN = os.getenv("POSTGRES_DSN", "")
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "dodb2.celu8oms0zc2.us-east-1.rds.amazonaws.com")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_DB = os.getenv("POSTGRES_DB", "postgres")
POSTGRES_USER = os.getenv("POSTGRES_USER", "postgres_master")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgres")
POSTGRES_TABLE = os.getenv("POSTGRES_TABLE", "machines")
POSTGRES_SSLMODE = os.getenv("POSTGRES_SSLMODE", "verify-full")
POSTGRES_SSLROOTCERT = os.getenv("POSTGRES_SSLROOTCERT", str(BASE_DIR / "src" / "worker" / "global-bundle.pem"))