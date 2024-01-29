echo Deploy Functions

source "$ENV_DIR/environments/infrastructure.env"
pushd "$ENV_DIR/artifacts/build/"

# deploy the zip file to the webapp
az functionapp deploy --resource-group $RESOURCE_GROUP_NAME --name $AZURE_FUNCTION_APP_NAME --src-path functions.zip --type zip --async true --verbose

# Restart the Azure Functions after deployment
az functionapp restart --name $AZURE_FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP_NAME

echo "Functions deployed successfully"

popd
