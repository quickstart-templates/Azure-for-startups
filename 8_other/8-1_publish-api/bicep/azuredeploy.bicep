@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('Azure API Management の SKU 名を入力してください')
@allowed(['Basic', 'Consumption', 'Developer', 'Isolated', 'Premium', 'Standard'])
param apiManagementSkuName string = 'Developer'

@description('Azure API Management を管理する組織名を入力してください')
param apiManagementOrganizationName string

@description('Azure API Management からの通知を受け取る管理者のメールアドレスを入力してください')
param apiManagementAdministratorEmail string

@description('Azure App Service Plan のプランを選択してください')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSkuCode string = 'P1v2'

@description('Azure Storage Account の SKU を選択してください')
@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuCode string = 'Standard_LRS'

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
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
    serviceEndpoints: [
      {
        service: 'Microsoft.Web'
      }
    ]
  }
}

resource subnetOutboundFunc 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  name: 'outbound-func'
  parent: virtualNetwork
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
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
  }
  dependsOn: [
    subnetFrontend
  ]
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

// App Service --

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'plan-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: appServicePlanSkuCode
  }
  kind: 'app'
  properties: {}
}

resource storageAccountFunc 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${uniqueString(resourceGroup().id, 'func')}'
  location: resourceGroupLocation
  sku: {
    name: storageAccountSkuCode
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Enabled'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: subnetOutboundFunc.id
          action: 'Allow'
        }
      ]
    }
  }
}

resource fileServiceFunc 'Microsoft.Storage/storageAccounts/fileServices@2022-05-01' = {
  name: 'default'
  parent: storageAccountFunc
  properties: {}
}

resource shareFunc 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = {
  name: toLower('func-${workloadName}')
  parent: fileServiceFunc
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
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountFunc.name};AccountKey=${storageAccountFunc.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountFunc.name};AccountKey=${storageAccountFunc.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('func-${workloadName}')
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~16'
        }
        {
          name: 'SQL_DATABASE_SERVER'
          value: sqlServer.properties.fullyQualifiedDomainName
        }
        {
          name: 'SQL_DATABASE_USERNAME'
          value: sqlServerAdminLoginUserName
        }
        {
          name: 'SQL_DATABASE_PASSWORD'
          value: sqlServerAdminLoginPassword
        }
        {
          name: 'SQL_DATABASE_NAME'
          value: sqlServerDatabase.name
        }
      ]
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
      ipSecurityRestrictions: [
        {
          vnetSubnetResourceId: subnetFrontend.id
          action: 'Allow'
          tag: 'Default'
          priority: 300
        }
      ]
    }
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetId: subnetOutboundFunc.id
  }
  dependsOn: [
    shareFunc
  ]
}

// API Management --

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: 'apim-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: apiManagementSkuName
    capacity: apiManagementSkuName == 'Consumption' ? 0 : 1
  }
  properties: {
    publisherName: apiManagementOrganizationName
    publisherEmail: apiManagementAdministratorEmail
    virtualNetworkConfiguration: {
      subnetResourceId: subnetFrontend.id
    }
    virtualNetworkType: 'External'
    publicNetworkAccess: 'Enabled'
  }
}

// SQL Server --

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' ={
  name: 'sql-${workloadName}'
  location: resourceGroupLocation
  properties: {
    administratorLogin: sqlServerAdminLoginUserName
    administratorLoginPassword: sqlServerAdminLoginPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlServerDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: 'sqldb-${workloadName}'
  parent: sqlServer
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
    createMode: 'Default'
  }
}

resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}
