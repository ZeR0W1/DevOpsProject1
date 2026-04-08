
## Overview

This is a rolling project that will evolve as new topics are learned. At this stage, the goal is to build the skeleton of an infrastructure provisioning tool. Future enhancements may integrate AWS and Terraform to create real resources. For now, the provisioning process is mocked to simulate infrastructure automation.

## Project Objective

Develop a modular Python-based automation tool that simulates infrastructure provisioning and service configuration by accepting and validating user inputs, all while maintining proper logging and error handling

## Current Project Structure
```text
src/
  api_backend.py        FastAPI backend entry point for nginx-proxied API mode
  config.py            Shared config values and output helper
  infra_simulator.py   Legacy CLI/testing entry point (currently inactive)
  machine.py           Pydantic machine model
  provisioning.py      Local/testing provisioning helpers
  schema.py            Nested models and enums
  user_input.py        Interactive user input collection and validation
  worker.py            Worker API for post-processing verified machines

configs/
  instances.json       Saved provisioned machines

scripts/
  inst_service.sh      service installation script(Linux)
```

## Setup Instructions

1. Make sure Python 3.11+ and git are installed.
2. Clone or update the project according to the role of the machine.

### Backend EC2 clone/update

Initial clone:

```bash
git clone --filter=blob:none --no-checkout --branch aws-assignment1 https://github.com/ZeR0W1/DevOpsProject1.git infra-automation
cd infra-automation
git sparse-checkout init --no-cone
git sparse-checkout set /README.md /requirements.txt /requirements-backend.txt src/api_backend.py src/config.py src/machine.py src/provisioning.py src/schema.py src/user_input.py configs/ /.gitignore
git checkout aws-assignment1
```

Update later:

```bash
cd /home/ec2-user/infra-automation
git checkout aws-assignment1
git pull origin aws-assignment1
```

### Worker EC2 clone/update

Initial clone:

```bash
git clone --filter=blob:none --no-checkout --branch aws-assignment1 https://github.com/ZeR0W1/DevOpsProject1.git infra-automation
cd infra-automation
git sparse-checkout init --no-cone
git sparse-checkout set /README.md /requirements.txt /requirements-worker.txt src/worker.py src/config.py src/machine.py src/schema.py configs/ /.gitignore
git checkout aws-assignment1
```

Update later:

```bash
cd /home/ec2-user/infra-automation
git checkout aws-assignment1
git pull origin aws-assignment1
```

### Frontend EC2 clone/update

If you want the HTML file directly from the repo on the frontend machine:

```bash
git clone --filter=blob:none --no-checkout --branch aws-assignment1 https://github.com/ZeR0W1/DevOpsProject1.git infra-automation
cd infra-automation
git sparse-checkout init --no-cone
git sparse-checkout set frontend/index2.html
git checkout aws-assignment1
```

Update later:

```bash
cd /home/ec2-user/infra-automation
git checkout aws-assignment1
git pull origin aws-assignment1
```

3. In the project root directory, create and activate a virtual environment:

from the project root directory:

### Linux:

```bash
python -m venv venv
source venv/bin/activate
```
### Windows:

```PowerShell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
python -m venv venv
venv\Scripts\Activate
```




4. Install dependencies according to the role you are running:

- backend EC2:

```bash
pip install -r requirements-backend.txt
```

- worker EC2:

```bash
pip install -r requirements-worker.txt
```

- local/dev environment:

```bash
for f in *requirements*.txt; do pip install -r "$f"; done
```

5. Run the active services from the project root:

- backend API:

```bash
python src/api_backend.py
```

- worker API:

```bash
python src/worker.py
```

## Backend API Mode

The project now also supports a backend API flow for the AWS assignment.

### Added requirements and why

- `fastapi` - used to expose real HTTP endpoints, read JSON request bodies, and validate them against the existing Pydantic-based machine schema.
- `uvicorn` - used to run the FastAPI app as the local Python web server that nginx can proxy requests to.

### Backend input/output model

- `MachineInput` represents the data the frontend is allowed to send.
- `Machine` represents the saved machine object, including backend-managed fields like `id`, default `status`, and internal `metadata`.

