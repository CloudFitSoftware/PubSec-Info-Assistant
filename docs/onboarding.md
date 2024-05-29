# Green Lightning (Infoasst) Onboarding Guide

Welcome to the Green Lightning team! This guide will walk you through the onboarding process, focusing on deployment, code updates, and container updates in IronBank.

## Overview
This document is designed for new developers joining the Green Lightning team. It will guide you through the necessary steps to deploy the application, update the code, and manage container updates in IronBank. Follow the steps carefully to ensure a smooth onboarding experience.

The application is made up of 7 components:

- **WebApp**: Front and backend code; provides GUI interface
- **Enrichment**: Embeds text and creates weaviate index
- **Weaviate**: Vectorization database; retreives relevant chunks of text that is fed to the LLM
- **Reranker**: Reranking algorithm for semantic reasoning; improves results from weaviate
- **T2v**: Model used to generate sentence embeddings that capture semantic meaning
- **LLM**: Large Language model wrapped by an API 
- **Functions**: Azure functions that process uploaded files


### Prerequisites
Before deploying, ensure you have cloned the following repos:
   - **Green Lightning Repo**: [Green Lightning Repository](https://cloudfitsoftware.visualstudio.com/CloudFit/_git/CloudFit.GreenLightning)
   - Platform One Repositories:
      - **Functions**: [Azure Function Container V1](https://repo1.dso.mil/dsop/cloudfit/ai/azure-function-container-v1.git)
      - **Webapp**: [Webapp Service V1](https://repo1.dso.mil/dsop/cloudfit/ai/webapp-front-end-v1.git)
      - **Enrichment**: [Enrichment Service V1](https://repo1.dso.mil/dsop/cloudfit/ai/enrichment-services-v1.git)
      - **Weaviate**: [Weaviate Service V1](https://repo1.dso.mil/dsop/cloudfit/ai/weaviate-v1.git)
      - **T2v**:
      - **Reranker**:
      - **LLM**:

And have installed the following tools:
   - **K9s**: Ensure k9s is installed for monitoring and debugging pods. 
   - **Helm**: You should have Helm installed for managing Kubernetes applications.
   - **Docker**: Ensure Docker is installed and configured to interact with Azure Container Registry (ACR).
   - **Azure CLI**: Install Azure CLI. For PC users, it will need to be in WSL.

---

## Stage 1: Deployment

### Deployment Steps

1. **Deploy**:
   - To deploy fully containerized, open `docs/deployment/containerized-deployment.md` and read through the containerized deployment process.
   
   **OR**
   
   - To deploy partially containerized, open `docs/deployment/hybrid-deployment.md` and read through the hybrid deployment process.

2. **Verify Deployment**:
   - Log into portal.azure.us, and navigate to the Kubernetes service in your new resource group.
   - Select "Services and ingresses."
   - Select the blue link to test out the application.

3. **Resolve Issues**:
   - Use `k9s` to monitor and debug the pods.

---

## Stage 2: Updating the Code

Once the application is deployed and all containers are running, you can start developing new features or updating existing ones.

Be sure to run the following `az` commands in PowerShell before starting: 
If deploying to Azure Commerical:
```bash
az cloud set -n AzureCloud
```
If deploying to MAG (Microsoft Azure Government):
```bash
az cloud set -n AzureUSGovernment
```
Then log into Azure:
```bash
az login
```
Then log into the ACR and AKS services:
```bash
az acr login -n <acr-name>
az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
```

### Delete the Pod and Update the Container

1. **Delete the Pod**:
   - Open a PowerShell terminal.
   - Use `helm delete infoasst-<pod-name> -n infoasst` to delete the specific pod you want to update.

2. **Rebuild**:
   - Switch to WSL.
   - Use `make build-containers` to rebuild the containers with the latest code.
      - The `make build-containers` abstracts the docker build commands into one simple command. You can view the script in `scripts/build-containers.sh`.

3. **Push to Azure Container Registry**:
   - In PowerShell, use `docker push <acr-name>.azurecr.us/<pod-name>:latest` to push the updated container to ACR.

### Reinstalling the Pod

1. **Reinstall the Pod**:
   - In PowerShell, navigate to the charts directory.
   - Use `helm install infoasst-<pod-name> ./infoasst-<pod-name> --namespace infoasst --create-namespace` to reinstall the pod.

2. **Verify Reinstallation**:
   - Use `k9s` to check that the pod is running.
   - Confirm that the updated code is reflected in the new pod.

### Example
In this example, lets imagine we have made changes to all of the pods in a `fully containerized deployment`, so they all need to be updated with the latest code.

Please note, for the weaviate pod, we separated the PVC for weaviate into its own chart called weaviate-storage. Do not helm delete this if you do not intend to lose the weaviate index.  

1. **Delete the Pods**:
   - In PowerShell, run:
     ```bash
     helm delete infoasst-webapp -n infoasst
     helm delete infoasst-enrichment -n infoasst
     helm delete infoasst-weaviate-container -n infoasst
     helm delete infoasst-t2v -n infoasst
     helm delete infoasst-reranker -n infoasst
     helm delete infoasst-llm -n infoasst
     ```

2. **Rebuild the Containers**:
   - In WSL, use `make build-containers`.

3. **Push to Azure Container Registry**:
   - In PowerShell, push each container:
     ```bash
     docker push infoasstcrshared.azurecr.us/webapp:latest
     docker push infoasstcrshared.azurecr.us/enrichment:latest
     docker push infoasstcrshared.azurecr.us/weaviate:latest
     docker push infoasstcrshared.azurecr.us/t2v:latest
     docker push infoasstcrshared.azurecr.us/reranker:latest
     docker push infoasstcrshared.azurecr.us/llm:latest
     ```

4. **Reinstall the Pods**:
   - In PowerShell, navigate to the charts directory and run:
     ```bash
     helm install infoasst-webapp ./infoasst-webapp --namespace infoasst --create-namespace
     helm install infoasst-enrichment ./infoasst-enrichment --namespace infoasst --create-namespace
     helm install infoasst-weaviate-container ./infoasst-weaviate-container --namespace infoasst --create-namespace
     helm install infoasst-t2v ./infoasst-t2v --namespace infoasst --create-namespace
     helm install infoasst-reranker ./infoasst-reranker --namespace infoasst --create-namespace
     helm install infoasst-llm ./infoasst-llm --namespace infoasst --create-namespace
     ```

5. **Verify the Reinstallation**:
   - Use `k9s` to confirm that all containers are running properly.

---

## Stage 3: Updating the Containers in IronBank

### Part 1: PR on Our End

1. **Submit a Pull Request (PR) in the Green Lightning Repo**:
   - Create a new PR with your changes.
   - Ensure your branch is up-to-date with the latest changes from the main branch.
   - This will initiate a build pipeline that pushes each container to our Azure Container Registry (ACR).

### Part 2: Update SHA in Container Repo

1. **Find the SHA of the Updated Container**:
   - Access the pipeline logs in Green Lightning or the CF internal ACR under the Production subscription.
   - Note the SHA of the updated container.

2. **Update the SHA in the Hardening Manifest**:
   - Edit the `hardening_manifest.yaml` file in the Platform One Container Repo.
   - Update the SHA for the container you updated.
   - Also, update the date and iteration under the tags and labels sections.
   - Commit the changes to the `addfiles` branch.

3. **Trigger the Pipeline in IronBank**:
   - This will start the pipeline process in IronBank, pushing your updated containers through the hardening process.
