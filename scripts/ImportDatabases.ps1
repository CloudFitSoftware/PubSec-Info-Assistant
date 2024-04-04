Import-Module .\ImportExportDatabases.psm1 -Force

# CosmosDB
$DestinationCosmosDBConnectionString = ''

# Cognitive search
$DestinationCognitiveSearchName = ''
$DestinationAdminKey = ''

# Storage account
$SourceStorageAccountName = ''
$DestinationStorageAccountName = ''
$DestinationStorageAccountKey = ''

# Function app
$SourceFunctionAppName = ''
$DestinationFunctionAppName = ''

Import-CosmosDB -DestinationConnectionString $DestinationCosmosDBConnectionString

Import-SearchIndexes -DestinationCognitiveSearchName $DestinationCognitiveSearchName `
    -DestinationAdminKey $DestinationAdminKey `
    -SourceStorageAccountName $SourceStorageAccountName `
    -DestinationStorageAccountName $DestinationStorageAccountName

Import-StorageAccount -SourceStorageAccountName $SourceStorageAccountName `
    -DestinationStorageAccountName $DestinationStorageAccountName `
    -DestinationStorageAccountKey $DestinationStorageAccountKey `
    -SourceFunctionAppName $SourceFunctionAppName `
    -DestinationFunctionAppName $DestinationFunctionAppName

