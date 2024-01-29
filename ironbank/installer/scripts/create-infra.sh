
printInfo() {
    printf "$YELLOW\n%s$RESET\n" "$1"
}

echo "Infrastructure"

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

if [ -n "${IS_USGOV_DEPLOYMENT}" ] && $IS_USGOV_DEPLOYMENT; then
  WEB_APP_ENDPOINT_SUFFIX="azurewebsites.us"
fi

if [ -n "${IS_USGOV_DEPLOYMENT}" ] && $IS_USGOV_DEPLOYMENT && ! $USE_EXISTING_AOAI; then
  echo "AOAI doesn't exist in US Gov regions.  Please create AOAI seperately and update the USE_EXISTING_AOAI in the env file. "
  exit 1  
fi

randomString="${randomString,,}"
export RANDOM_STRING=$randomString

echo -e "\n" 
echo "Setting up Azure AD App Registration and Service Principal for your environment"

signedInUserId=$(az ad signed-in-user show --query id --output tsv)
kvAccessObjectId=$signedInUserId
#if not in automation, create the app registration and service principal values
#set up azure ad app registration since there is no bicep support for this yet
aadWebAppId=$(az ad app list --display-name infoasst_web_access_$RANDOM_STRING --output tsv --query [].appId)
if [ -z $aadWebAppId ]
then
    aadWebAppId=$(az ad app create --display-name infoasst_web_access_$RANDOM_STRING --sign-in-audience AzureADMyOrg --identifier-uris "api://infoasst-$RANDOM_STRING" --web-redirect-uris "https://infoasst-web-$RANDOM_STRING.$WEB_APP_ENDPOINT_SUFFIX/.auth/login/aad/callback" --enable-access-token-issuance true --enable-id-token-issuance true --output tsv --query "[].appId")
    aadWebAppId=$(az ad app list --display-name infoasst_web_access_$RANDOM_STRING --output tsv --query [].appId)
fi

aadWebSPId=$(az ad sp list --display-name infoasst_web_access_$RANDOM_STRING --output tsv --query "[].id")
if [ -z $aadWebSPId ]; then
    aadWebSPId=$(az ad sp create --id $aadWebAppId --output tsv --query "[].id")
    aadWebSPId=$(az ad sp list --display-name infoasst_web_access_$RANDOM_STRING --output tsv --query "[].id")
fi

aadMgmtAppId=$(az ad app list --display-name infoasst_mgmt_access_$RANDOM_STRING --output tsv --query [].appId)
if [ -z $aadMgmtAppId ]
then
    aadMgmtAppId=$(az ad app create --display-name infoasst_mgmt_access_$RANDOM_STRING --sign-in-audience AzureADMyOrg --output tsv --query "[].appId")
    aadMgmtAppId=$(az ad app list --display-name infoasst_mgmt_access_$RANDOM_STRING --output tsv --query [].appId)
fi
aadMgmtAppSecret=$(az ad app credential reset --id $aadMgmtAppId --display-name infoasst-mgmt --output tsv --query password)

aadMgmtSPId=$(az ad sp list --display-name infoasst_mgmt_access_$RANDOM_STRING --output tsv --query "[].id")
if [ -z $aadMgmtSPId ]; then
    aadMgmtSPId=$(az ad sp create --id $aadMgmtAppId --output tsv --query "[].id")
    aadMgmtSPId=$(az ad sp list --display-name infoasst_mgmt_access_$RANDOM_STRING --output tsv --query "[].id")
fi

if [ $REQUIRE_WEBSITE_SECURITY_MEMBERSHIP ]; then
# if the REQUIRE_WEBSITE_SECURITY_MEMBERSHIP is set to true, then we need to update the app registration to require assignment
az ad sp update --id $aadWebSPId --set "appRoleAssignmentRequired=true"
else
# otherwise the default is to allow all users in the tenant to access the app
az ad sp update --id $aadWebSPId --set "appRoleAssignmentRequired=false"
fi


export SINGED_IN_USER_PRINCIPAL=$signedInUserId
export AZURE_AD_WEB_APP_CLIENT_ID=$aadWebAppId
export AZURE_AD_MGMT_APP_CLIENT_ID=$aadMgmtAppId
export AZURE_AD_MGMT_SP_ID=$aadMgmtSPId
export AZURE_AD_MGMT_APP_SECRET=$aadMgmtAppSecret
export AZURE_KV_ACCESS_OBJ_ID=$kvAccessObjectId

if [ -n "${IN_AUTOMATION}" ]; then 
  export IS_IN_AUTOMATION=true 
else 
  export IS_IN_AUTOMATION=false
fi

