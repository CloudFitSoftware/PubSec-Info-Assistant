Import-Module .\ImportExportDatabases.psm1 -Force

$DocumentName = 'MyDocument.txt'

# CosmosDB
$CosmosDBConnectionString = ''

# Cognitive search
$CognitiveSearchName = ''
$AdminKey = ''

# Storage account
$StorageAccountName = ''
$StorageAccountKey = ''

Remove-Document -DocumentName $DocumentName -CosmosDBConnectionString $CosmosDBConnectionString -CognitiveSearchName $CognitiveSearchName `
    -CognitiveSearchAdminKey $AdminKey -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

