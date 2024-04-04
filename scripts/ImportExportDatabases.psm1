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
Exports file processing status data from the CosmosDB database

.DESCRIPTION
Exports file processing status data from the CosmosDB database

.PARAMETER SourceConnectionString
The connection string to the source CosmosDB database

.PARAMETER WorkingDirectory
The path to the working directory used to export the data.  Defaults to ./data

.EXAMPLE
Export-CosmosDB -SourceConnectionString <source Cosmos DB connection string>

.EXAMPLE
Export-CosmosDB -SourceConnectionString <source Cosmos DB connection string> -WorkingDirectory ./ExportedData

.NOTES
Data will be exported to a folder named CosmosDB in the working directory.
#>
function Export-CosmosDB() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SourceConnectionString,
        [Parameter()]
        [string]
        $WorkingDirectory = './data'
    )

    Write-Host "Entering Export-CosmosDB"

    try {
        if (-not (Test-Path $WorkingDirectory)) {
            Write-Host "Creating working directory $WorkingDirectory"
            New-Item $WorkingDirectory -ItemType Directory | Out-Null
        }

        $CosmosDBDirectory = Join-Path -Path $WorkingDirectory -ChildPath 'CosmosDB'

        if (-not (Test-Path $CosmosDBDirectory)) {
            Write-Host "Creating CosmosDB directory $CosmosDBDirectory"
            New-Item $CosmosDBDirectory -ItemType Directory | Out-Null
        }

        $DatabaseName = 'statusdb'
        $ContainerName = 'statuscontainer'

        $SourceContext = New-CosmosDbContext -ConnectionString ($SourceConnectionString | ConvertTo-SecureString -AsPlainText -Force) -Database $DatabaseName -Environment AzureUSGovernment

        Write-Host "Downloading documents from source"
        $DocumentsPerRequest = 20
        $ContinuationToken = $null
        $DocumentCount = 0
        $BatchNumber = 0
        
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
        
            $Documents = Get-CosmosDbDocument @getCosmosDbDocumentParameters
            $ContinuationToken = Get-CosmosDbContinuationToken -ResponseHeader $ResponseHeader

            $OutputPath = Join-Path -Path $CosmosDBDirectory -ChildPath "$BatchNumber.json".PadLeft(10, '0')
            Write-Host "Writing batch $BatchNumber to $OutputPath"
            $Documents | ConvertTo-Json -Depth 100 | Out-File -FilePath $OutputPath

            $DocumentCount += $Documents.Count
            $BatchNumber++
        } while (-not [System.String]::IsNullOrEmpty($ContinuationToken))

        Write-Host "Downloaded $($DocumentCount) documents"
    }
    catch {
        Write-Host "Error thrown in Export-CosmosDB" -ForegroundColor Red
        throw
    }

    Write-Host "Exiting Export-CosmosDB"
}

<#
.SYNOPSIS
Imports file processing status data exported by the Export-CosmosDB cmdlet.

.DESCRIPTION
Imports file processing status data exported by the Export-CosmosDB cmdlet.

.PARAMETER DestinationConnectionString
The connection string to the destination CosmosDB database

.PARAMETER WorkingDirectory
The path to the working directory used to export the data.  Defaults to ./data

.EXAMPLE
Import-CosmosDB -DestinationConnectionString <destination Cosmos DB connection string>

.EXAMPLE
Import-CosmosDB -DestinationConnectionString <destination Cosmos DB connection string> -WorkingDirectory ./ExportedData

.NOTES
Data will be imported from a folder named CosmosDB in the working directory.

