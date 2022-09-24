@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('Azure App Service Plan のプランを選択してください')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSkuCode string = 'P1v2'

@description('Azure Storage Account の SKU を選択してください')
@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuCode string = 'Standard_LRS'

@description('Azure Cosmos DB のロケーションを選択してください（状況によって利用できないリージョンがあります）')
@allowed(['Brazil Southeast', 'Central US', 'Australia Southeast', 'Canada Central', 'Central India', 'Southeast Asia', 'Switzerland North', 'UAE North', 'East Asia', 'UK West', 'Switzerland West', 'West Europe', 'East US 2', 'West US', 'East US', 'West US 3', 'Australia East', 'Brazil South', 'Germany West Central', 'France Central', 'Japan East', 'Japan West', 'Korea South', 'Germany North', 'France South', 'Australia Central', 'South Central US', 'South Africa North', 'Korea Central', 'South India', 'Norway East', 'Canada East', 'North Central US', 'Norway West', 'North Europe', 'South Africa West', 'Australia Central 2', 'UAE Central', 'UK South', 'West Central US', 'West India', 'West US 2', 'Jio India West', 'Jio India Central', 'Sweden Central', 'Sweden South', 'Qatar Central'])
param cosmosDbLocation string = 'Korea Central'

@description('Azure Cosmos DB の無料利用枠を利用するか否かを選択してください')
param cosmosDbEnableFreeTier bool = false

@description('Azure Database for PostgreSQL の管理者ユーザー名を入力してください')
param postgreSqlServerAdminLoginUserName string

@description('Azure Database for PostgreSQL の管理者パスワードを入力してください')
@secure()
param postgreSqlServerAdminLoginPassword string

var resourceGroupLocation = resourceGroup().location

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

  resource subnetFrontend 'subnets@2022-01-01' = {
    name: 'frontend'
    properties: {
      addressPrefix: '10.0.0.0/24'
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }

  resource subnetOutboundWebApp 'subnets@2022-01-01' = {
    name: 'outbound-webapp'
    properties: {
      addressPrefix: '10.0.1.0/24'
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
      subnetFrontend
    ]
  }

  resource subnetBackend 'subnets@2022-01-01' = {
    name: 'backend'
    properties: {
      addressPrefix: '10.0.2.0/24'
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
    dependsOn: [
      subnetOutboundWebApp
    ]
  }
}

resource privateDnsZoneBlobStorage 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: 'link-${storageAccount.name}'
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
    name: 'link-${cosmosDb.name}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource privateDnsZonePostgreSql 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: 'link-${postgreSql.name}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'plan-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: appServicePlanSkuCode
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: 'app-${workloadName}'
  location: resourceGroupLocation
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    reserved: true
    vnetRouteAllEnabled: true
    siteConfig: {
      linuxFxVersion: 'NODE|16-lts'
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      ipSecurityRestrictions: [
        {
          vnetSubnetResourceId: virtualNetwork::subnetFrontend.id
        }
      ]
      appSettings: [
        {
          name: 'STORAGE_ACCOUNT_CONNECTION_STRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'COSMOS_DB_CONNECTION_STRING'
          value: cosmosDb.listConnectionStrings().connectionStrings[0].connectionString
        }
        {
          name: 'POSTGRESQL_HOST'
          value: '${postgreSql.name}.postgres.database.azure.com'
        }
        {
          name: 'POSTGRESQL_USER'
          value: postgreSqlServerAdminLoginUserName
        }
        {
          name: 'POSTGRESQL_KEY'
          value: postgreSqlServerAdminLoginPassword
        }
      ]
    }
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetId: virtualNetwork::subnetOutboundWebApp.id
  }

  resource vnetConnection 'virtualNetworkConnections@2022-03-01' = {
    name: 'vnet-connection'
    properties: {
      vnetResourceId: virtualNetwork::subnetOutboundWebApp.id
      isSwift: true
    }
  }
}

resource frontDoor 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: 'fd-${workloadName}'
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }

  resource endpoint 'afdEndpoints@2021-06-01' = {
    name: 'cdne-${workloadName}'
    location: 'global'

    resource route 'routes@2021-06-01' = {
      name: 'app'
      properties: {
        originGroup: {
          id: frontDoor::originGroup.id
        }
        supportedProtocols: [
          'Http'
          'Https'
        ]
        patternsToMatch: [
          '/*'
        ]
        forwardingProtocol: 'MatchRequest'
        linkToDefaultDomain: 'Enabled'
        httpsRedirect: 'Enabled'
      }
      dependsOn: [
        frontDoor::originGroup::origin
      ]
    }
  }

  resource originGroup 'originGroups@2021-06-01' = {
    name: 'default'
    properties: {
      loadBalancingSettings: {
        sampleSize: 4
        successfulSamplesRequired: 3
      }
    }

    resource origin 'origins@2021-06-01' = {
      name: 'app'
      properties: {
        hostName: webApp.properties.defaultHostName
        httpPort: 80
        httpsPort: 443
        weight: 1000
        originHostHeader: webApp.properties.defaultHostName
        priority: 1
        sharedPrivateLinkResource: {
          privateLink: {
            id: webApp.id
          }
          groupId: 'sites'
          privateLinkLocation: webApp.location
          requestMessage: 'Private link request from AFD'
        }
      }
    }
  }

  resource securityPolicy 'securitypolicies@2021-06-01' = {
    name: 'default'
    properties: {
      parameters:{
        wafPolicy: {
          id: frontDoorWafPolicy.id
        }
        associations: [
          {
            domains: [
              {
                id: frontDoor::endpoint.id
              }
            ]
            patternsToMatch: [
              '/*'
            ]
          }
        ]
        type: 'WebApplicationFirewall'
      }
    }
  }
}

resource frontDoorWafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: 'fdfp${join(split(workloadName, '-'), '')}'
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      mode: 'Detection'
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.0'
          ruleSetAction: 'Block'
        }
      ]
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${join(split(workloadName, '-'), '')}'
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

resource privateEndpointBlobStorage 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-storage'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'blob'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: virtualNetwork::subnetBackend.id
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
      id: virtualNetwork::subnetBackend.id
    }
  }
}

resource postgreSql 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
  name: 'psql-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: 'GP_Gen5_4'
  }
  properties: {
    createMode: 'Default'
    version: '11'
    minimalTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
    administratorLogin: postgreSqlServerAdminLoginUserName
    administratorLoginPassword: postgreSqlServerAdminLoginPassword
  }
}

resource privateEndpointPostgreSql 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-psql'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'postgresqlServer'
        properties: {
          privateLinkServiceId: postgreSql.id
          groupIds: [
            'postgresqlServer'
          ]
        }
      }
    ]
    subnet: {
      id: virtualNetwork::subnetBackend.id
    }
  }
}