#set up parameter file
declare -A REPLACE_TOKENS=(
    [\${WORKSPACE}]=${WORKSPACE}
    [\${LOCATION}]=${LOCATION}
    [\${ENABLE_CUSTOMER_USAGE_ATTRIBUTION}]=${ENABLE_CUSTOMER_USAGE_ATTRIBUTION}
    [\${CUSTOMER_USAGE_ATTRIBUTION_ID}]=${CUSTOMER_USAGE_ATTRIBUTION_ID}
    [\${SINGED_IN_USER_PRINCIPAL}]=${SINGED_IN_USER_PRINCIPAL}
    [\${RANDOM_STRING}]=${RANDOM_STRING}
    [\${AZURE_OPENAI_SERVICE_NAME}]=${AZURE_OPENAI_SERVICE_NAME}
    [\${AZURE_OPENAI_RESOURCE_GROUP}]=${AZURE_OPENAI_RESOURCE_GROUP}
    [\${CHATGPT_MODEL_DEPLOYMENT_NAME}]=${AZURE_OPENAI_CHATGPT_DEPLOYMENT}
    [\${AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME}]=${AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME}
    [\${AZURE_OPENAI_EMBEDDINGS_MODEL_NAME}]=${AZURE_OPENAI_EMBEDDINGS_MODEL_NAME}
    [\${AZURE_OPENAI_EMBEDDINGS_MODEL_VERSION}]=${AZURE_OPENAI_EMBEDDINGS_MODEL_VERSION}
    [\${CHATGPT_MODEL_MODEL_NAME}]=${AZURE_OPENAI_CHATGPT_MODEL_NAME}
    [\${CHATGPT_MODEL_VERSION}]=${AZURE_OPENAI_CHATGPT_MODEL_VERSION}
    [\${CHATGPT_MODEL_CAPACITY}]=${AZURE_OPENAI_CHATGPT_MODEL_CAPACITY}
    [\${USE_EXISTING_AOAI}]=${USE_EXISTING_AOAI}
    [\${AZURE_OPENAI_SERVICE_KEY}]=${AZURE_OPENAI_SERVICE_KEY}
    [\${BUILD_NUMBER}]=${BUILD_NUMBER}
    [\${AZURE_AD_WEB_APP_CLIENT_ID}]=${AZURE_AD_WEB_APP_CLIENT_ID}
    [\${AZURE_AD_MGMT_APP_CLIENT_ID}]=${AZURE_AD_MGMT_APP_CLIENT_ID}
    [\${AZURE_AD_MGMT_SP_ID}]=${AZURE_AD_MGMT_SP_ID}
    [\${IS_IN_AUTOMATION}]=${IS_IN_AUTOMATION}
    [\${QUERYTERM_LANGUAGE}]=${PROMPT_QUERYTERM_LANGUAGE}
    [\${TARGET_TRANSLATION_LANGUAGE}]=${TARGET_TRANSLATION_LANGUAGE}
    [\${ENABLE_DEV_CODE}]=${ENABLE_DEV_CODE}
    [\${TENANT_ID}]=${TENANT_ID}
    [\${SUBSCRIPTION_ID}]=${SUBSCRIPTION_ID}
    [\${AZURE_AD_MGMT_APP_SECRET}]=${AZURE_AD_MGMT_APP_SECRET}
    [\${CHAT_WARNING_BANNER_TEXT}]=${CHAT_WARNING_BANNER_TEXT}
    [\${USE_AZURE_OPENAI_EMBEDDINGS}]=${USE_AZURE_OPENAI_EMBEDDINGS}
    [\${OPEN_SOURCE_EMBEDDING_MODEL_VECTOR_SIZE}]=${OPEN_SOURCE_EMBEDDING_MODEL_VECTOR_SIZE}
    [\${OPEN_SOURCE_EMBEDDING_MODEL}]=${OPEN_SOURCE_EMBEDDING_MODEL}
    [\${APPLICATION_TITLE}]=${APPLICATION_TITLE}
    [\${AZURE_KV_ACCESS_OBJ_ID}]=${AZURE_KV_ACCESS_OBJ_ID}
)
parameter_json=$(cat "$ENV_DIR/infra/main.parameters.json.template")
for token in "${!REPLACE_TOKENS[@]}"
do
  parameter_json="${parameter_json//"$token"/"${REPLACE_TOKENS[$token]}"}"
done
echo $parameter_json > $ENV_DIR/infra/main.parameters.json

pushd "$ENV_DIR/infra"
#make sure bicep is always the latest version
az bicep upgrade

#deploy bicep
az deployment sub what-if --location $LOCATION --template-file main.bicep --parameters main.parameters.json --name $RG_NAME
if [ -z $SKIP_PLAN_CHECK ]
    then
        printInfo "Are you happy with the plan, would you like to apply? (y/N)"
        read -r answer
        answer=${answer^^}
        
        if [[ "$answer" != "Y" ]];
        then
            printInfo "Exiting: User did not wish to apply infrastructure changes." 
            exit 1
        fi
    fi
results=$(az deployment sub create --location $LOCATION --template-file main.bicep --parameters main.parameters.json --name $RG_NAME)

#save deployment output
printInfo "Writing output to infra_output.json"
popd
echo $results > infra_output.json
