Import-Module .\ImportExportDatabases.psm1 -Force

# CosmosDB
$SourceCosmosDBConnectionString = ''

# Cognitive search
$SourceCognitiveSearchName = ''
$SourceAdminKey = ''

# Storage account
$SourceStorageAccountName = ''
$SourceStorageAccountKey = ''

# Function app
$SourceFunctionAppName = ''

Export-CosmosDB -SourceConnectionString $SourceCosmosDBConnectionString

Export-SearchIndexes -SourceCognitiveSearchName $SourceCognitiveSearchName `
    -SourceAdminKey $SourceAdminKey

Export-StorageAccount -SourceStorageAccountName $SourceStorageAccountName `
    -SourceStorageAccountKey $SourceStorageAccountKey `
    -SourceFunctionAppName $SourceFunctionAppName

