Import-Module .\CopyDatabases.psm1

# CosmosDB
$SourceCosmosDBConnectionString = ''
$DestinationCosmosDBConnectionString = ''

# Cognitive search
$SourceCognitiveSearchName = ''
$SourceAdminKey = ''

$DestinationCognitiveSearchName = ''
$DestinationAdminKey = ''

# Storage account
$SourceStorageAccountName = ''
$SourceStorageAccountKey = ''

$DestinationStorageAccountName = ''
$DestinationStorageAccountKey = ''

# Function app
$SourceFunctionAppName = ''
$DestinationFunctionAppName = ''

Copy-CosmosDB -SourceConnectionString $SourceCosmosDBConnectionString `
    -DestinationConnectionString $DestinationCosmosDBConnectionString

Copy-SearchIndexes -SourceCognitiveSearchName $SourceCognitiveSearchName `
    -SourceAdminKey $SourceAdminKey `
    -SourceStorageAccountName $SourceStorageAccountName `
    -DestinationCognitiveSearchName $DestinationCognitiveSearchName `
    -DestinationAdminKey $DestinationAdminKey `
    -DestinationStorageAccountName $DestinationStorageAccountName

Copy-StorageAccount -SourceStorageAccountName $SourceStorageAccountName `
    -SourceStorageAccountKey $SourceStorageAccountKey `
    -SourceFunctionAppName $SourceFunctionAppName `
    -DestinationStorageAccountName $DestinationStorageAccountName `
    -DestinationStorageAccountKey $DestinationStorageAccountKey `
    -DestinationFunctionAppName $DestinationFunctionAppName

