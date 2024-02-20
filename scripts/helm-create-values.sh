set -e

printInfo() {
    printf "$YELLOW\n%s$RESET\n" "$1"
}

# Get the directory that this script is in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/load-env.sh"
pushd "$DIR/../infra" > /dev/null

echo -e "\n" 

echo "Setting up random.txt file for your environment"

#set up variables for the bicep deployment
#get or create the random.txt from local file system
if [ -f ".state/${WORKSPACE}/random.txt" ]; then
  randomString=$(cat .state/${WORKSPACE}/random.txt)
else  
  randomString=$(mktemp --dry-run XXXXX)
  mkdir -p .state/${WORKSPACE}
  echo $randomString >> .state/${WORKSPACE}/random.txt
fi

WEB_APP_ENDPOINT_SUFFIX="azurewebsites.net"

if [ -n "${IS_USGOV_DEPLOYMENT}" ] && $IS_USGOV_DEPLOYMENT; then
  WEB_APP_ENDPOINT_SUFFIX="azurewebsites.us"
fi

if [ -n "${IN_AUTOMATION}" ]; then
  #if in automation, add the random.txt to the state container
  #echo "az storage blob exists --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_ACCOUNT_KEY --container-name state --name ${WORKSPACE}.random.txt --output tsv --query exists"
  exists=$(az storage blob exists --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_ACCOUNT_KEY --container-name state --name ${WORKSPACE}.random.txt --output tsv --query exists)
  #echo "exists: $exists"
  if [ $exists == "true" ]; then
    #echo "az storage blob download --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_ACCOUNT_KEY --container-name state --name ${WORKSPACE}.random.txt --query content --output tsv"
    randomString=$(az storage blob download --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_ACCOUNT_KEY --container-name state --name ${WORKSPACE}.random.txt --query content --output tsv)
    rm .state/${WORKSPACE}/random.txt
    echo $randomString >> .state/${WORKSPACE}/random.txt
  else
    #echo "az storage blob upload --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_ACCOUNT_KEY --container-name state --name ${WORKSPACE}.random.txt --file .state/${WORKSPACE}/random.txt"
    upload=$(az storage blob upload --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_ACCOUNT_KEY --container-name state --name ${WORKSPACE}.random.txt --file .state/${WORKSPACE}/random.txt)
  fi
fi
randomString="${randomString,,}"
export RANDOM_STRING=$randomString

popd

