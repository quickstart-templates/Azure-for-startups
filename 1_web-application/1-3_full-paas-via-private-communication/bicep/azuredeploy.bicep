@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('VPN ゲートウェイの SKU を選択してください')
@allowed(['Basic', 'ErGw1AZ', 'ErGw2AZ', 'ErGw3AZ', 'HighPerformance', 'Standard', 'UltraPerformance', 'VpnGw1', 'VpnGw1AZ', 'VpnGw2', 'VpnGw2AZ', 'VpnGw3', 'VpnGw3AZ', 'VpnGw4', 'VpnGw4AZ', 'VpnGw5', 'VpnGw5AZ'])
param virtualNetworkGatewaySkuName string = 'VpnGw1'

@description('VPN ゲートウェイの SKU tier を選択してください（SKU name と同じ値を指定します）')
@allowed(['Basic', 'ErGw1AZ', 'ErGw2AZ', 'ErGw3AZ', 'HighPerformance', 'Standard', 'UltraPerformance', 'VpnGw1', 'VpnGw1AZ', 'VpnGw2', 'VpnGw2AZ', 'VpnGw3', 'VpnGw3AZ', 'VpnGw4', 'VpnGw4AZ', 'VpnGw5', 'VpnGw5AZ'])
param virtualNetworkGatewaySkuTier string = 'VpnGw1'

@description('VPN ゲートウェイで使用するクライアントプロトコルを選択してください')
@allowed(['IKEv2', 'OpenVPN', 'SSTP'])
param vpnClientProtocol string = 'IKEv2'

@description('base64エンコードされたルート証明書の内容を入力してください')
@secure()
param vpnCilentRootCertificatePublicData string

@description('Azure App Service Plan のプランを選択してください')
@allowed(['B1', 'B2', 'B3', 'D1', 'S1', 'S2', 'S3', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSkuCode string = 'P1v2'

@description('Azure SQL Database の照合順序を選択してください')
param sqlDatabaseCollation string = 'Japanese_CI_AS'

@description('Azure SQL Database の最大サイズを入力してください（GB）')
param sqlDatabaseMaxSizeGigabytes int = 32

@description('Azure SQL Server の管理者ユーザー名を入力してください')
param sqlServerAdminLoginUserName string

@description('Azure SQL Server の管理者パスワードを入力してください')
@secure()
param sqlServerAdminLoginPassword string

var resourceGroupLocation = resourceGroup().location
var sqlDatabaseMaxSizeBytes = sqlDatabaseMaxSizeGigabytes * 1024 * 1024 * 1024

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

  resource subnetInboundWebApp 'subnets@2022-01-01' = {
    name: 'inboundWebApp'
    properties: {
      addressPrefix: '10.0.1.0/24'
      privateEndpointNetworkPolicies: 'Disabled'
      serviceEndpoints: [
        {
          service: 'Microsoft.Web'
        }
      ]
    }
  }

  resource subnetOutboundWebApp 'subnets@2022-01-01' = {
    name: 'outboundWebApp'
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
    }
    dependsOn: [
      subnetInboundWebApp
    ]
  }

  resource subnetInboundSqlServer 'subnets@2022-01-01' = {
    name: 'inboundSqlServer'
    properties: {
      addressPrefix: '10.0.3.0/24'
      privateEndpointNetworkPolicies: 'Disabled'
      serviceEndpoints: [
        {
          service: 'Microsoft.Sql'
        }
      ]
    }
    dependsOn: [
      subnetOutboundWebApp
    ]
  }

  resource subnetGateway 'subnets@2022-01-01' = {
    name: 'GatewaySubnet'
    properties: {
      addressPrefix: '10.0.255.0/24'
    }
    dependsOn: [
      subnetInboundSqlServer
    ]
  }
}

resource privateDnsZoneWebApp 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: '${webApp.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource privateDnsZoneSqlServer 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
  properties: {}

  resource link 'virtualNetworkLinks@2020-06-01' = {
    name: '${sqlServer.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'pip-${workloadName}-vgw'
  location: resourceGroupLocation
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2020-11-01' = {
  name: 'vgw-${workloadName}'
  location: resourceGroupLocation
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork::subnetGateway.id
          }
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
    sku: {
      name: virtualNetworkGatewaySkuName
      tier: virtualNetworkGatewaySkuTier
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [
          '10.1.0.0/16'
        ]
      }
      vpnClientProtocols: [
        vpnClientProtocol
      ]
      vpnAuthenticationTypes: [
        'Certificate'
      ]
      vpnClientRootCertificates: [
        {
          name: 'P2SRootCert'
          properties: {
            publicCertData: vpnCilentRootCertificatePublicData
          }
        }
      ]
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'plan-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: appServicePlanSkuCode
  }
  properties: {}
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: 'app-${workloadName}'
  location: resourceGroupLocation
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      alwaysOn: !contains(['F1', 'D1'], appServicePlanSkuCode)
      http20Enabled: true
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'SQL_DATABASE_CONNECTION_STRING'
          value: 'Data Source=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlServer::database.name};User Id=${sqlServerAdminLoginUserName}@${sqlServer.properties.fullyQualifiedDomainName};Password=${sqlServerAdminLoginPassword};'
        }
      ]
    }
    httpsOnly: true
    vnetRouteAllEnabled: true
    virtualNetworkSubnetId: virtualNetwork::subnetOutboundWebApp.id
  }

  resource outboundVnetConnection 'virtualNetworkConnections@2022-03-01' = {
    name: 'outbound'
    properties: {
      vnetResourceId: virtualNetwork::subnetOutboundWebApp.id
      isSwift: true
    }
    dependsOn: [
      virtualNetwork
    ]
  }
}

resource inboundWebAppPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-inbound-web-app'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'inboundWebApp'
        properties: {
          privateLinkServiceId: webApp.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
    subnet: {
      id: virtualNetwork::subnetInboundWebApp.id
    }
  }
  dependsOn: [
    virtualNetwork
  ]

  resource privateDnsZoneGroup 'privateDnsZoneGroups@2021-05-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config1'
          properties: {
            privateDnsZoneId: privateDnsZoneWebApp.id
          }
        }
      ]
    }
  }
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' ={
  name: 'sql-${workloadName}'
  location: resourceGroupLocation
  properties: {
    administratorLogin: sqlServerAdminLoginUserName
    administratorLoginPassword: sqlServerAdminLoginPassword
    version: '12.0'
    publicNetworkAccess: 'Disabled'
  }

  resource database 'databases@2021-11-01' = {
    name: 'sqldb-${workloadName}'
    location: resourceGroupLocation
    sku: {
      name: 'GP_S_Gen5'
      tier: 'GeneralPurpose'
      family: 'Gen5'
      capacity: 1
    }
    properties: {
      collation: sqlDatabaseCollation
      maxSizeBytes: sqlDatabaseMaxSizeBytes
    }
  }
}

resource inboundSqlServerPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'private-endpoint-${workloadName}-inbound-sql-server'
  location: resourceGroupLocation
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'inboundSqlServer'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
    subnet: {
      id: virtualNetwork::subnetInboundSqlServer.id
    }
  }
  dependsOn: [
    virtualNetwork
  ]

  resource privateDnsZoneGroup 'privateDnsZoneGroups@2021-05-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config1'
          properties: {
            privateDnsZoneId: privateDnsZoneSqlServer.id
          }
        }
      ]
    }
  }
}
