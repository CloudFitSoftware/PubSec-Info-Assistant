if (-not (Get-Module -ListAvailable CosmosDB)) {
    Write-Warning 'You must install CosmosDB PowerShell module before using this module.  Install-Module CosmosDB'
}

if (-not (Get-Module -ListAvailable Az.Storage)) {
    Write-Warning 'You must install Az.Storage PowerShell module before using this module.  Install-Module Az.Storage'
}

Import-Module CosmosDB
Import-Module Az.Storage

<#
.SYNOPSIS
Copies file processing status data between two CosmosDB databases

.DESCRIPTION
Copies file processing status data between two CosmosDB databases

.PARAMETER SourceConnectionString
The connection string to the source CosmosDB database

.PARAMETER DestinationConnectionString
The connection string to the destination CosmosDB database

.EXAMPLE
Copy-CosmosDB -SourceConnectionString <source connection string> `
    -DestinationConnectionString <destination connection string>
#>
function Copy-CosmosDB() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SourceConnectionString,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationConnectionString
    )

    Write-Host "Entering Copy-CosmosDB"

    try {
        $DatabaseName = 'statusdb'
        $ContainerName = 'statuscontainer'

        $SourceContext = New-CosmosDbContext -ConnectionString ($SourceConnectionString | ConvertTo-SecureString -AsPlainText -Force) -Database $DatabaseName -Environment AzureUSGovernment
        $DestinationContext = New-CosmosDbContext -ConnectionString ($DestinationConnectionString | ConvertTo-SecureString -AsPlainText -Force) -Database $DatabaseName -Environment AzureUSGovernment

        Write-Host "Downloading documents from source"
        $DocumentsPerRequest = 20
        $ContinuationToken = $null
        $Documents = $null
        
        do {
            $ResponseHeader = $null
            $GetCosmosDbDocumentParameters = @{
                Context        = $SourceContext
                CollectionId   = $ContainerName
                MaxItemCount   = $DocumentsPerRequest
                ResponseHeader = ([ref] $ResponseHeader)
            }
        
            if ($ContinuationToken) {
                $GetCosmosDbDocumentParameters.ContinuationToken = $ContinuationToken
            }
        
            $Documents += Get-CosmosDbDocument @getCosmosDbDocumentParameters
            $ContinuationToken = Get-CosmosDbContinuationToken -ResponseHeader $ResponseHeader
        } while (-not [System.String]::IsNullOrEmpty($ContinuationToken))

        Write-Host "Downloaded $($Documents.Count) documents"

        Write-Host "Uploading documents to destination"
        foreach ($Document in $Documents) {
            $NewCosmosDbDocumentParameters = @{
                Context      = $DestinationContext
                CollectionId = $ContainerName
                DocumentBody = @{
                    id                = $Document.id
                    file_path         = $Document.file_path
                    file_name         = $Document.file_name
                    state             = $Document.state
                    start_timestamp   = $Document.start_timestamp
                    state_description = $Document.state_description
                    state_timestamp   = $Document.state_timestamp
                    status_updates    = $Document.status_updates
                } | ConvertTo-Json
                PartitionKey = $Document.file_name
                Upsert       = $true
            }

            New-CosmosDbDocument @NewCosmosDbDocumentParameters
        }
    }
    catch {
        Write-Host "Error thrown in Copy-CosmosDB" -ForegroundColor Red
        throw
    }

    Write-Host "Exiting Copy-CosmosDB"
}

<#
.SYNOPSIS
Copies the search index between two Azure Cognitive Search services

.DESCRIPTION
Copies the search index between two Azure Cognitive Search services

.PARAMETER SourceCognitiveSearchName
The name of the source Azure Cognitive Search service

.PARAMETER SourceAdminKey
The admin key of the source Azure Cognitive Search service

.PARAMETER SourceStorageAccountName
The name of the source Azure Storage account

.PARAMETER DestinationCognitiveSearchName
The name of the destination Azure Cognitive Search service

.PARAMETER DestinationAdminKey
The admin key of the destination Azure Cognitive Search service

.PARAMETER DestinationStorageAccountName
The name of the destination Azure Storage account

.EXAMPLE
Copy-SearchIndexes -SourceCognitiveSearchName <source cognitive search name> `
    -SourceAdminKey <source admin key> `
    -SourceStorageAccountName <source storage account name> `
    -DestinationCognitiveSearchName <destination cognitive search name> `
    -DestinationAdminKey <destination admin key> `
    -DestinationStorageAccountName <destination storage account name>

