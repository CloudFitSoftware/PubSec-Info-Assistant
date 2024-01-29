#!/bin/bash

az cloud set -n AzureUSGovernment
az login --use-device-code

export ENV_DIR=$(pwd)

# Set local environment variables
source set-env.sh

az account set -s $SUBSCRIPTION_ID

# Checking subscription
source check-subscription.sh

# Create Azure Infrastructure
source create-infra.sh

# Extract azure environment details
source json-to-env.sh < infra_output.json > ./environments/infrastructure.env

# Deploy Enrichment Webapp
source deploy-enrichment-webapp.sh

# Deploy Search Indexes
source deploy-search-indexes.sh

# Deploy Webapp
source deploy-webapp.sh

# Deploy Azure Functions
source deploy-functions.sh

echo Deployment complete!