jq -r  '
    .properties.outputs |
    [
        {
            "path": "applicationinsightS_CONNECTION_STRING",
            "env_var": "APPLICATIONINSIGHTS_CONNECTION_STRING"
        },
        {
            "path": "azurE_LOCATION",
            "env_var": "LOCATION"
        },
        {
            "path": "azurE_SEARCH_INDEX",
            "env_var": "AZURE_SEARCH_INDEX"
        },
        {
            "path": "azurE_SEARCH_SERVICE",
            "env_var": "AZURE_SEARCH_SERVICE"
        },
        {
            "path": "azurE_SEARCH_SERVICE_ENDPOINT",
            "env_var": "AZURE_SEARCH_SERVICE_ENDPOINT"
        },
        {
            "path": "azurE_STORAGE_ACCOUNT",
            "env_var": "AZURE_BLOB_STORAGE_ACCOUNT"
        },
        {
            "path": "azurE_STORAGE_CONTAINER",
            "env_var": "AZURE_BLOB_STORAGE_CONTAINER"
        },
        {
            "path": "azurE_OPENAI_SERVICE",
            "env_var": "AZURE_OPENAI_SERVICE"
        },
        {
            "path": "backenD_URI",
            "env_var": "AZURE_WEBAPP_URI"
        },
        {
            "path": "backenD_NAME",
            "env_var": "AZURE_WEBAPP_NAME"
        },
        {
            "path": "resourcE_GROUP_NAME",
            "env_var": "RESOURCE_GROUP_NAME"
        },
        {
            "path": "azurE_OPENAI_CHAT_GPT_DEPLOYMENT",
            "env_var": "AZURE_OPENAI_CHATGPT_DEPLOYMENT"
        },
        {
            "path": "azurE_OPENAI_EMBEDDING_DEPLOYMENT_NAME",
            "env_var": "AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME"
        },       
        {
            "path": "azurE_FUNCTION_APP_NAME",
            "env_var": "AZURE_FUNCTION_APP_NAME"
        },
        {
            "path": "containeR_REGISTRY_NAME",
            "env_var": "CONTAINER_REGISTRY_NAME"
        },
        {
            "path": "containeR_APP_SERVICE",
            "env_var": "CONTAINER_APP_SERVICE"
        },
        {
            "path": "embeddingsqueue",
            "env_var": "EMBEDDINGS_QUEUE"
        },
        {
            "path": "azurE_STORAGE_CONTAINER",
            "env_var": "AZURE_STORAGE_CONTAINER"
        },      
        {
            "path": "targeT_EMBEDDINGS_MODEL",
            "env_var": "TARGET_EMBEDDINGS_MODEL"
        },
        {
            "path": "azurE_COSMOSDB_URL",
            "env_var": "COSMOSDB_URL"
        },
        {
            "path": "azurE_COSMOSDB_LOG_DATABASE_NAME",
            "env_var": "COSMOSDB_LOG_DATABASE_NAME"
        },
        {
            "path": "azurE_COSMOSDB_LOG_CONTAINER_NAME",
            "env_var": "COSMOSDB_LOG_CONTAINER_NAME"
        },
        {
            "path": "azurE_COSMOSDB_TAGS_CONTAINER_NAME",
            "env_var": "COSMOSDB_TAGS_CONTAINER_NAME"
        },
        {
            "path": "azurE_COSMOSDB_TAGS_DATABASE_NAME",
            "env_var": "COSMOSDB_TAGS_DATABASE_NAME"
        },
        {
            "path": "azurE_OPENAI_RESOURCE_GROUP",
            "env_var": "AZURE_OPENAI_RESOURCE_GROUP"
        },
        {
            "path": "embeddinG_VECTOR_SIZE",
            "env_var": "EMBEDDING_VECTOR_SIZE"
        },       
        {
            "path": "iS_USGOV_DEPLOYMENT",
            "env_var": "IS_USGOV_DEPLOYMENT"
        },
        {
            "path": "bloB_STORAGE_ACCOUNT_ENDPOINT",
            "env_var": "BLOB_STORAGE_ACCOUNT_ENDPOINT"
        },
        {
            "path": "enrichmenT_APPSERVICE_NAME",
            "env_var": "ENRICHMENT_APPSERVICE_NAME"
        },
        {
            "path": "deploymenT_KEYVAULT_NAME",
            "env_var": "DEPLOYMENT_KEYVAULT_NAME"
        }
    ]
        as $env_vars_to_extract
    |
    with_entries(
        select (
            .key as $a
            |
            any( $env_vars_to_extract[]; .path == $a)
        )
        |
        .key |= . as $old_key | ($env_vars_to_extract[] | select (.path == $old_key) | .env_var)
    )
    |
    to_entries
    | 
    map("export \(.key)=\"\(.value.value)\"")
    |
    .[]
    ' | sed "s/\"/'/g" > temp.sh # replace double quote with single quote to handle special chars

source ./temp.sh

