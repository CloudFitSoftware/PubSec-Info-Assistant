
output "AZURE_LOCATION" {
  value = var.location
}

output "AZURE_OPENAI_SERVICE" {
  value = var.disconnectedAi ? "" : (var.useExistingAOAIService ? var.azureOpenAIServiceName : module.openaiServices.name)
}

output "AZURE_SEARCH_INDEX" {
  value = var.searchIndexName
}

output "AZURE_SEARCH_SERVICE" {
  value = var.disconnectedAi ? "" : module.searchServices[0].name
}

output "AZURE_SEARCH_SERVICE_ENDPOINT" {
  value = var.disconnectedAi ? "" : module.searchServices[0].endpoint
}

output "AZURE_STORAGE_ACCOUNT" {
  value = module.storage.name
}

output "AZURE_STORAGE_ACCOUNT_ENDPOINT" {
  value = module.storage.primary_endpoints
}

output "AZURE_STORAGE_CONTAINER" {
  value = var.contentContainerName
}

output "AZURE_STORAGE_UPLOAD_CONTAINER" {
  value = var.uploadContainerName
}

output "BACKEND_URI" {
  value = var.containerizedAppServices ? "" : module.backend[0].uri
}

output "BACKEND_NAME" {
  value = var.containerizedAppServices ? "" : module.backend[0].web_app_name
}

output "RESOURCE_GROUP_NAME" {
  value = azurerm_resource_group.rg.name
}

output "AZURE_OPENAI_CHATGPT_DEPLOYMENT" {
  value = var.chatGptDeploymentName != "" ? var.chatGptDeploymentName : var.chatGptModelName != "" ? var.chatGptModelName : "gpt-35-turbo-16k"
}

output "AZURE_OPENAI_RESOURCE_GROUP" {
  value = var.disconnectedAi ? "" : (var.useExistingAOAIService ? var.azureOpenAIResourceGroup : azurerm_resource_group.rg.name)
}

output "AZURE_FUNCTION_APP_NAME" {
  value = module.functions.function_app_name
}

output "AZURE_COSMOSDB_URL" {
  value = module.cosmosdb.CosmosDBEndpointURL
}

output "AZURE_COSMOSDB_LOG_DATABASE_NAME" {
  value = module.cosmosdb.CosmosDBLogDatabaseName
}

output "AZURE_COSMOSDB_LOG_CONTAINER_NAME" {
  value = module.cosmosdb.CosmosDBLogContainerName
}

output "AZURE_FORM_RECOGNIZER_ENDPOINT" {
  value = module.formrecognizer.formRecognizerAccountEndpoint
}

output "AZURE_BLOB_DROP_STORAGE_CONTAINER" {
  value = var.uploadContainerName
}

output "AZURE_BLOB_LOG_STORAGE_CONTAINER" {
  value = var.functionLogsContainerName
}

output "CHUNK_TARGET_SIZE" {
  value = var.chunkTargetSize
}

output "FR_API_VERSION" {
  value = var.formRecognizerApiVersion
}

output "TARGET_PAGES" {
  value = var.targetPages
}

output "ENRICHMENT_ENDPOINT" {
  value = var.disconnectedAi ? "" : module.cognitiveServices.cognitiveServiceEndpoint
}

output "ENRICHMENT_NAME" {
  value = var.disconnectedAi ? "" : module.cognitiveServices.cognitiveServicerAccountName
}

output "TARGET_TRANSLATION_LANGUAGE" {
  value = var.targetTranslationLanguage
}

output "ENABLE_DEV_CODE" {
  value = var.enableDevCode
}

output "AZURE_SUBSCRIPTION_ID" {
  value = var.subscriptionId
}

output "BLOB_STORAGE_ACCOUNT_ENDPOINT" {
  value = module.storage.primary_endpoints
}

output "EMBEDDING_VECTOR_SIZE" {
  value = var.useAzureOpenAIEmbeddings ? "1536" : var.sentenceTransformerEmbeddingVectorSize
}

output "TARGET_EMBEDDINGS_MODEL" {
  value = var.useAzureOpenAIEmbeddings ? "azure-openai_${var.azureOpenAIEmbeddingDeploymentName}" : var.sentenceTransformersModelName
}

