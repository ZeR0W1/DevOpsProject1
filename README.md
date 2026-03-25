
## Overview

This is a rolling project that will evolve as new topics are learned. At this stage, the goal is to build the skeleton of an infrastructure provisioning tool. Future enhancements may integrate AWS and Terraform to create real resources. For now, the provisioning process is mocked to simulate infrastructure automation.

GitHub repository: https://github.com/ZeR0W1/DevOpsProject1.git

## Project Objective

Develop a modular Python-based automation tool that simulates infrastructure provisioning and service configuration by accepting and validating user inputs, all while maintining proper logging and error handling

## Current Project Structure
```text
src/
  config.py            Shared config values and output helper
  infra_simulator.py   Main entry point
  machine.py           Pydantic machine model
  provisioning.py      Infrastructure provisioning simulation
  schema.py            Nested models and enums
  user_input.py        Interactive user input collection and validation

configs/
  instances.json       Saved provisioned machines

scripts/
  inst_service.sh      service installation script(Linux)
```

## Setup Instructions

1. Make sure Python is installed.
2. Install the required dependency in a venv:

from the project root directory:

### Linux:

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```
### Windows:

```PowerShell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
python -m venv venv
venv\Scripts\Activate
pip install -r requirements.txt
```

3. Run the simulator from the project root:

```bash
python src/infra_simulator.py
```

## Example Expected Output

Example terminal session for creating one machine:

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
Enter tag (leave blank to finish): web
Enter tag (leave blank to finish): prod
Enter tag (leave blank to finish):
Enter metadata key (leave blank to finish): owner
Enter value for owner: ops-team
Enter metadata key (leave blank to finish):
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
    "version": "22.04",
    "distribution": 1
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
  "tags": ["web", "prod"],
  "metadata": {
    "owner": "ops-team"
  }
}
```

## Notes

- Machine IDs are generated from the highest existing ID in `configs/instances.json`
