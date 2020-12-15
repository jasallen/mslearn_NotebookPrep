az extension add -n azure-cli-ml

subscription=$(az account list --query [0].id -o tsv)
resourceGroupName=$(az group list --query "[0] | name" -o tsv)
cd clouddrive

sandboxStorageName=$(az storage account list -g $resourceGroupName --query "[?contains(@.name, 'cloudshell')==\`true\`].name" -o tsv)
sandboxStorageKey=$(az storage account keys list \
    --resource-group $resourceGroupName \
    --account-name $sandboxStorageName \
    --query "[0].value" | tr -d '"')

end=`date -u -d "60 minutes" '+%Y-%m-%dT%H:%MZ'`
sandboxStorageSas=$(az storage account generate-sas \
    --permissions cdlruwap \
    --account-name $sandboxStorageName \
    --account-key $sandboxStorageKey \
    --services f --resource-types sco \
    --expiry $end \
    -o tsv)
sandboxEndpoint=$(az storage account show \
    --resource-group $resourceGroupName \
    --name $sandboxStorageName \
    --query "primaryEndpoints.file" -o tsv )

sandboxShareName=$(az storage share list --account-name $sandboxStorageName --account-key $sandboxStorageKey --prefix "code" --query [0].name -o tsv)

# create workspace and workspace compute
workspaceName="sandbox-ml"
az ml workspace create -w $workspaceName -g $(echo $resourceGroupName) --location eastus
az ml folder attach -w $workspaceName -g $(echo $resourceGroupName)

computeName="sandboxgpu-compute$(echo $RANDOM)"
ssh-keygen -q -t rsa -N '' -f ~/.ssh/compute_rsa <<<y 2>&1 >/dev/null
az ml computetarget create computeinstance \
    --admin-user-ssh-public-key "$(cat ~/.ssh/compute_rsa.pub)" \
    --ssh-public-access True \
    -n $computeName -s Standard_NC6 

computeDetails=$(az rest --method get --uri /subscriptions/$subscription/resourceGroups/$resourceGroupName/providers/Microsoft.MachineLearningServices/workspaces/sandbox-ml/computes?api-version=2019-05-01     \
    --query "{user:value[0].properties.properties.sshSettings.adminUserName, \
        sshPort:value[0].properties.properties.sshSettings.sshPort, \
        iP:value[0].properties.properties.connectivityEndpoints.publicIpAddress, \
        jupyter:(value[0].properties.properties.applications[?displayName=='Jupyter'].endpointUri)[0]}" \
    -o tsv)
computeUser=$(echo "$computeDetails" | cut -f1)
computePort=$(echo "$computeDetails" | cut -f2)
computeIp=$(echo "$computeDetails" | cut -f3)
Jupyter=$(echo "$computeDetails" | cut -f4)

ssh -q -o "StrictHostKeyChecking no" $computeUser@$computeIp -p $computePort -i ~/.ssh/compute_rsa <<-ENDSSH
    # in ssh session
    mkdir -p /mnt/batch/tasks/shared/LS_root/mounts/clusters/$computeName/code/Users/$computeUser
    cd /mnt/batch/tasks/shared/LS_root/mounts/clusters/$computeName/code/Users/$computeUser
    git clone $1
ENDSSH

echo "$Jupyter/tree/Users/$computeUser"

# get workspace storage
# workspaceStorageId=$(az ml workspace show -w sandbox-ml --query storageAccount -o tsv)
# workspaceStorageName=$(az storage account show --ids $workspaceStorageId --query name -o tsv)
# workspaceStorageKey=$(az storage account keys list \
#     --resource-group $resourceGroupName \
#     --account-name $workspaceStorageName \
#     --query "[0].value" | tr -d '"')

# end=`date -u -d "60 minutes" '+%Y-%m-%dT%H:%MZ'`
# workspaceStorageSas=$(az storage account generate-sas \
#     --permissions cdlruwap \
#     --account-name $workspaceStorageName \
#     --account-key $workspaceStorageKey \
#     --services f --resource-types sco \
#     --expiry $end \
#     -o tsv)
# workspaceEndpoint=$(az storage account show \
#     --resource-group $resourceGroupName \
#     --name $workspaceStorageName \
#     --query "primaryEndpoints.file" -o tsv )

# azcopy copy $(https://$sandboxStorageKey.file.core.windows.net/<file-share-name>/clouddrive?<SAS-token>') 'https://<destination-storage-account-name>.file.core.windows.net/<file-share-name><SAS-token>' --recursive