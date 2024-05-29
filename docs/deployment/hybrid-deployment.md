# Hybrid Deployment Guide

## Table of Contents
- [Install Additional Build Requirements](#install-additional-build-requirements)
  - [Docker](#docker)
  - [kubectl](#kubectl)
  - [helm](#helm)
  - [(optional) k9s](#optional-k9s)
- [Deployment with Existing OpenAI Instance](#deployment-with-existing-openai-instance)
- [Manual Steps for Supporting a Partially Containerized Deployment](#manual-steps-for-supporting-a-partially-containerized-deployment)
  - [Set CloudFit Flags](#set-cloudfit-flags)
  - [Build Infrastructure, Containers, and Generate Helm Values](#build-infrastructure-containers-and-generate-helm-values)
  - [Get Credentials](#get-credentials)
  - [Push Containers to ACR](#push-containers-to-acr)
  - [Install Kubernetes Pods](#install-kubernetes-pods)

## Install Additional Build Requirements

### Docker

This is required for building and pushing containers.

- [Docker Install](https://www.docker.com/products/docker-desktop/)

### kubectl

This is required to create a k8s secret for the LLM storage account key.

- [kubectl Install](https://kubernetes.io/docs/tasks/tools/)

### helm

This is required to configure AKS (or any Kubernetes cluster) with all of the required applications and dependencies.

- [helm Install](https://helm.sh/docs/intro/install/)

### (optional) k9s

K9s is a tool to help manage clusters in a text-based GUI. This is **not** a required installation.

- [k9s](https://github.com/derailed/k9s?tab=readme-ov-file#installation)

## Deployment with Existing OpenAI Instance

> [!IMPORTANT]
> If you are deploying into a Microsoft Azure Government tenant, please follow the [Sovereign Deployment Guide](sovereign_deployment_guide.md) for considerations.

In the above document, perform the following steps, and then return to this document for continuing a containerized deployment:

- [Create the instance of Azure OpenAI API](./sovereign_deployment_guide.md#creating-the-instance-of-azure-openai-api) and sub steps.
- [Accept the terms of the "Responsible AI Notice"](./sovereign_deployment_guide.md#accept-the-terms-of-the-responsible-ai-notice).
- [Build Requirements](./sovereign_deployment_guide.md#build-requirements) and sub steps.

When using an existing OpenAI Instance, we do not need to upload and install the LLM container and dependencies. Follow the steps below:

- [Build Infrastructure, Containers, and Generate Helm Values](#build-infrastructure-containers-and-generate-helm-values)
- [Get Credentials](#get-credentials)
- Skip the nVidia/LLM steps and continue below.
- [Push Containers to ACR](#push-containers-to-acr)

## Manual Steps for Supporting a Partially Containerized Deployment

### Set CloudFit Flags

In your `local.env` file, set `CONTAINERIZED_APP_SERVICES` to `true`, and `DISCONNECTED_AI` to `false` to achieve a containerized deployment that still uses Azure native AI components.

### Build Infrastructure, Search Indexes, Containers, and Generate Helm Values

```bash
make deploy-containers
make deploy-search-indexes
make build-containers
./scripts/helm-create-values.sh
```

### Get credentials

```powershell
az login
az acr login -n <acr_name>
az aks get-credentials --resource-group <resource_group_name> --name <cluster_name>
```

### Push containers to ACR

docker push each image for `webapp` and `enrichment` 

```powershell
docker push <acrname>.azurecr.us/<container_name>:latest
```

### Install kubernetes pods

helm install each chart for `webapp` and `enrichment`

```powershell
cd charts
helm install infoasst-<pod_name> ./infoasst-<pod_name> --namespace infoasst --create-namespace
```