declare -A REPLACE_TOKENS=(
    [\${APPLICATIONINSIGHTS_CONNECTION_STRING}]=${APPLICATIONINSIGHTS_CONNECTION_STRING}
    [\${AZURE_BLOB_STORAGE_ACCOUNT}]=${AZURE_BLOB_STORAGE_ACCOUNT}
    [\${AZURE_OPENAI_CHATGPT_DEPLOYMENT}]=${AZURE_OPENAI_CHATGPT_DEPLOYMENT}
    [\${AZURE_OPENAI_CHATGPT_MODEL_NAME}]=${AZURE_OPENAI_CHATGPT_MODEL_NAME}
    [\${AZURE_OPENAI_CHATGPT_MODEL_VERSION}]=${AZURE_OPENAI_CHATGPT_MODEL_VERSION}
    [\${AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME}]=${AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME}
    [\${AZURE_OPENAI_EMBEDDINGS_MODEL_NAME}]=${AZURE_OPENAI_EMBEDDINGS_MODEL_NAME}
    [\${AZURE_OPENAI_EMBEDDINGS_MODEL_VERSION}]=${AZURE_OPENAI_EMBEDDINGS_MODEL_VERSION}
    [\${AZURE_OPENAI_RESOURCE_GROUP}]=${AZURE_OPENAI_RESOURCE_GROUP}
    [\${AZURE_OPENAI_SERVICE}]=${AZURE_OPENAI_SERVICE}
    [\${AZURE_SEARCH_SERVICE}]=${AZURE_SEARCH_SERVICE}
    [\${AZURE_SEARCH_SERVICE_ENDPOINT}]=${AZURE_SEARCH_SERVICE_ENDPOINT}
    [\${BLOB_STORAGE_ACCOUNT_ENDPOINT}]=${BLOB_STORAGE_ACCOUNT_ENDPOINT}
    [\${CHAT_WARNING_BANNER_TEXT}]=${CHAT_WARNING_BANNER_TEXT}
    [\${CONTAINER_REGISTRY_NAME}]=${CONTAINER_REGISTRY_NAME}
    [\${COSMOSDB_LOG_CONTAINER_NAME}]=${COSMOSDB_LOG_CONTAINER_NAME}
    [\${COSMOSDB_LOG_DATABASE_NAME}]=${COSMOSDB_LOG_DATABASE_NAME}
    [\${COSMOSDB_TAGS_CONTAINER_NAME}]=${COSMOSDB_TAGS_CONTAINER_NAME}
    [\${COSMOSDB_TAGS_DATABASE_NAME}]=${COSMOSDB_TAGS_DATABASE_NAME}
    [\${COSMOSDB_URL}]=${COSMOSDB_URL}
    [\${DEPLOYMENT_KEYVAULT_NAME}]=${DEPLOYMENT_KEYVAULT_NAME}
    [\${ENRICHMENT_APPSERVICE_NAME}]=${ENRICHMENT_APPSERVICE_NAME}
    [\${IS_CONTAINERIZED_DEPLOYMENT}]=${IS_CONTAINERIZED_DEPLOYMENT}
    [\${IS_GOV_CLOUD_DEPLOYMENT}]=${IS_USGOV_DEPLOYMENT}
    [\${IS_USGOV_DEPLOYMENT}]=${IS_USGOV_DEPLOYMENT}
    [\${PROMPT_QUERYTERM_LANGUAGE}]=${PROMPT_QUERYTERM_LANGUAGE}
    [\${SUBSCRIPTION_ID}]=${SUBSCRIPTION_ID}
    [\${TARGET_EMBEDDINGS_MODEL}]=${TARGET_EMBEDDINGS_MODEL}
    [\${TENANT_ID}]=${TENANT_ID}
    [\${USE_AZURE_OPENAI_EMBEDDINGS}]=${USE_AZURE_OPENAI_EMBEDDINGS}
)

CHARTS_DIR="$DIR/../charts"

if [ -d "$CHARTS_DIR" ]; then
    for chart_dir in "$CHARTS_DIR"/*; do
        if [ -d "$chart_dir" ]; then 
            echo "Processing chart directory: $chart_dir"
            parameter_json=$(cat "$chart_dir/values.yaml.template")
            for token in "${!REPLACE_TOKENS[@]}"
            do
              parameter_json="${parameter_json//"$token"/"${REPLACE_TOKENS[$token]}"}"
            done
            echo "$parameter_json" > "$chart_dir/values.yaml"
        fi
    done
else
    echo "Charts directory not found: $CHARTS_DIR"
fi

rm ./temp.sh