Existing data will be overwritten without warning.
#>
function Import-CosmosDB() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationConnectionString,
        [Parameter()]
        [string]
        $WorkingDirectory = './data'
    )

    Write-Host "Entering Import-CosmosDB"

    try {
        if (-not (Test-Path $WorkingDirectory)) {
            throw "Working directory $WorkingDirectory does not exist"
        }

        $CosmosDBDirectory = Join-Path -Path $WorkingDirectory -ChildPath 'CosmosDB'

        if (-not (Test-Path $CosmosDBDirectory)) {
            throw "CosmosDB directory $CosmosDBDirectory does not exist"
        }

        $DatabaseName = 'statusdb'
        $ContainerName = 'statuscontainer'

        $DestinationContext = New-CosmosDbContext -ConnectionString ($DestinationConnectionString | ConvertTo-SecureString -AsPlainText -Force) -Database $DatabaseName -Environment AzureUSGovernment

        $Batches = Get-ChildItem -Path $CosmosDBDirectory -Filter '*.json'
        
        Write-Host "Uploading $($Batches.Count) batches to destination"

        $DocumentCount = 0

        foreach ($Batch in $Batches) {
            Write-Host "Uploading batch $($Batch.Name) to destination"

            $Documents = $Batch | Get-Content -Raw | ConvertFrom-Json -Depth 100
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
    
                New-CosmosDbDocument @NewCosmosDbDocumentParameters | Out-Null

                $DocumentCount++
            }
        }

        Write-Host "Uploaded $($DocumentCount) documents"
    }
    catch {
        Write-Host "Error thrown in Import-CosmosDB" -ForegroundColor Red
        throw
    }

    Write-Host "Exiting Import-CosmosDB"
}

<#
.SYNOPSIS
Exports the search index from the Azure Cognitive Search service

.DESCRIPTION
Exports the search index from the Azure Cognitive Search service

.PARAMETER SourceCognitiveSearchName
The name of the source Azure Cognitive Search service

.PARAMETER SourceAdminKey
The admin key of the source Azure Cognitive Search service

.PARAMETER WorkingDirectory
The path to the working directory used to export the data.  Defaults to ./data

.EXAMPLE
Export-SearchIndexes -SourceCognitiveSearchName <source cognitive search name> `
    -SourceAdminKey <source admin key>

.EXAMPLE
Export-SearchIndexes -SourceCognitiveSearchName <source cognitive search name> `
    -SourceAdminKey <source admin key> `
    -WorkingDirectory ./ExportedData

.NOTES
Data will be exported to a folder named Search in the working directory.
#>
function Export-SearchIndexes() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SourceCognitiveSearchName,
        [Parameter(Mandatory = $true)]
        [string]
        $SourceAdminKey,
        [Parameter()]
        [string]
        $WorkingDirectory = './data'
    )

    Write-Host "Entering Export-SearchIndexes"

    try {
        if (-not (Test-Path $WorkingDirectory)) {
            Write-Host "Creating working directory $WorkingDirectory"
            New-Item $WorkingDirectory -ItemType Directory | Out-Null
        }

        $SearchDirectory = Join-Path -Path $WorkingDirectory -ChildPath 'Search'

        if (-not (Test-Path $SearchDirectory)) {
            Write-Host "Creating Search directory $SearchDirectory"
            New-Item $SearchDirectory -ItemType Directory | Out-Null
        }

        $IndexName = 'all-files-index'
        $SourceServiceUrl = "https://$SourceCognitiveSearchName.search.azure.us"

        $SourceHeaders = @{
            'api-key' = $SourceAdminKey
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
        $DocumentCount = 0
        $BatchNumber = 0

        Write-Host "Downloading indexed documents in $BatchCount batches of $BatchSize from source"
        for ($i = 0; $i -lt $BatchCount; $i++) {
            Write-Host "Downloading source batch $i"

            $Skip = $i * $BatchSize
            $Response = Invoke-RestMethod -Uri "$SourceServiceUrl/indexes/$IndexName/docs/?api-version=2020-06-30&search=*&searchMode=all&`$skip=$Skip&`$top=$BatchSize" `
                -Method Get -Headers $SourceHeaders -ContentType 'application/json'
            
            $OutputPath = Join-Path -Path $SearchDirectory -ChildPath "$BatchNumber.json".PadLeft(10, '0')
            Write-Host "Writing batch $BatchNumber to $OutputPath"
            $Response | ConvertTo-Json -Depth 100 | Out-File -FilePath $OutputPath
    
            $DocumentCount += $Response.value.Count
            $BatchNumber++
        }

        Write-Host "Downloaded $($DocumentCount) documents"
    }
    catch {
        Write-Host "Error thrown in Export-SearchIndexes" -ForegroundColor Red
        throw
    }

    Write-Host "Exiting Export-SearchIndexes"
}

