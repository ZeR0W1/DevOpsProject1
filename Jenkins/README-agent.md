# Jenkins images and EKS pipelines

Project overview: [../README.md](../README.md)

This directory contains the separate CI and CD Jenkinsfiles plus reproducible
controller and agent images:

- `Dockerfile.controller` and `plugins.txt` build the private in-cluster Jenkins
  controller image used by the Helm release;
- `Dockerfile.agent` builds the Python/check container used by CI; and
- `Dockerfile.kaniko-agent` builds the Kaniko compatibility image used for
  unprivileged application-image builds.

## Python agent

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
- Sonar Scanner CLI and Docker CLI retained for optional future CI stages and
  operator diagnostics
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

## EKS usage

The EKS CI agent Pod also contains separate Kaniko, Helm/kubectl, and Trivy
containers. Application images are built by Kaniko; this Python container does
not mount `/var/run/docker.sock`. The parameter-gated Trivy stage runs from the
dedicated pinned Trivy container, not from this Python image.

## Pipeline boundaries and security

- Do not mount a host Docker socket into the EKS pipeline. The active image-build
  path uses the separate unprivileged Kaniko container.
- The bundled Sonar Scanner and Docker CLI are not currently invoked by
  `Jenkinsfile.eks`; enable them only through a reviewed, resource-bounded stage.
- `RUN_TRIVY_SCAN=true` enables the dedicated Trivy filesystem vulnerability and
  secret scan only in `BUILD_AND_DEPLOY`; it fails on HIGH/CRITICAL findings.
- The active EKS pipeline uses Docker Hub credentials referenced by
  `DOCKERHUB_CREDENTIALS_ID` only to push application images.
- `Jenkinsfile.eks` owns tests and publication of one immutable tag across all
  three services. `Jenkinsfile-deploy` alone receives namespace-scoped deployment
  access and performs FULL or CONTENT_ONLY delivery.
- Jenkins is ClusterIP-only. Ansible seeds jobs and registry credentials through
  hardened short-lived in-cluster Jobs rather than exposing the controller.