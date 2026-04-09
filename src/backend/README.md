## Backend instance

### Functional intent

The backend is the validation and orchestration layer.

- accepts machine requests from the frontend
- validates request payloads
- assigns machine IDs
- forwards verified machines to the worker
- exposes read and health endpoints

### Structure

```text
src/backend/
  api.py
  config.py
  machine.py
  schema.py
  README.md
```

### Deployment setup

Install dependencies:

```bash
pip install -r requirements-backend.txt
```

Run from the `src/backend/` directory:

```bash
python api.py
```

### systemd setup

Install and start:

```bash
sudo tee /etc/systemd/system/infra-backend.service >/dev/null <<'UNIT'
[Unit]
Description=Infrastructure Automation Backend API
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user/infra-automation/src/backend
Environment="API_HOST=127.0.0.1"
Environment="API_PORT=8000"
Environment="WORKER_HOST=10.0.157.192"
Environment="WORKER_PORT=8000"
ExecStart=/home/ec2-user/infra-automation/venv/bin/python /home/ec2-user/infra-automation/src/backend/api.py
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable infra-backend.service
sudo systemctl restart infra-backend.service
sudo systemctl status infra-backend.service
```

### Key configuration

```bash
API_HOST=127.0.0.1
API_PORT=8000
WORKER_HOST=10.0.157.192
WORKER_PORT=8000
```

### Current AWS attachment notes

- instance security group: `backend-api`
- inbound application traffic: `8000/tcp` from security group `http`
- backend forwards worker requests to `10.0.157.192:8000`