<#
.SYNOPSIS
Imports the search index exported by the Export-SearchIndexes cmdlet

.DESCRIPTION
Imports the search index exported by the Export-SearchIndexes cmdlet

.PARAMETER DestinationCognitiveSearchName
The name of the destination Azure Cognitive Search service

.PARAMETER DestinationAdminKey
The admin key of the destination Azure Cognitive Search service

.PARAMETER SourceStorageAccountName
The name of the source Azure Storage account

.PARAMETER DestinationStorageAccountName
The name of the destination Azure Storage account

.PARAMETER WorkingDirectory
The path to the working directory used to export the data.  Defaults to ./data

.EXAMPLE
Import-SearchIndexes -DestinationCognitiveSearchName <destination cognitive search name> `
    -DestinationAdminKey <destination admin key> `
    -SourceStorageAccountName <source storage account name> `
    -DestinationStorageAccountName <destination storage account name>

.EXAMPLE
Import-SearchIndexes -DestinationCognitiveSearchName <destination cognitive search name> `
    -DestinationAdminKey <destination admin key> `
    -SourceStorageAccountName <source storage account name> `
    -DestinationStorageAccountName <destination storage account name> `
    -WorkingDirectory ./ExportedData

.NOTES
Data will be imported from a folder named Search in the working directory.

During the import process, the reference to the source Azure Storage account will be updated to point at the destination Azure Storage account.

Existing data will be overwritten without warning.
#>
function Import-SearchIndexes() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationCognitiveSearchName,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationAdminKey,
        [Parameter(Mandatory = $true)]
        [string]
        $SourceStorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationStorageAccountName,
        [Parameter()]
        [string]
        $WorkingDirectory = './data'
    )

    Write-Host "Entering Import-SearchIndexes"

    try {
        if (-not (Test-Path $WorkingDirectory)) {
            throw "Working directory $WorkingDirectory does not exist"
        }

        $SearchDirectory = Join-Path -Path $WorkingDirectory -ChildPath 'Search'

        if (-not (Test-Path $SearchDirectory)) {
            throw "Search directory $SearchDirectory does not exist"
        }
        
        $IndexName = 'all-files-index'
        $DestinationServiceUrl = "https://$DestinationCognitiveSearchName.search.azure.us"

        $DestinationHeaders = @{
            'api-key' = $DestinationAdminKey
        }

        $Batches = Get-ChildItem -Path $SearchDirectory -Filter '*.json'
        
        Write-Host "Uploading $($Batches.Count) batches to destination"

        $DocumentCount = 0

        foreach ($Batch in $Batches) {
            Write-Host "Uploading batch $($Batch.Name) to destination"
            
            $Json = $Batch | Get-Content -Raw

            # Replace embedded urls
            $Json = $Json -replace $SourceStorageAccountName, $DestinationStorageAccountName

            Invoke-RestMethod -Uri "$DestinationServiceUrl/indexes/$IndexName/docs/index?api-version=2020-06-30" `
                -Method Post -Body $Json -Headers $DestinationHeaders -ContentType "application/json; charset=utf-8"

            $DocumentCount += ($Json | ConvertFrom-Json -Depth 100).value.Count
        }

        Write-Host "Uploaded $($DocumentCount) documents"
    }
    catch {
        Write-Host "Error thrown in Import-SearchIndexes" -ForegroundColor Red
        throw
    }

    Write-Host "Exiting Import-SearchIndexes"
}

<#
.SYNOPSIS
Exports blobs receipts, indexed content, logs and original documents from the source Azure Storage account.

.DESCRIPTION
Exports blobs receipts, indexed content, logs and original documents from the source Azure Storage account.

.PARAMETER SourceStorageAccountName
The name of the source Azure Storage account

.PARAMETER SourceStorageAccountKey
The master key of the source Azure Storage account

