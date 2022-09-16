@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('Azure Cache for Redis の SKU を選択してください')
@allowed(['Basic', 'Standard', 'Premium'])
param cacheForRedisSkuName string = 'Basic'

@description('Azure Cache for Redis のキャパシティを選択してください（SKU が Basic/Standard の場合は 0 ～ 6、Premium の場合は 1 ～ 4）')
@minValue(0)
@maxValue(6)
param cacheForRedisCapacity int = 0

@description('Azure Database for MySQL の MySQL のバージョンを選択してください')
@allowed(['5.7', '8.0'])
param mySqlServerVersion string = '8.0'

@description('Azure Database for MySQL の管理者ユーザー名を入力してください')
param mySqlServerAdminLoginUserName string

@description('Azure Database for MySQL の管理者パスワードを入力してください')
@secure()
param mySqlServerAdminLoginPassword string

@description('Azure Key Vault を利用するユーザーの Object ID を入力してください')
param keyVaultAccessPolicyUserObjectId string = ''

@description('Azure App Service Plan のプランを選択してください')
@allowed(['B1', 'B2', 'B3', 'D1', 'S1', 'S2', 'S3', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSkuCode string = 'P1v2'

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
      serviceEndpoints: [
        {
          service: 'Microsoft.Web'
        }
      ]
    }
  }
  
  resource subnetOutboundWebApp 'subnets@2022-01-01' = {
    name: 'outbound-webapp'
    properties: {
      addressPrefix: '10.0.1.0/24'
      privateEndpointNetworkPolicies: 'Disabled'
      serviceEndpoints: [
        {
          service: 'Microsoft.KeyVault'
          locations: [
            '*'
          ]
        }
      ]
      delegations: [
        {
          name: 'delegation'
          properties: {
            serviceName: 'Microsoft.Web/serverFarms'
          }
        }
      ]
    }
    dependsOn: [
      subnetFrontend
    ]
  }
  
  resource subnetBackend 'subnets@2022-01-01' = {
    name: 'backend'
    properties: {
      addressPrefix: '10.0.2.0/24'
    }
    dependsOn: [
      subnetOutboundWebApp
    ]
  }
}

resource privateDnsZoneRedisCache 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.redis.cache.windows.net'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: '${redisCache.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource privateDnsZoneMySql 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.mysql.database.azure.com'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: '${mySql.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource redisCache 'Microsoft.Cache/Redis@2022-05-01' = {
  name: 'redis-${workloadName}'
  location: resourceGroupLocation
  properties: {
    sku: {
      name: cacheForRedisSkuName
      family: cacheForRedisSkuName == 'Premium' ? 'P' : 'C'
      capacity: cacheForRedisCapacity
    }
  }
}

resource privateEndpointRedisCache 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-redis-cache'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'redisCache'
        properties: {
          privateLinkServiceId: redisCache.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
    subnet: {
      id: virtualNetwork::subnetBackend.id
    }
  }
  dependsOn: [
    virtualNetwork
  ]

  resource privateDnsZoneGroup 'privateDnsZoneGroups@2022-01-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config1'
          properties: {
            privateDnsZoneId: privateDnsZoneRedisCache.id
          }
        }
      ]
    }
  }
}

resource mySql 'Microsoft.DBforMySQL/servers@2017-12-01' = {
  name: 'mysql-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2
  }
  properties: {
    administratorLogin: mySqlServerAdminLoginUserName
    administratorLoginPassword: mySqlServerAdminLoginPassword
    version: mySqlServerVersion
    createMode: 'Default'
  }
}

resource privateEndpointMySql 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-mysql'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'mysql'
        properties: {
          privateLinkServiceId: mySql.id
          groupIds: [
            'mysqlServer'
          ]
        }
      }
    ]
    subnet: {
      id: virtualNetwork::subnetBackend.id
    }
  }

  resource privateDnsZoneGroup 'privateDnsZoneGroups@2022-01-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config1'
          properties: {
            privateDnsZoneId: privateDnsZoneMySql.id
          }
        }
      ]
    }
  }
}

