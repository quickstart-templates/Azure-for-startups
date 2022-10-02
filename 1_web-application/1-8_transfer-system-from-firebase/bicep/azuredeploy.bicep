@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('Azure Cosmos DB のロケーションを選択してください（状況によって利用できないリージョンがあります）')
@allowed(['Brazil Southeast', 'Central US', 'Australia Southeast', 'Canada Central', 'Central India', 'Southeast Asia', 'Switzerland North', 'UAE North', 'East Asia', 'UK West', 'Switzerland West', 'West Europe', 'East US 2', 'West US', 'East US', 'West US 3', 'Australia East', 'Brazil South', 'Germany West Central', 'France Central', 'Japan East', 'Japan West', 'Korea South', 'Germany North', 'France South', 'Australia Central', 'South Central US', 'South Africa North', 'Korea Central', 'South India', 'Norway East', 'Canada East', 'North Central US', 'Norway West', 'North Europe', 'South Africa West', 'Australia Central 2', 'UAE Central', 'UK South', 'West Central US', 'West India', 'West US 2', 'Jio India West', 'Jio India Central', 'Sweden Central', 'Sweden South', 'Qatar Central'])
param cosmosDbLocation string = 'Korea Central'

@description('Azure Cosmos DB の無料利用枠を利用するか否かを選択してください')
param cosmosDbEnableFreeTier bool = false

var resourceGroupLocation = resourceGroup().location

// Virtual Network --

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

resource subnetFrontend 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  name: 'frontend'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.0.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
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
  dependsOn: [
    subnetFrontend
  ]
}

resource subnetContainerAppsEnv 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  name: 'container-apps-environment'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.254.0/23'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    subnetBackend
  ]
}

// Container Registry --

resource privateDnsZoneContainerRegistry 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: 'link-${workloadName}-container-registry'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource privateEndpointContainerRegistry 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-container-registry'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'registry'
        properties: {
          privateLinkServiceId: containerRegistry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
    subnet: {
      id: subnetFrontend.id
    }
  }
}

resource privateDnsZoneGroupContainerRegistry 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  name: 'default'
  parent: privateEndpointContainerRegistry
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneContainerRegistry.id
        }
      }
    ]
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: 'cr${join(split(workloadName, '-'), '')}'
  location: resourceGroupLocation
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    anonymousPullEnabled: false
  }
}

// Container Apps --

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: 'container-apps-environment-${workloadName}'
  location: resourceGroupLocation
  properties: {
    vnetConfiguration: {
      internal: false
      infrastructureSubnetId: subnetContainerAppsEnv.id
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'log-${workloadName}'
  location: resourceGroupLocation
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'app-${workloadName}'
  location: resourceGroupLocation
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: 'simple-hello-world-container'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
    }
  }
}

// Cosmos DB --

resource privateDnsZoneCosmosDb 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: 'link-${workloadName}-cosmos'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
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

resource privateDnsZoneGroupCosmosDb 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  name: 'default'
  parent: privateEndpointCosmosDb
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneCosmosDb.id
        }
      }
    ]
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