output "AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME" {
  value = var.azureOpenAIEmbeddingDeploymentName
}

output "USE_AZURE_OPENAI_EMBEDDINGS" {
  value = var.useAzureOpenAIEmbeddings
}

output "EMBEDDING_DEPLOYMENT_NAME" {
  value = var.useAzureOpenAIEmbeddings ? var.azureOpenAIEmbeddingDeploymentName : var.sentenceTransformersModelName
}

output "ENRICHMENT_APPSERVICE_NAME" {
  value = var.containerizedAppServices ? "" : module.enrichmentApp[0].name
}

output "ENRICHMENT_APPSERVICE_URL" {
  value = var.containerizedAppServices ? "" : module.enrichmentApp[0].uri
}

output "DEPLOYMENT_KEYVAULT_NAME" {
  value = module.kvModule.keyVaultName
}

output "DEPLOYMENT_KEYVAULT_ENDPOINT" {
  value = module.kvModule.keyVaultUri
}

output "CHAT_WARNING_BANNER_TEXT" {
  value = var.chatWarningBannerText
}

output "AZURE_OPENAI_ENDPOINT" {
  value = var.disconnectedAi ? "" : (var.useExistingAOAIService ? "https://${var.azureOpenAIServiceName}.${var.azure_openai_domain}/" : module.openaiServices.endpoint)
}

output "AZURE_ENVIRONMENT" {
  value = var.azure_environment
}

output "BING_SEARCH_ENDPOINT" {
  value = var.enableWebChat ? module.bingSearch.endpoint : ""
}

output "BING_SEARCH_KEY" {
  value = var.enableWebChat ? module.bingSearch.key : ""
}

output "ENABLE_BING_SAFE_SEARCH" {
  value = var.enableBingSafeSearch
}

output "AZURE_AI_TRANSLATION_DOMAIN" {
  value = var.azure_ai_translation_domain
}

output "AZURE_AI_TEXT_ANALYTICS_DOMAIN" {
  value = var.azure_ai_text_analytics_domain
}

output "AZURE_ARM_MANAGEMENT_API" {
  value = var.azure_arm_management_api
}
output "MAX_CSV_FILE_SIZE" {
  value = var.maxCsvFileSize
}

output "RANDOM_STRING_RESULT" {
  value = random_string.random.result
}

output "AZURE_BLOB_STORAGE_ACCOUNT" {
  value = module.storage.name
}

output "AZURE_OPENAI_CHATGPT_MODEL_NAME" {
  value = var.chatGptModelName
}

output "AZURE_OPENAI_CHATGPT_MODEL_VERSION" {
  value = var.chatGptModelVersion
}
output "AZURE_OPENAI_EMBEDDINGS_MODEL_NAME" {
  value = var.azureOpenAIEmbeddingsModelName
}
output "AZURE_OPENAI_EMBEDDINGS_MODEL_VERSION" {
  value = var.azureOpenAIEmbeddingsModelVersion
}

output "AZURE_TENANT_ID" {
  value = var.tenantId
}

output "CONTAINER_REGISTRY_NAME" {
  value = var.containerizedAppServices ? module.acr[0].acrName : ""
}

output "CONTAINERIZED_APP_SERVICES" {
  value = var.containerizedAppServices
}

output "DISCONNECTED_AI" {
  value = var.disconnectedAi
}

output "AZURE_OPENAI_AUTHORITY_HOST" {
  value = var.azure_openai_authority_host
}

output "USE_SEMANTIC_RERANKER" {
  value = var.use_semantic_reranker
}

output "TOP_LEVEL_DOMAIN" {
  value = var.topLevelDomain
}

output "ENTRA_ID_CLIENT_ID" {
  value = module.entraObjects.azure_ad_web_app_client_id
}
output "ENTRA_ID_CLIENT_SECRET" {
  value     = module.entraObjects.azure_ad_web_app_secret
  sensitive = true
}

output "PUBLIC_IP_NAME" {
  value = module.PublicIP.PublicIpName
}

output "APP_DOMAIN" {
  value = var.containerizedAppServices ? "https://infoasst.${random_string.random.result}.${var.topLevelDomain}" : "https://infoasst-web-${random_string.random.result}.${var.azure_websites_domain}"
}