.PARAMETER SourceFunctionAppName
The name of the source Azure Function application

.PARAMETER WorkingDirectory
The path to the working directory used to export the data.  Defaults to ./data

.EXAMPLE
Export-StorageAccount -SourceStorageAccountName <source storage account name> `
    -SourceStorageAccountKey <source storage account key> `
    -SourceFunctionAppName <source function app name>

.EXAMPLE
Export-StorageAccount -SourceStorageAccountName <source storage account name> `
    -SourceStorageAccountKey <source storage account key> `
    -SourceFunctionAppName <source function app name> `
    -WorkingDirectory ./ExportedData

.NOTES
Data will be exported to a folder named Storage in the working directory.

This process will take several hours to complete due to data egress throttling in Azure.
#>
function Export-StorageAccount() {
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
        [Parameter()]
        [string]
        $WorkingDirectory = './data'

    )

    Write-Host "Entering Export-StorageAccount"

    try {
        if (-not (Test-Path $WorkingDirectory)) {
            Write-Host "Creating working directory $WorkingDirectory"
            New-Item $WorkingDirectory -ItemType Directory | Out-Null
        }

        $StorageDirectory = Join-Path -Path $WorkingDirectory -ChildPath 'Storage'

        if (-not (Test-Path $StorageDirectory)) {
            Write-Host "Creating Storage directory $StorageDirectory"
            New-Item $StorageDirectory -ItemType Directory | Out-Null
        }

        $SourceContext = New-AzStorageContext -StorageAccountName $SourceStorageAccountName -StorageAccountKey $SourceStorageAccountKey -Environment AzureUSGovernment

        $ContainerNames = @('azure-webjobs-hosts', 'content', 'logs', 'upload')
        $DocumentCount = 0

        foreach ($ContainerName in $ContainerNames) {
            $ContainerDirectory = Join-Path -Path $StorageDirectory -ChildPath $ContainerName

            if (-not (Test-Path $ContainerDirectory)) {
                Write-Host "Creating Container directory $ContainerDirectory"
                New-Item $ContainerDirectory -ItemType Directory | Out-Null
            }

            Write-Host "Getting list of blobs from $ContainerName container from source"
            $SourceBlobs = Get-AzStorageBlob -Context $SourceContext -Container $ContainerName
            
            $FilteredBlobs = $SourceBlobs | Where-Object { $ContainerName -ne 'azure-webjobs-hosts' -or $_.Name -like 'blobreceipts*' }

            Write-Host "Found $($FilteredBlobs.Count) blobs"

            $BlobCount = 1
    
            foreach ($SourceBlob in $SourceBlobs) {
                if ($ContainerName -eq 'azure-webjobs-hosts' -and $SourceBlob.Name -notlike 'blobreceipts*') {
                    continue
                }

                Write-Host "Downloading blob $BlobCount/$($FilteredBlobs.Count) from container $ContainerName"
                
                $SourceBlob | Get-AzStorageBlobContent -Destination $ContainerDirectory

                $DocumentCount++
                $BlobCount++
            }
        }

        Write-Host "Downloaded $($DocumentCount) documents"
    }
    catch {
        Write-Host "Error thrown in Export-StorageAccount" -ForegroundColor Red
        throw
    }

    Write-Host "Exiting Export-StorageAccount"
}

<#
.SYNOPSIS
Imports blobs receipts, indexed content, logs and original documents exported by the Export-StorageAccount cmdlet.

.DESCRIPTION
Imports blobs receipts, indexed content, logs and original documents exported by the Export-StorageAccount cmdlet.

.PARAMETER SourceStorageAccountName
The name of the source Azure Storage account

.PARAMETER DestinationStorageAccountName
The name of the destination Azure Storage account

.PARAMETER DestinationStorageAccountKey
The master key of the destination Azure Storage account

.PARAMETER SourceFunctionAppName
The name of the source Azure Function application

.PARAMETER DestinationStorageAccountKey
The master key of the destination Azure Storage account

.PARAMETER WorkingDirectory
The path to the working directory used to export the data.  Defaults to ./data

.EXAMPLE
Import-StorageAccount -SourceStorageAccountName <source storage account name> `
    -DestinationStorageAccountName <destination storage account name> `
    -DestinationStorageAccountKey <destination storage account key> `
    -SourceFunctionAppName <source function app name> `
    -DestinationFunctionAppName <destination function app name>

.EXAMPLE
Import-StorageAccount -SourceStorageAccountName <source storage account name> `
    -DestinationStorageAccountName <destination storage account name> `
    -DestinationStorageAccountKey <destination storage account key> `
    -SourceFunctionAppName <source function app name> `
    -DestinationFunctionAppName <destination function app name> `
    -WorkingDirectory ./ExportedData

