echo Deploy Webapp

source "$ENV_DIR/environments/infrastructure.env"
pushd "$ENV_DIR/artifacts/build/"

# deploy the zip file to the webapp
az webapp deploy --name $AZURE_WEBAPP_NAME --resource-group $RESOURCE_GROUP_NAME --type zip --src-path webapp.zip --async true --timeout 600000 --verbose

echo "Webapp deployed successfully"

popd
