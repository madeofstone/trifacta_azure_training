
## pre-deploy
## Create
az group create --name ts_armdeploytest3 --location westeurope

az ad app create --display-name ts_testCLIapp2 --required-resource-accesses manifest.json --query "appId"

appId=$(az ad app show --id 7b54178e-de3f-4c33-a5af-3f0defe1c8f7 --query "appId" --output tsv)
appId=$(az ad app create --display-name ts_testCLIapp2 --required-resource-accesses manifest.json --query "appId" --output tsv)
secret=$(az ad app credential reset --id $appId --query "password" --output tsv)
appSP=$(az ad sp create --id $appId --query "objectId" --output tsv)

adminUsername=$'TrifAdmin'
##"The supplied password must be between 6-72 characters long and must satisfy at least 3 of password complexity 
##requirements from the following:\r\n1) Contains an uppercase character\r\n2) 
##Contains a lowercase character\r\n3) Contains a numeric digit\r\n4) Contains a special character\r\n5) 
##Control characters are not allowed"
adminPassword=$'TrifDiddy22?'



## Deployment group what-if
az deployment group what-if \
--name ts_armdeploy1 --resource-group ts_armdeploytest2 \
--template-file trifacta920deploy_training_app.bicep \
--parameters @trifacta920deploy_training_app.parameters.json

az deployment group create \
--name ts_armdeploy1 --resource-group ts_armdeploytest3 \
--template-file trifacta920deploy_training_app.bicep \
--parameters servicePrincipalObjectId=$appSP \
adminUsername=$adminUsername adminPassword=$adminPassword \
appId=$appId appSecret=$secret

## Deployment group create
az deployment group create \
--name ts_armdeploy1 --resource-group ts_armdeploytest3 \
--template-file trifacta920deploy_training_app.bicep \
--parameters @trifacta920deploy_training_app.parameters.json

