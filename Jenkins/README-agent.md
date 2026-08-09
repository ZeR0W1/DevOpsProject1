# Jenkins Python agent image

`Dockerfile.agent` is the reproducible source for the public image used by the
EKS-native CI pipeline:

```text
zer0w1/devops-project1-jenkins-agent:eks-python-v1
```

`Jenkins/Jenkinsfile.eks` runs this image as the `python` container in an
ephemeral Kubernetes agent Pod. The Kubernetes plugin overrides the image entry
point with `cat`; no permanent inbound node or host Docker socket is required by
the active EKS pipeline.

It includes:

- Official Jenkins inbound agent runtime with JDK 21
- Git and OpenSSH client for checkout
- Python 3, `venv`, and `pip`
- `pytest`, `flake8`, and `bandit`
- Sonar Scanner CLI, Docker CLI, and Trivy retained for the archived local-agent
  workflow
- `jq`, `curl`, `bash`, and common CA certificates

## Build

From the repository root:

```bash
docker build \
  -f Jenkins/Dockerfile.agent \
  -t zer0w1/devops-project1-jenkins-agent:eks-python-v1 \
  Jenkins
```

The published repository is public, so EKS and other users can pull it without
the repository owner's Docker Hub credentials. Credentials are required only to
push a rebuilt image. A user who wants an independently owned copy can tag and
push it to their own registry, then update the CI Pod image reference.

## Active EKS usage

The EKS CI agent Pod also contains separate Kaniko, Helm/kubectl, and Trivy
containers. Application images are built by Kaniko; this Python container does
not mount `/var/run/docker.sock`.

## Archived local inbound-agent usage

The earlier single-service local pipeline is retained under
`Jenkins/legacy/local-docker/Jenkinsfile`. Its helper is retained under
`scripts/legacy/create_jenkins_pipeline_job.sh`. That lab flow used this same
image as a permanent inbound node with the `docker-builder` label and a host
Docker socket mount.

```text
docker-builder
```

Then run the container with the node secret and node name from Jenkins:

```bash
docker run --rm \
  --name devops-project1-jenkins-agent \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$(stat -c '%g' /var/run/docker.sock)" \
  zer0w1/devops-project1-jenkins-agent:eks-python-v1 \
  -url '<JENKINS_URL>' \
  '<AGENT_SECRET>' \
  '<AGENT_NAME>'
```

## Important notes

- The Docker socket grants control of the host daemon and belongs only to the
  archived local lab flow; do not introduce it into the EKS pipeline.
- The active EKS pipeline uses Docker Hub credentials referenced by
  `DOCKERHUB_CREDENTIALS_ID` only to push application images.