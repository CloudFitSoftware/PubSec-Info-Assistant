#!/bin/bash
set -e

echo "Build Containers"

# Get the directory that this script is in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}"/../scripts/load-env.sh
source "$DIR/../scripts/environments/infrastructure.env"
BINARIES_OUTPUT_PATH="${DIR}/../artifacts/build/"
DOCKER_DIR="${DIR}/../docker"

cp "${BINARIES_OUTPUT_PATH}"/webapp.zip "${DOCKER_DIR}"/webapp.zip
cp "${BINARIES_OUTPUT_PATH}"/functions.zip "${DOCKER_DIR}"/functions.zip
cp "${BINARIES_OUTPUT_PATH}"/enrichment.zip "${DOCKER_DIR}"/enrichment.zip

cd "${DOCKER_DIR}"

unzip -d webapp/ webapp.zip
unzip -d functions/ functions.zip
unzip -d enrichment/ enrichment.zip

CONTAINER_REGISTRY_NAME=$(jq -r '.CONTAINER_REGISTRY_NAME.value' ../inf_output.json)

if [ -n "${CONTAINER_REGISTRY_NAME}" ]; then
    docker build -t "${CONTAINER_REGISTRY_NAME}".azurecr.us/webapp:latest -f Dockerfile.webapp .
    docker build -t "${CONTAINER_REGISTRY_NAME}".azurecr.us/function:latest -f Dockerfile.functions .
    docker build -t "${CONTAINER_REGISTRY_NAME}".azurecr.us/enrichment:latest -f Dockerfile.enrichment .
    docker build -t "${CONTAINER_REGISTRY_NAME}".azurecr.us/weaviate:latest -f Dockerfile.weaviate .
    docker build -t "${CONTAINER_REGISTRY_NAME}".azurecr.us/t2v:latest -f Dockerfile.t2v-transformers .
    docker build -t "${CONTAINER_REGISTRY_NAME}".azurecr.us/reranker:latest -f Dockerfile.reranker-transformers .
else
    docker build -t webapp:latest -f Dockerfile.webapp .
    docker build -t function:latest -f Dockerfile.functions .
    docker build -t enrichment:latest -f Dockerfile.enrichment .
    docker build -t weaviate:latest -f Dockerfile.weaviate .
    docker build -t t2v:latest -f Dockerfile.t2v-transformers .
    docker build -t reranker:latest -f Dockerfile.reranker-transformers .
fi

rm -rf ./webapp/
rm -rf ./functions/
rm -rf ./enrichment/
rm ./webapp.zip
rm ./functions.zip
rm ./enrichment.zip