### Run the backend API

From the project root:

```bash
python src/api_backend.py
```

By default, the backend listens on `127.0.0.1:8000`, which is appropriate when nginx is used as the public-facing reverse proxy.

## Worker API Mode

The worker is a separate service that receives verified machines from the backend over HTTP.

Current worker responsibility:

- own the authoritative `instances.json`
- update that file when the backend sends a verified machine
- back up saved machines into PostgreSQL when enabled
- sync the worker-owned `instances.json` to S3
- detect machine ID overlap and ask the backend for reassignment when needed

Run the worker from the project root:

```bash
python src/worker.py
```

If your worker is managed by `systemd`, apply the PostgreSQL environment variables to that service definition and restart the service instead of launching it manually.

### Worker PostgreSQL backup with pgAdmin 4

PostgreSQL is currently configured as a **backup target**, while `configs/instances.json` remains the worker's main storage and the file that is synced to S3.

Current write flow on the worker:

1. save the verified machine into `configs/instances.json`
2. back up that machine into PostgreSQL when PostgreSQL is enabled
3. sync `configs/instances.json` to S3

If PostgreSQL is unavailable, the worker still keeps the primary JSON/S3 flow working and logs the PostgreSQL backup failure.

#### Worker environment variables

Set these on the worker host:

```bash
export POSTGRES_ENABLED=true
export POSTGRES_HOST=<postgres-host>
export POSTGRES_PORT=5432
export POSTGRES_DB=<postgres-database>
export POSTGRES_USER=<postgres-user>
export POSTGRES_PASSWORD=<postgres-password>
export POSTGRES_TABLE=machines
export POSTGRES_SSLMODE=verify-full
export POSTGRES_SSLROOTCERT=/path/to/ca-bundle.pem
```

You can also provide a single DSN instead:

```bash
export POSTGRES_DSN='postgresql://<postgres-user>:<postgres-password>@<postgres-host>:5432/<postgres-database>?sslmode=verify-full&sslrootcert=/path/to/ca-bundle.pem'
```

If your PostgreSQL provider requires TLS verification, download or place the provider CA bundle on the worker host and point `POSTGRES_SSLROOTCERT` at it.

#### systemd example for the worker service

If `worker.py` is started by `systemd`, add the PostgreSQL settings to the unit file, for example:

```ini
[Service]
Environment="POSTGRES_ENABLED=true"
Environment="POSTGRES_HOST=<postgres-host>"
Environment="POSTGRES_PORT=5432"
Environment="POSTGRES_DB=<postgres-database>"
Environment="POSTGRES_USER=<postgres-user>"
Environment="POSTGRES_PASSWORD=<postgres-password>"
Environment="POSTGRES_TABLE=machines"
Environment="POSTGRES_SSLMODE=verify-full"
Environment="POSTGRES_SSLROOTCERT=/absolute/path/to/ca-bundle.pem"
```

Then reload and restart the service:

```bash
sudo systemctl daemon-reload
sudo systemctl restart <worker-service-name>
sudo systemctl status <worker-service-name>
```

#### PostgreSQL connection test example

You can validate the same connection outside the worker with `psql` before restarting the service:

```bash
psql "host=<postgres-host> port=5432 dbname=<postgres-database> user=<postgres-user> sslmode=verify-full sslrootcert=/path/to/ca-bundle.pem"
```

If the connection succeeds, use the same values in the worker service environment.

#### PostgreSQL database setup example

If you need a dedicated backup database:

```sql
CREATE DATABASE infra_automation;
```

If you want a dedicated login instead of the default user:

```sql
CREATE USER infra_worker WITH PASSWORD 'change-me';
GRANT ALL PRIVILEGES ON DATABASE infra_automation TO infra_worker;
```

Then update the worker environment variables to match that user.

#### Connect with pgAdmin 4

In pgAdmin 4:

1. Right-click **Servers** -> **Register** -> **Server**.
2. Under **General**, enter a name such as `worker-postgres-backup`.
3. Under **Connection**, set:
   - **Host name/address**: your PostgreSQL host
   - **Port**: `5432`
   - **Maintenance database**: your PostgreSQL database
   - **Username**: your PostgreSQL username
   - **Password**: your PostgreSQL password
   - **SSL mode**: set this to match your PostgreSQL provider requirements
   - **Root certificate**: provide the CA bundle path if TLS verification is required
