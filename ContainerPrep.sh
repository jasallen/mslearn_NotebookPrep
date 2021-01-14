resourceGroupName=$(az group list --query "[0] | name" -o tsv)
containerName=learnjupyterinst$RANDOM

az container create \
    --resource-group $resourceGroupName \
    -n $containerName \
    --cpu 1 --memory 2 --ports 8888\
    --dns-name-label $containerName \
    --image tempacrname.azurecr.io/mslearnjupyter:v1 \
    --registry-login-server tempacrname.azurecr.io --registry-username readjupyter --registry-password lxHJUfPGau5FvuKo8gbsO+8MA64qyHcb \
    --gitrepo-url %1 \
    --gitrepo-mount-path /notebooks/