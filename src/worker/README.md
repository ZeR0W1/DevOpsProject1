## Worker instance

### Functional intent

The worker is the persistence and integration layer.

- receives verified machine payloads from the backend
- stores machine data in `configs/instances.json`
- writes and reads machine data through PostgreSQL/RDS when enabled
- uploads the instances file to S3
- sends SNS notifications when enabled

### Structure

```text
src/worker/
  api.py
  config.py
  README.md
```

### Deployment setup

Install dependencies:

```bash
pip install -r requirements-worker.txt
```

Run from the `src/worker/` directory:

```bash
python api.py
```

### systemd setup

Install and start:

```bash
sudo tee /etc/systemd/system/infra-worker.service >/dev/null <<'UNIT'
[Unit]
Description=Infrastructure Automation Worker API
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/infra-automation/src/worker
Environment="API_PORT=8000"
Environment="BACKEND_HOST=10.0.149.9"
Environment="BACKEND_PORT=8000"
Environment="S3_BUCKET_NAME=quick-demo-058264247987-us-east-1-an"
Environment="S3_INSTANCES_OBJECT_KEY=instances.json"
Environment="SNS_NOTIFICATIONS_ENABLED=true"
Environment="SNS_TOPIC_ARN=arn:aws:sns:us-east-1:058264247987:DOAworker"
Environment="POSTGRES_ENABLED=true"
Environment="POSTGRES_HOST=dodb2.celu8oms0zc2.us-east-1.rds.amazonaws.com"
Environment="POSTGRES_PORT=5432"
Environment="POSTGRES_DB=postgres"
Environment="POSTGRES_USER=postgres_master"
Environment="POSTGRES_PASSWORD=postgres"
Environment="POSTGRES_TABLE=machines"
Environment="POSTGRES_SSLMODE=verify-full"
Environment="POSTGRES_SSLROOTCERT=/home/ec2-user/infra-automation/src/worker/global-bundle.pem"
ExecStart=/home/ec2-user/infra-automation/venv/bin/python /home/ec2-user/infra-automation/src/worker/api.py
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable infra-worker.service
sudo systemctl restart infra-worker.service
sudo systemctl status infra-worker.service
```

### Key configuration

```bash
API_PORT=8000
BACKEND_HOST=10.0.149.9
BACKEND_PORT=8000
S3_BUCKET_NAME=quick-demo-058264247987-us-east-1-an
S3_INSTANCES_OBJECT_KEY=instances.json
SNS_NOTIFICATIONS_ENABLED=true
SNS_TOPIC_ARN=arn:aws:sns:us-east-1:058264247987:DOAworker
POSTGRES_ENABLED=true
POSTGRES_HOST=dodb2.celu8oms0zc2.us-east-1.rds.amazonaws.com
POSTGRES_PORT=5432
POSTGRES_DB=postgres
POSTGRES_USER=postgres_master
POSTGRES_PASSWORD=postgres
POSTGRES_TABLE=machines
POSTGRES_SSLMODE=verify-full
POSTGRES_SSLROOTCERT=/home/ec2-user/infra-automation/src/worker/global-bundle.pem
```

### Current AWS attachment notes

- instance security group: `worker-app`
- inbound application traffic: `8000/tcp` from security group `backend-api`
- RDS access is allowed from `worker-app`
- direct pgAdmin access is intentionally preserved through the RDS security group admin-IP rule