var accessPoliciesWebApp = [
  // web app
  {
    tenantId: subscription().tenantId
    objectId: webApp.identity.principalId
    permissions: {
      secrets: [
        'get'
      ]
    }
  }
]

var accessPoliciesManager = [
  {
    tenantId: subscription().tenantId
    objectId: keyVaultAccessPolicyUserObjectId
    permissions: {
      keys: [
        'all'
      ]
      secrets: [
        'all'
      ]
      certificates: [
        'all'
      ]
    }
  }
]

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv-${workloadName}'
  location: resourceGroupLocation
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: subscription().tenantId
    accessPolicies: keyVaultAccessPolicyUserObjectId == '' ? accessPoliciesWebApp : concat(accessPoliciesWebApp, accessPoliciesManager)
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: virtualNetwork::subnetOutboundWebApp.id
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
  }
  dependsOn: [
    webApp
  ]

  resource secretMySqlHost 'secrets@2022-07-01' = {
    name: 'mysql-host'
    properties: {
      value: '${mySql.name}.mysql.database.azure.com'
    }
  }

  resource secretMySqlUser 'secrets@2022-07-01' = {
    name: 'mysql-user'
    properties: {
      value: mySqlServerAdminLoginUserName
    }
  }

  resource secretMySqlKey 'secrets@2022-07-01' = {
    name: 'mysql-key'
    properties: {
      value: mySqlServerAdminLoginPassword
    }
  }

  resource secretRedisCacheKey 'secrets@2022-07-01' = {
    name: 'redis-cache-key'
    properties: {
      value: redisCache.listKeys().primaryKey
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
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    reserved: true
    vnetRouteAllEnabled: true
    vnetImagePullEnabled: false
    siteConfig: {
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
      acrUseManagedIdentityCreds: true
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      ipSecurityRestrictions: [
        {
          vnetSubnetResourceId: virtualNetwork::subnetFrontend.id
          action: 'Allow'
          tag: 'Default'
          priority: 300
        }
        {
          ipAddress: 'GatewayManager'
          action: 'Allow'
          tag: 'ServiceTag'
          priority: 301
          name: 'from Application Gateway'
        }
      ]
      appSettings: [
        {
          name: 'MYSQL_HOST'
          value: '@Microsoft.KeyVault(SecretUri=https://kv-${workloadName}.vault.azure.net/secrets/mysql-host/)'
        }
        {
          name: 'MYSQL_USER'
          value: '@Microsoft.KeyVault(SecretUri=https://kv-${workloadName}.vault.azure.net/secrets/mysql-user/)'
        }
        {
          name: 'MYSQL_KEY'
          value: '@Microsoft.KeyVault(SecretUri=https://kv-${workloadName}.vault.azure.net/secrets/mysql-key/)'
        }
        {
          name: 'REDIS_CACHE_KEY'
          value: '@Microsoft.KeyVault(SecretUri=https://kv-${workloadName}.vault.azure.net/secrets/redis-cache-key/)'
        }
      ]
    }
    httpsOnly: true
    virtualNetworkSubnetId: virtualNetwork::subnetOutboundWebApp.id
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

resource publicIpAppGateway 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'pip-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource applicationGatewayFirewallPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-01-01' = {
  name: 'waf-policy-${workloadName}'
  location: resourceGroupLocation
  properties: {
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Detection'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.1'
        }
      ]
    }
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2022-01-01' = {
  name: 'agw-${workloadName}'
  location: resourceGroupLocation
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: virtualNetwork::subnetFrontend.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: publicIpAppGateway.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'http'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'webapp'
        properties: {
          backendAddresses: [
            {
              fqdn: '${webApp.name}.azurewebsites.net'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'appGatewayBackendHttpSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'default'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'agw-${workloadName}', 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'agw-${workloadName}', 'http')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'http'
        properties: {
          ruleType: 'Basic'
          priority: 10
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'agw-${workloadName}', 'default')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'agw-${workloadName}', 'webapp')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'agw-${workloadName}', 'appGatewayBackendHttpSettings')
          }
        }
      }
    ]
    enableHttp2: true
    firewallPolicy: {
      id: applicationGatewayFirewallPolicy.id
    }
  }
}