.NOTES
Data will be imported from a folder named Storage in the working directory.

During the import process, the reference to the source Azure Function application will be updated to point to the destination Azure Function application,
and the reference to the source Azure Storage account will be updated to point at the destination Azure Storage account.

This process will take a fraction of the time than the export did.
#>
function Import-StorageAccount() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SourceStorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationStorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationStorageAccountKey,
        [Parameter(Mandatory = $true)]
        [string]
        $SourceFunctionAppName,
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationFunctionAppName,
        [Parameter()]
        [string]
        $WorkingDirectory = './data'
    )

    Write-Host "Entering Import-StorageAccount"

    try {
        if (-not (Test-Path $WorkingDirectory)) {
            throw "Working directory $WorkingDirectory not found"
        }

        $StorageDirectory = Join-Path -Path $WorkingDirectory -ChildPath 'Storage'

        if (-not (Test-Path $StorageDirectory)) {
            throw "Storage directory $StorageDirectory not found"
        }

        $DestinationContext = New-AzStorageContext -StorageAccountName $DestinationStorageAccountName -StorageAccountKey $DestinationStorageAccountKey -Environment AzureUSGovernment

        $ContainerNames = @('azure-webjobs-hosts', 'content', 'logs', 'upload')
        $DocumentCount = 0

        foreach ($ContainerName in $ContainerNames) {
            $ContainerDirectory = Join-Path -Path $StorageDirectory -ChildPath $ContainerName

            if (-not (Test-Path $ContainerDirectory)) {
                throw "Container directory $ContainerDirectory not found"
            }

            Write-Host "Creating $ContainerName container in destination"
            $DestinationContainer = Get-AzStorageContainer -Context $DestinationContext | Where-Object { $_.Name -eq $ContainerName }
            if (-not $DestinationContainer) {
                $DestinationContainer = New-AzStorageContainer -Context $DestinationContext -Name $ContainerName
            }

            Write-Host "Getting list of files from $ContainerDirectory"
            $SourceFiles = Get-ChildItem -Path $ContainerDirectory -Recurse -File
            
            Write-Host "Found $($SourceFiles.Count) files"

            $FileCount = 1
    
            $ParentDirectory = Resolve-Path -Path $ContainerDirectory

            Write-Host "Uploading files to destination"
            foreach ($SourceFile in $SourceFiles) {
                $Name = $SourceFile.FullName -replace $SourceFunctionAppName, $DestinationFunctionAppName
                $Name = $Name -replace "$ParentDirectory/", ''

                Write-Host "Uploading file $FileCount/$($SourceFiles.Count) to container $ContainerName"

                $DestinationBlob = $DestinationContainer.CloudBlobContainer.GetBlockBlobReference($Name)

                if ($ContainerName -eq 'upload') {
                    $DestinationBlob.UploadFromFile($SourceFile.FullName)
                }
                else {
                    $Text = $SourceFile | Get-Content -Raw

                    if ($ContainerName -eq 'content' -or $ContainerName -eq 'logs') {
                        $Text = $Text -replace $SourceStorageAccountName, $DestinationStorageAccountName
                    }

                    if ($null -eq $Text) {
                        $Text = ''
                    }
                    
                    $DestinationBlob.UploadText($Text)
                }

                $DocumentCount++
                $FileCount++
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

        Write-Host "Uploaded $($DocumentCount) documents"
    }
    catch {
        Write-Host "Error thrown in Import-StorageAccount" -ForegroundColor Red
        throw
    }

    Write-Host "Exiting Import-StorageAccount"
}

<#
.SYNOPSIS
Removes a document from databases and the search index

.DESCRIPTION
Removes a document from databases and the search index

.PARAMETER DocumentName
The name of the document to remove

.PARAMETER CosmosDBConnectionString
The connection string to the CosmosDB database

.PARAMETER CognitiveSearchName
The name of the Azure Cognitive Search service

.PARAMETER CognitiveSearchAdminKey
The admin key of the Azure Cognitive Search service

.PARAMETER StorageAccountName
The name of the Azure Storage account

.PARAMETER StorageAccountKey
The master key of the Azure Storage account

.EXAMPLE
Remove-Document -DocumentName <document name> `
    -CosmosDBConnectionString <CosmosDB connection string> `
    -CognitiveSearchName <cognitive search name> `
    -CognitiveSearchAdminKey <cognitive search admin key> `
    -StorageAccountName <storage account name> `
    -StorageAccountKey <storage account master key>
#>
function Remove-Document() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $DocumentName,
        [Parameter(Mandatory = $true)]
        [string]
        $CosmosDBConnectionString,
        [Parameter(Mandatory = $true)]
        [string]
        $CognitiveSearchName,
        [Parameter(Mandatory = $true)]
        [string]
        $CognitiveSearchAdminKey,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountKey

    )

    Write-Host "Entering Remove-Document"

    try {
        $RootFileName = [IO.Path]::GetFileNameWithoutExtension($DocumentName)
        $FileExtension = [IO.Path]::GetExtension($DocumentName)

        Write-Host 'Connecting to storage account'
        $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -Environment AzureUSGovernment

        Write-Host 'Removing matching blobs from content container'
        Get-AzStorageBlob -Context $StorageContext -Container 'content' -Prefix $DocumentName | Remove-AzStorageBlob

        Write-Host 'Removing matching blobs from logs container'
        Get-AzStorageBlob -Context $StorageContext -Container 'logs' -Prefix "$($RootFileName)_Document_Map$($FileExtension).json" | Remove-AzStorageBlob
        Get-AzStorageBlob -Context $StorageContext -Container 'logs' -Prefix "$($RootFileName)_FR_Result$($FileExtension).json" | Remove-AzStorageBlob

        Write-Host 'Removing matching blobs from upload container'
        Get-AzStorageBlob -Context $StorageContext -Container 'upload' -Prefix $DocumentName | Remove-AzStorageBlob

        Write-Host 'Connecting to CosmosDB'
        $DatabaseName = 'statusdb'
        $ContainerName = 'statuscontainer'

        $CosmosDbContext = New-CosmosDbContext -ConnectionString ($CosmosDBConnectionString | ConvertTo-SecureString -AsPlainText -Force) -Database $DatabaseName -Environment AzureUSGovernment

        Write-Host 'Removing matching file statuses from CosmosDB'
        $Document = Get-CosmosDbDocument -Context $CosmosDbContext -CollectionId $ContainerName -PartitionKey $DocumentName
        
        if ($Document) {
            Remove-CosmosDbDocument -Context $CosmosDbContext -CollectionId $ContainerName -PartitionKey $DocumentName -Id $Document.id
        }

        Write-Host 'Running the cognitive search indexer'
        $IndexerName = 'all-files-indexer'
        $CognitiveSearchUrl = "https://$CognitiveSearchName.search.azure.us"

        $Headers = @{
            'api-key' = $CognitiveSearchAdminKey
        }

        Invoke-RestMethod -Uri "$CognitiveSearchUrl/indexers('$IndexerName')/search.run?api-version=2020-06-30" `
            -Method Post -Headers $Headers -ContentType 'application/json'

        Write-Host 'Document removed successfully'

    }
    catch {
        Write-Host "Error thrown in Remove-Document" -ForegroundColor Red
        throw
    }

    Write-Host "Exiting Remove-Document"
}