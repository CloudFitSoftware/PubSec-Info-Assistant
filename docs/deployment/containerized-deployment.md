## Table of Contents <!-- omit in toc -->

- [Install additional build requirements](#install-additional-build-requirements)
  - [Docker](#docker)
  - [kubectl](#kubectl)
  - [helm](#helm)
  - [(optional) k9s](#optional-k9s)
- [Deployment with Existing OpenAI Instance](#deployment-with-existing-openai-instance)
- [Deployment for Disconnected Scenarios](#deployment-for-disconnected-scenarios)
- [Manual Steps for Supporting a Containerized Deployment](#manual-steps-for-supporting-a-containerized-deployment)
  - [Build infrastructure, containers, and generate helm values](#build-infrastructure-containers-and-generate-helm-values)
  - [Get credentials](#get-credentials)
  - [Install nVidia drivers in AKS](#install-nvidia-drivers-in-aks)
  - [Upload the LLM Tensor Files](#upload-the-llm-tensor-files)
  - [Update Storage Account Network Policies](#update-storage-account-network-policies)
  - [Add storage account secret to AKS cluster](#add-storage-account-secret-to-aks-cluster)
  - [Build the LLM server](#build-the-llm-server)
  - [Push containers to ACR](#push-containers-to-acr)
  - [Install kubernetes pods using helm](#install-kubernetes-pods-using-helm)
- [Roadmap](#roadmap)
  - [Supporting Pipelines for Deployment](#supporting-pipelines-for-deployment)
  - [Reduce manual steps with automation](#reduce-manual-steps-with-automation)
  - [Fine-tuning LLMs and grounding prompts](#fine-tuning-llms-and-grounding-prompts)
- [Basic Architecture](#basic-architecture)

## Install additional build requirements

### Docker

This is required for building and pushing containers

- [Docker Install](https://www.docker.com/products/docker-desktop/)

### kubectl

This is required to create a k8s secret for the LLM storage account key

- [kubectl Install](https://kubernetes.io/docs/tasks/tools/)

### helm

This is required to configure AKS (or any Kubernetes cluter) with all of the required applications and dependencies

- [helm Install](https://helm.sh/docs/intro/install/)

### (optional) k9s

K9s is a tool to help manage clusters in a text-based GUI.  This is **not** a required installation

- [k9s](https://github.com/derailed/k9s?tab=readme-ov-file#installation)

## Deployment with Existing OpenAI Instance

> [!IMPORTANT] 
> If you are deploying into a Microsoft Azure Government tenant, please follow the [Sovereign Deployment Guide](sovereign_deployment_guide.md) for considerations

In the above document, perform the following steps, and then return to this document for continuing a containerized deployment:

- [Create the instance of Azure OpenAI API](./sovereign_deployment_guide.md#creating-the-instance-of-azure-openai-api) and sub steps
- [Accept the terms of the "Responsible AI Notice](./sovereign_deployment_guide.md#accept-the-terms-of-the-responsible-ai-notice)
- [Build Requirements](./sovereign_deployment_guide.md#build-requirements) and sub steps

When using an existing OpenAI Instance, we do not need to upload and install the LLM container and dependencies.  Follow the following steps below:

- [Build infra/containers and generate helm values](#build-infrastructure-containers-and-generate-helm-values)
- [Get Credentials](#get-credentials)
- Skip the nVidia/LLM steps and continue below
- [Push Containers to ACR](#push-containers-to-acr)

## Deployment for Disconnected Scenarios

> [!IMPORTANT]
> As of March 21, 2024, Azure OpenAI is not available for disconnected scenarios.  This solution utilizes an Open Source Large Language Model (LLM), Mistral-7B-Instruct-v0.2.
>
> There are limitations to using smaller LLMs that can fit within availabile SKUs in a Microsoft Azure Government Tenant.  As we continue to evalutate solutions, additional LLMs may become available

## Manual Steps for Supporting a Containerized Deployment

### Build infrastructure, containers, and generate helm values

```bash
make deploy-containers
make build-containers
./scripts/helm-create-values.sh < infra_output.json
```

### Get credentials

```powershell
az login
az acr login -n <acr_name>
az aks get-credentials --resource-group <resource_group_name> --name <cluster_name>
```

### Install nVidia drivers in AKS

```bash
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update
helm upgrade -i nvdp nvdp/nvidia-device-plugin \
  --namespace nvidia-device-plugin \
  --create-namespace \
  --version 0.14.5
```
More information can be found here: https://github.com/NVIDIA/k8s-device-plugin?tab=readme-ov-file#deployment-via-helm

### Upload the LLM Tensor Files

#### The download process is broken into two stages: <!-- omit in toc -->

1. Download model locally
    1. In powershell, CD into the LLM folder: `cd llm`
    1. Run `save_model.py` to download the model. For example, run `python3 save_model.py mistral` to download the mistral model that we are currently using.
    1. You will find the model tensorfiles downloaded in the models folder once the script is done running.

1. Copy the LLM tensorfiles to LLM folder
    1. Navigate to the infoasststoreshared page in the Azure Portal
    1. Select the "File shares" tab
    1. Select the llms folder
    1. Select "Connect"
    1. Mount to your local file system, and copy the model folder under `\<source>\llm\models` 
        > Example:
        > 
        > `robocopy c:\<source>llm\models\mistral-7b-instruct-v0.2\ z:\mistral-7b-instruct-v0.2\ /MIR /MT:4`
        
        This assumes that Z: is the drive letter for your Azure file share mount

### Update Storage Account Network Policies

1. Navigate to your storage account in the Azure Portal
1. Select `Networking` under the `Security + networking` section in the left navigation menu
1. Update Public network access to `Enabled from selected virtual networks and IP addresses`:
 
   ![alt text](/docs/images/storage-networkaccess.png)
1. Add an existing virtual network
1. Select your AKS v-net in the wizard.  Example output:

   ![alt text](/docs/images/storage-vnet.png)
1. Ensure you press Save to save settings.

### Add storage account secret to AKS cluster

Note: Ensure that you are logged in to the correct tenant/subscription with `azcli`
```powershell
$STORAGE_KEY=$(az storage account keys list --resource-group <resourcegroup> --account-name <storageaccount> --query "[0].value" -o tsv)

kubectl create secret generic infoasst-llms-share --from-literal=azurestorageaccountname=<storageaccount> --from-literal=azurestorageaccountkey=$STORAGE_KEY --namespace infoasst
```

### Build the LLM server

```bash
cd <source>/llm
docker build --tag <acrname>.azurecr.us/llm:latest -f ./Dockerfile .
docker push <acrname>.azurecr.us/llm:latest
```

### Push containers to ACR

docker push each image for `webapp`, `function`, `weaviate`, `t2v`, `reranker`, `llm` and `enrichment` 

```powershell
docker push <acrname>.azurecr.us/<container_name>:latest
```

### Install kubernetes pods using helm

helm install each chart for `webapp`, `function`, `weaviate`, `t2v`, `reranker`, `llm`, and `enrichment`

```powershell
helm install infoasst-<pod_name> ./infoasst-<pod_name> --namespace infoasst --create-namespace
```

## Roadmap

### Supporting Pipelines for Deployment

1. Creating pipelines for automated deployments and use of the .devcontainer will vastly improve user experience

### Reduce manual steps with automation

1. Automate docker push operations
1. Automate LLM image build

### Fine-tuning LLMs and grounding prompts

- Our current iteration works well, but there is still much room to improve our instructions to the LLM.
- Our current approch explains the answering process using a simplified example.

Here are the main components of the current prompt:
1. Targeted Information Retrieval: The prompt requires the model to sift through a structured context block, akin to a database or a collection of documents, to find the section most relevant to the question.
2. Selective Information Extraction: Once the relevant section is identified, the model must extract and present the specific information needed to answer the question. 
3. Contextual Interpretation without External Input: The model is tasked with understanding and interpreting the provided context to find the answer, without relying on external knowledge or databases.
4. Citation and Accountability: By citing the specific section from which the answer was drawn, the prompt incorporates an element of source attribution, which adds a layer of accountability and transparency to the model's responses.

## Basic Architecture

![alt text](/docs/images/container-arch.png)
