#!/bin/bash

# Purpose:
#   This script regenerates blob receipts in the target Function App's storage account by 
#   creating ETag-based placeholder files in the appropriate `azure-webjobs-hosts` container.
#
# Using this script:
#   Be sure to STOP the Azure Function app before uploading backed up content to the `upload` folder,
#   or any files added here will trigger the file processing logic.
#   Once all files are in place, update the storage and function app variables below and run this script.
#
#   Expect about 1-2s per file in the `uploads` container of the storage account.
#
#   Once processing is complete, you can restart the Function App and monitor it for correct behavior.
#   New files should trigger processing, but existing files should not.
#
# TODO:
# * Allow parameterization of inputs
# * Either clean up created files or swap to a method that doesn't require them

storage_account_name=''
storage_account_key=''
functionAppName=''

az storage blob list --account-name $storage_account_name --account-key $storage_account_key -c upload --query "[].{Name:name, ETag:properties.etag}" > blobs.json
touch empty.txt

blobs=$(jq -c '.[]' blobs.json)

while IFS= read -r blob; do
        echo $blob
        blobName=$(echo $blob | jq -r '.Name')
        etag=$(echo $blob | jq -r '.ETag')
        receiptPath="blobreceipts/$functionAppName/Host.Functions.FileUploadedFunc/\"$etag\"/upload/$blobName"

        #echo $receiptPath
        az storage blob upload --account-name $storage_account_name --account-key $storage_account_key -c azure-webjobs-hosts --name "$receiptPath" --content-type 'application/octet-stream' -f ./empty.txt --overwrite
        echo "-------"
done <<< "$blobs"