4. Save the server.
5. Browse to `Databases -> <your database> -> Schemas -> public -> Tables -> machines`.

To inspect the backed-up machines in pgAdmin 4, open the query tool and run:

```sql
SELECT id, machine_data, created_at
FROM machines
ORDER BY id;
```

### API endpoints

- `GET /health` - backend health check
- `GET /machines` - list machines through the backend, which reads from the worker
- `POST /machines` - validate a machine and forward it to the worker for persistence
- `POST /machines/reassign` - reassign a machine ID when the worker detects an ID collision
- `GET /schema/machine` - return the machine JSON schema

### Expected frontend JSON payload

The frontend should send JSON matching `MachineInput`, for example:

```json
{
  "name": "Machine G",
  "cpu": {
    "cores": 2,
    "threads_per_core": 2,
    "architecture": 1
  },
  "memory_gb": 8,
  "os": {
    "name": 1,
    "version": "22.04"
  },
  "disks": [
    {
      "name": "disk-g1",
      "size_gb": 50.0,
      "type": 1,
      "boot": false
    }
  ],
  "network_interfaces": [
    {
      "name": "nic-g1",
      "private_ip": "192.168.10.10",
      "mac_address": "00:16:3e:5e:6c:20",
      "public_ip": "34.10.10.10"
    }
  ],
  "tags": {
    "Environment": "Production",
    "Role": "Web"
  }
}
```

The backend assigns the machine `id`, applies the default `status`, and can attach internal `metadata` separately from the frontend payload before or after worker-side processing. If the worker detects an ID collision against its authoritative `instances.json`, it calls the backend reassign endpoint and stores the reassigned machine instead.

## Example Expected Output

Example terminal session for the legacy local CLI/testing path:

```text
Welcome!
Enter machine name: Machine G
ok
Enter number of cores: 2
ok
Enter number of threads per core: 2
ok
Choose CPU architecture:
1 - x86_64
2 - arm64
1
ok
Enter RAM(in GB, numeric only): 8
ok
Choose OS:
1 - ubuntu
2 - centos
1
ok
Enter version: 22.04
ok
Enter disk name: disk-g1
ok
Enter size(in GB): 50
ok
Choose disk type:
1 - ssd
2 - hdd
3 - nvme
1
ok
Add another disk? [y/N]: n
Enter network interface name: nic-g1
ok
Enter private ip: 192.168.10.10
ok
Enter mac address: 00:16:3e:5e:6c:20
ok
Enter public ip: 34.10.10.10
ok
Add another network_interface? [y/N]: n
Enter tags key (leave blank to finish): Environment
Enter value for Environment: Production
Enter tags key (leave blank to finish): Role
Enter value for Role: Web
Enter tags key (leave blank to finish):
Machine created: Machine G
VM saved successfully
Run service installation script? (y/N)
Installation canceled by user
```

## Example Saved Output

Example machine entry in `configs/instances.json`:

```json
{
  "id": 1,
  "name": "Machine G",
  "status": "stopped",
  "cpu": {
    "cores": 2,
    "threads_per_core": 2,
    "architecture": 1
  },
  "memory_gb": 8,
  "os": {
    "name": 1,
    "version": "22.04"
  },
  "disks": [
    {
      "name": "disk-g1",
      "size_gb": 50.0,
      "type": 1,
      "boot": false
    }
  ],
  "network_interfaces": [
    {
      "name": "nic-g1",
      "private_ip": "192.168.10.10",
      "mac_address": "00:16:3e:5e:6c:20",
      "public_ip": "34.10.10.10"
    }
  ],
  "tags": {
    "Environment": "Production",
    "Role": "Web"
  }
}
```

## Notes

- Machine IDs are generated from the highest existing ID in `instances.json`
- In the current multi-EC2 design, the worker is intended to be the owner of the authoritative `instances.json`
- The old CLI/local provisioning path is being kept only for testing/reference
