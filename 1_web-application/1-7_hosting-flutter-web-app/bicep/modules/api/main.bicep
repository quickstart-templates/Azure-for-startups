param workloadName string
param resourceGroupLocation string = resourceGroup().location
@allowed(['Basic', 'Consumption', 'Developer', 'Isolated', 'Premium', 'Standard'])
param apimSkuName string = 'Developer'
param apimOrganizationName string
param apimAdministratorEmail string
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSkuCode string = 'P1v2'
@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuCode string = 'Standard_LRS'
@allowed(['Brazil Southeast', 'Central US', 'Australia Southeast', 'Canada Central', 'Central India', 'Southeast Asia', 'Switzerland North', 'UAE North', 'East Asia', 'UK West', 'Switzerland West', 'West Europe', 'East US 2', 'West US', 'East US', 'West US 3', 'Australia East', 'Brazil South', 'Germany West Central', 'France Central', 'Japan East', 'Japan West', 'Korea South', 'Germany North', 'France South', 'Australia Central', 'South Central US', 'South Africa North', 'Korea Central', 'South India', 'Norway East', 'Canada East', 'North Central US', 'Norway West', 'North Europe', 'South Africa West', 'Australia Central 2', 'UAE Central', 'UK South', 'West Central US', 'West India', 'West US 2', 'Jio India West', 'Jio India Central', 'Sweden Central', 'Sweden South', 'Qatar Central'])
param cosmosDbLocation string = 'Korea Central'
param cosmosDbEnableFreeTier bool = false

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-${workloadName}'
  location: resourceGroupLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

resource subnetBackend 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  name: 'backend'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.1.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource subnetOutboundFunc 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  name: 'outbound-func'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.2.0/24'
    delegations: [
      {
        name: 'delegation'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    subnetBackend
  ]
}

resource subnetOutboundApim 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  name: 'outbound-apim'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.3.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    subnetOutboundFunc
  ]
}

resource privateDnsZoneBlobStorage 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: 'link-${workloadName}-storage-blob'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource privateDnsZoneFileStorage 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: 'link-${workloadName}-storage-file'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource privateDnsZoneFunc 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: 'link-${workloadName}-func'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource privateDnsZoneCosmosDb 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: 'link-${workloadName}-cosmos'
    location: 'global'
    properties: {
      registrationEnabled: true
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: 'nsg-${workloadName}-outbound-apim'
  location: resourceGroupLocation
  properties: {
    securityRules: [
      {
        name: 'ManagementForPortalAndPowerShell'
        properties: {
          description: 'Management endpoint for Azure portal and PowerShell'
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '3443'
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowTagHTTPSInbound'
        properties: {
          description: 'Client communication to API Management'
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowTagHTTPSOutbound'
        properties: {
          description: 'Dependency on Azure Storage'
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource privateEndpointFuncBlobStorage 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-storage-func-blob'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'blob'
        properties: {
          privateLinkServiceId: storageAccountFunc.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: subnetBackend.id
    }
  }
}

resource privateEndpointFuncFileStorage 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-storage-func-file'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'file'
        properties: {
          privateLinkServiceId: storageAccountFunc.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
    subnet: {
      id: subnetBackend.id
    }
  }
}

resource privateEndpointFunc 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-func'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'sites'
        properties: {
          privateLinkServiceId: functions.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
    subnet: {
      id: subnetBackend.id
    }
  }
}

resource storageAccountFunc 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${uniqueString(resourceGroup().id, 'func')}'
  location: resourceGroupLocation
  sku: {
    name: storageAccountSkuCode
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'plan-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: appServicePlanSkuCode
  }
  kind: 'app'
  properties: {}
}

resource functions 'Microsoft.Web/sites@2022-03-01' = {
  name: 'func-${workloadName}'
  location: resourceGroupLocation
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    vnetRouteAllEnabled: true
    vnetContentShareEnabled: true
    siteConfig: {
      alwaysOn: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      nodeVersion: '16'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'COSMOS_DB_CONNECTION_STRING'
          value: cosmosDb.listConnectionStrings().connectionStrings[0].connectionString
        }
      ]
    }
    virtualNetworkSubnetId: subnetOutboundFunc.id
  }
}

resource privateEndpointCosmosDb 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-cosmos'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'cosmosdb'
        properties: {
          privateLinkServiceId: cosmosDb.id
          groupIds: [
            'sql'
          ]
        }
      }
    ]
    subnet: {
      id: subnetBackend.id
    }
  }
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: 'cosmos-${workloadName}'
  location: cosmosDbLocation
  kind: 'GlobalDocumentDB'
  properties: {
    publicNetworkAccess: 'Disabled'
    enableFreeTier: cosmosDbEnableFreeTier
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxStalenessPrefix: 100
      maxIntervalInSeconds: 5
    }
    locations: [
      {
        locationName: cosmosDbLocation
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: 'apim-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: apimSkuName
    capacity: apimSkuName == 'Consumption' ? 0 : 1
  }
  properties: {
    publisherName: apimOrganizationName
    publisherEmail: apimAdministratorEmail
    virtualNetworkConfiguration: {
      subnetResourceId: subnetOutboundApim.id
    }
    virtualNetworkType: 'External'
    publicNetworkAccess: 'Enabled'
  }
}

resource apiBackend 'Microsoft.ApiManagement/service/backends@2021-08-01' = {
  name: functions.name
  parent: apim
  properties: {
    url: 'https://${functions.properties.defaultHostName}/api'
    protocol: 'http'
    resourceId: '${environment().resourceManager}${functions.id}'
  }
}
