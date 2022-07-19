param deploymentName string = 'tsarmTesting3'
param deploymentString  string = substring(guid(uniqueString(resourceGroup().id)), 0, 2)

@description('This is the object ID for the service princpal.')
@secure()
param servicePrincipalObjectId string
param location string = resourceGroup().location
param networkSecurityGroupName string = '${deploymentName}-${deploymentString}-nsg'
param subnetName string = 'default'
param virtualNetworkName string = '${deploymentName}-${deploymentString}-net'
param publicIpAddressName string = '${deploymentName}-${deploymentString}-pip'
param publicIpAddressType string = 'static'
param publicIpAddressSku string = 'Basic'
param virtualMachineName string = '${deploymentName}-${deploymentString}-vm'
param virtualMachineSize string = 'Standard_E8s_v3'
param adminUsername string
@secure()
param adminPassword string
@secure()
param appId string
@secure()
param appSecret string
param trifactaStorageAccountName string = 'trifacta${deploymentString}storage'
param databricksMRGID string = '${subscription().id}/resourceGroups/${deploymentName}-${deploymentString}-dbrg'
param containerName string = 'trifacta'
param keyVaultName string = '${deploymentName}-${deploymentString}-kv'

var networkInterfaceName = '${deploymentName}-${deploymentString}-int'
//var nsgId = resourceId(resourceGroup().name, 'Microsoft.Network/networkSecurityGroups', networkSecurityGroupName)
var vnetId = resourceId(resourceGroup().name, 'Microsoft.Network/virtualNetworks', virtualNetworkName)
var subnetRef = '${vnetId}/subnets/${subnetName}'
var storageBlobContributor = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var databricksWorkspaceName_var = '${deploymentName}-${deploymentString}-db'
//var storageAccountRole_var = '${trifactaStorageAccountName}/Microsoft.Authorization/${guid(uniqueString(trifactaStorageAccountName))}'
var storageAccountRoleName_var = guid(uniqueString(trifactaStorageAccountName))
//var publicIpAddressId = resourceId(resourceGroup().name, 'Microsoft.Network/publicIpAddresses', publicIpAddressName)


resource networkInterface 'Microsoft.Network/networkInterfaces@2021-08-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig2'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddressName_resource.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupName_resource.id
    }
  }
  dependsOn: [
    virtualNetworkName_resource
  ]
}

resource networkSecurityGroupName_resource 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 300
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Trifacta_Service'
        properties: {
          priority: 200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '3005'
            '80'
            '443'
          ]
        }
      }
    ]
  }
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2019-04-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.2.0/24'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.1.2.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
    ]
  }
}

resource publicIpAddressName_resource 'Microsoft.Network/publicIPAddresses@2021-08-01' = {
  name: publicIpAddressName
  location: location
  properties: {
    publicIPAllocationMethod: publicIpAddressType
    dnsSettings: {
      domainNameLabel: toLower('${deploymentName}${deploymentString}')
    }
  }
  sku: {
    name: publicIpAddressSku
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: virtualMachineName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        id: '/subscriptions/b5ee4560-1a98-4001-bb35-57413fa77258/resourceGroups/ts_training/providers/Microsoft.Compute/galleries/ts_training/images/trifacta_ee/versions/9.2.1'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
  }
  plan: {
    name: 'wrangler-enterprise'
    product: 'wrangler-enterprise-vm'
    publisher: 'trifacta'
  }
  resource configRunCommand 'runCommands' = {
    name: 'trifactaConfigs'
    location: location
    properties: {
      errorBlobUri: '${trifactaStorageAccount.properties.primaryEndpoints.blob}${containerName}/runcommanderror.txt'
      outputBlobUri: '${trifactaStorageAccount.properties.primaryEndpoints.blob}${containerName}/runcommandoutput.txt'
      source: {
        script: '/opt/trifacta/pkg3p/python/bin/python3 /opt/trifacta/azureconfig.py --keyVaultUrl "${keyVaultName_resource.properties.vaultUri}" --directoryid ${subscription().tenantId} --dbserviceUrl "https://${databricksWorkspaceName.properties.workspaceUrl}" --storageaccount ${trifactaStorageAccountName} --storagecontainer ${containerName} --applicationid ${appId} --secret ${appSecret} && source /opt/trifacta/conf/env.sh && /opt/trifacta/services/configuration-service/bin/import.sh -f /opt/trifacta/tools/config-service-tools/resources/migrate.conf && service nginx restart'
      }
    }
  }
}

resource trifactaStorageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: trifactaStorageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
    isHnsEnabled: true
    supportsHttpsTrafficOnly: true
  }
}

resource blobServiceContainerName 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: '${trifactaStorageAccount.name}/default/${containerName}'
}

resource storageAccountRoleName 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: storageAccountRoleName_var
  scope: trifactaStorageAccount
  properties: {
    roleDefinitionId: storageBlobContributor
    principalId: servicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultName_resource 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: servicePrincipalObjectId
        permissions: {
          keys: [
            'get'
            'list'
            'update'
            'create'
            'import'
            'delete'
            'recover'
            'backup'
            'restore'
          ]
          secrets: [
            'get'
            'list'
            'set'
            'delete'
            'recover'
            'backup'
            'restore'
          ]
          certificates: [
            'get'
            'list'
            'update'
            'create'
            'import'
            'delete'
            'recover'
            'backup'
            'restore'
            'managecontacts'
            'manageissuers'
            'getissuers'
            'listissuers'
            'setissuers'
            'deleteissuers'
          ]
        }
      }
    ]
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: [
        {
          id: '${virtualNetworkName_resource.id}/subnets/default'
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
  }
}

resource databricksWorkspaceName 'Microsoft.Databricks/workspaces@2018-04-01' = {
  name: databricksWorkspaceName_var
  location: location
  properties: {
    managedResourceGroupId: databricksMRGID
  }
}

output adminUsername string = adminUsername
output trifactaInstanceName string = virtualMachineName
output trifactaURL string = publicIpAddressName_resource.properties.dnsSettings.fqdn
output keyvaultURI string = keyVaultName_resource.properties.vaultUri
output databricksURL string = databricksWorkspaceName.properties.workspaceUrl
output storagecontainer string = containerName
output storageaccount string = trifactaStorageAccountName
output vmid string = virtualMachine.identity.principalId
