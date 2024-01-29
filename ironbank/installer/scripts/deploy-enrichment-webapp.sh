echo Deploy Enrichment Webapp

source "$ENV_DIR/environments/infrastructure.env"
pushd "$ENV_DIR/artifacts/build/"

# deploy the zip file to the webapp
az webapp deploy --name $ENRICHMENT_APPSERVICE_NAME --resource-group $RESOURCE_GROUP_NAME --type zip --src-path enrichment.zip --async true --timeout 600000 --verbose

echo "Enrichment Webapp deployed successfully"
echo -e "\n"

popd