.NOTES
The indexes contain references to the indexed content in the storage account which are updated during the copy process.
#>
function Copy-SearchIndexes() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SourceCognitiveSearchName,
        [Parameter(Mandatory = $true)]
        [string]
        $SourceAdminKey,
        [Parameter(Mandatory = $true)]
        [string]
        $SourceStorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationCognitiveSearchName,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationAdminKey,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationStorageAccountName
    )

    Write-Host "Entering Copy-SearchIndexes"

    try {
        $IndexName = 'all-files-index'
        $SourceServiceUrl = "https://$SourceCognitiveSearchName.search.azure.us"
        $DestinationServiceUrl = "https://$DestinationCognitiveSearchName.search.azure.us"

        $SourceHeaders = @{
            'api-key' = $SourceAdminKey
        }
        $DestinationHeaders = @{
            'api-key' = $DestinationAdminKey
        }

        Write-Host "Getting count of indexed documents from source"

        $Response = Invoke-WebRequest -Uri "$SourceServiceUrl/indexes/$IndexName/docs/`$count?api-version=2020-06-30" `
            -Method Get -Headers $SourceHeaders -ContentType 'application/json'

        # The server is returning a BOM in the response for some reason.  These two lines will convert it to an integer.
        $ContentDecodedAsUtf8 = [Text.Encoding]::UTF8.GetString($Response.RawContentStream.ToArray())
        $Count = [int]::Parse($ContentDecodedAsUtf8.Substring(1))

        Write-Host "Index contains $Count documents"

        $BatchSize = 500
        $BatchCount = [math]::Ceiling($Count / $BatchSize)
        Write-Host "Downloading indexed documents in $BatchCount batches of $BatchSize from source"
        for ($i = 0; $i -lt $BatchCount; $i++) {
            Write-Host "Downloading source batch $i"

            $Skip = $i * $BatchSize
            $Response = Invoke-RestMethod -Uri "$SourceServiceUrl/indexes/$IndexName/docs/?api-version=2020-06-30&search=*&searchMode=all&`$skip=$Skip&`$top=$BatchSize" `
                -Method Get -Headers $SourceHeaders -ContentType 'application/json'
            
            # Replace embedded urls
            $Json = $Response | ConvertTo-Json -Depth 100
            $Json = $Json -replace $SourceStorageAccountName, $DestinationStorageAccountName

            Write-Host "Uploading destination batch $i"

            Invoke-RestMethod -Uri "$DestinationServiceUrl/indexes/$IndexName/docs/index?api-version=2020-06-30" `
                -Method Post -Body $Json -Headers $DestinationHeaders -ContentType "application/json; charset=utf-8"
        }
    }
    catch {
        Write-Host "Error thrown in Copy-SearchIndexes" -ForegroundColor Red
        throw
    }

    Write-Host "Exiting Copy-SearchIndexes"
}

<#
.SYNOPSIS
Copies blobs receipts, indexed content, logs and original documents between two Azure Storage accounts.

.DESCRIPTION
Copies blobs receipts, indexed content, logs and original documents between two Azure Storage accounts.

.PARAMETER SourceStorageAccountName
The name of the source Azure Storage account

.PARAMETER SourceStorageAccountKey
The master key of the source Azure Storage account

.PARAMETER SourceFunctionAppName
The name of the source Azure Function application

.PARAMETER DestinationStorageAccountName
The name of the destination Azure Storage account

.PARAMETER DestinationStorageAccountKey
The master key of the destination Azure Storage account

.PARAMETER DestinationFunctionAppName
The name of the destination Azure Function application

.EXAMPLE
Copy-StorageAccount -SourceStorageAccountName <source storage account name> `
    -SourceStorageAccountKey <source storage account key> `
    -SourceFunctionAppName <source function app name> `
    -DestinationStorageAccountName <destination storage account name> `
    -DestinationStorageAccountKey <destination storage account key> `
    -DestinationFunctionAppName <destination function app name>

.NOTES
Blob receipts reference the Azure Function application that created them.  They are updated during the copy process.

Indexed content and logs contain references to the indexed content in the storage account which are updated during the copy process.
#>
function Copy-StorageAccount() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SourceStorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $SourceStorageAccountKey,
        [Parameter(Mandatory = $true)]
        [string]
        $SourceFunctionAppName,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationStorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationStorageAccountKey,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationFunctionAppName
    )

    Write-Host "Entering Copy-StorageAccount"

    try {
        $SourceContext = New-AzStorageContext -StorageAccountName $SourceStorageAccountName -StorageAccountKey $SourceStorageAccountKey -Environment AzureUSGovernment
        $DestinationContext = New-AzStorageContext -StorageAccountName $DestinationStorageAccountName -StorageAccountKey $DestinationStorageAccountKey -Environment AzureUSGovernment

        $ContainerNames = @('azure-webjobs-hosts', 'content', 'logs', 'upload')

        foreach ($ContainerName in $ContainerNames) {
            Write-Host "Creating $ContainerName container in destination"
            $DestinationContainer = Get-AzStorageContainer -Context $DestinationContext | Where-Object { $_.Name -eq $ContainerName }
            if (-not $DestinationContainer) {
                $DestinationContainer = New-AzStorageContainer -Context $DestinationContext -Name $ContainerName
            }

            Write-Host "Getting list of blobs from $ContainerName container from source"
            $SourceBlobs = Get-AzStorageBlob -Context $SourceContext -Container $ContainerName
            
            Write-Host "Found $($SourceBlobs.Count) blobs"
    
            Write-Host "Transferring blobs between storage accounts"
            foreach ($SourceBlob in $SourceBlobs) {
                if ($ContainerName -eq 'azure-webjobs-hosts' -and $SourceBlob.Name -notlike 'blobreceipts*') {
                    continue
                }
                
                $Name = $SourceBlob.Name -replace $SourceFunctionAppName, $DestinationFunctionAppName

                $DestinationBlob = $DestinationContainer.CloudBlobContainer.GetBlockBlobReference($Name)

                if ($ContainerName -eq 'upload') {
                    $Stream = $SourceBlob.ICloudBlob.OpenRead()
                    $DestinationBlob.UploadFromStream($Stream, $Stream.Length)
                }
                else {
                    $Text = $SourceBlob.ICloudBlob.DownloadText()
                    $Text = $Text -replace $SourceStorageAccountName, $DestinationStorageAccountName
                    $DestinationBlob.UploadText($Text)
                }
            }

            # Add blob receipts for all files in upload container so that they don't get reprocessed.
            Write-Host "Adding blob receipts for all files in upload container"
            $AzureWebjobsHostsContainer = Get-AzStorageContainer -Context $DestinationContext | Where-Object { $_.Name -eq 'azure-webjobs-hosts' }
            $UploadBlobs = Get-AzStorageBlob -Context $DestinationContext -Container 'upload'

            foreach ($UploadBlob in $UploadBlobs) {
                $ETag = $UploadBlob.BlobProperties.ETag

                $ReceiptName = "blobreceipts/$DestinationFunctionAppName/Host.Functions.FileUploadedFunc/$ETag/upload/$($UploadBlob.Name)"

                $DestinationBlob = $AzureWebjobsHostsContainer.CloudBlobContainer.GetBlockBlobReference($ReceiptName)

                $DestinationBlob.UploadText('')
            }
        }
    }
    catch {
        Write-Host "Error thrown in Copy-StorageAccount" -ForegroundColor Red
        throw
    }

    Write-Host "Exiting Copy-StorageAccount"
}