@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('Azure Storage Account の SKU を選択してください')
@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuCode string = 'Standard_LRS'

@description('Azure App Service Plan のプランを選択してください')
@allowed(['F1', 'B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSkuCode string = 'F1'

@description('Azure IoT Hub のプランを選択してください')
@allowed(['F1', 'B1', 'B2', 'B3', 'S1', 'S2', 'S3'])
param iotHubSkuCode string = 'F1'

@description('Optional の構成を有効にするか選択してください')
param optional bool = true

@description('Azure SQL Database の照合順序を選択してください')
param sqlDatabaseCollation string = 'Japanese_CI_AS'

@description('Azure SQL Database の最大サイズを入力してください（GB）')
param sqlDatabaseMaxSizeGigabytes int = 32

@description('Azure SQL Server の管理者ユーザー名を入力してください')
param sqlServerAdminLoginUserName string = ''

@description('Azure SQL Server の管理者パスワードを入力してください')
@secure()
param sqlServerAdminLoginPassword string = ''

@description('Azure Service Bus のティアを選択してください')
@allowed(['Basic', 'Standard', 'Premium'])
param serviceBusTier string = 'Standard'

var resourceGroupLocation = resourceGroup().location

// Role definition ID if Storage Account Blob Contributor
var roleDefinitionIdStorageBlobDataContributor = resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource userAssignedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'id-${workloadName}'
  location: resourceGroupLocation
}

// IoT Hub --

var iotHubName = 'iot-${workloadName}'

var iotHubRoutesBase = [
  {
    name: 'default'
    source: 'DeviceMessages'
    condition: 'true'
    endpointNames: [
      'events'
    ]
    isEnabled: true
  }
  {
    name: 'toStorage'
    source: 'DeviceMessages'
    condition: 'true'
    endpointNames: [
      'storage'
    ]
    isEnabled: true
  }
]

var iotHubRoutes = optional ? concat(iotHubRoutesBase, [
  {
    name: 'toServiceBusTopic'
    source: 'DeviceMessages'
    condition: 'true'
    endpointNames: [
      'toServiceBusTopic'
    ]
    isEnabled: true
  }
]) : iotHubRoutesBase

resource iotHub 'Microsoft.Devices/IotHubs@2022-04-30-preview' = {
  name: iotHubName
  location: resourceGroupLocation
  sku: {
    name: iotHubSkuCode
    capacity: 1
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: json('{"${userAssignedManagedIdentity.id}": {}}')
  }
  properties: {
    routing: {
      endpoints: {
        storageContainers: [
          {
            name: 'storage'
            containerName: storageAccountBlobContainer.name
            fileNameFormat: '{iothub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}.json'
            encoding: 'json'
            endpointUri: 'https://${storageAccount.name}.blob.${environment().suffixes.storage}'
            authenticationType: 'identityBased'
            identity: {
              userAssignedIdentity: userAssignedManagedIdentity.id
            }
          }
        ]
        serviceBusTopics: optional ? [
          {
            name: 'toServiceBusTopic'
            endpointUri: 'sb://${serviceBus.outputs.serviceBusName}.servicebus.windows.net'
            entityPath: serviceBus.outputs.serviceBusTopicName
            authenticationType: 'identityBased'
            identity: {
              userAssignedIdentity: userAssignedManagedIdentity.id
            }
          }
        ] : null
      }
      routes: iotHubRoutes
    }
  }
  dependsOn: [
    roleAssignmentStorageAccount
  ]
}

// Storage Account --

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${join(split(workloadName, '-'), '')}'
  location: resourceGroupLocation
  sku: {
    name: storageAccountSkuCode
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource roleAssignmentStorageAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, roleDefinitionIdStorageBlobDataContributor, resourceId('Microsoft.Devices/IotHubs', iotHubName))
  properties: {
    roleDefinitionId: roleDefinitionIdStorageBlobDataContributor
    principalId: userAssignedManagedIdentity.properties.principalId
  }
}

resource storageAccountBlob 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  name: 'default'
  parent: storageAccount
  properties: {}
}

resource storageAccountBlobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: 'data'
  parent: storageAccountBlob
  properties: {}
}

// App Service --

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
          name: 'STORAGE_ACCOUNT_CONNECTION_STRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }      
      ]
    }
    httpsOnly: true
  }
}

var sqlServerName = 'sql-${workloadName}'
var sqlServerDatabaseName = 'sqldb-${workloadName}'

module sqlServer 'optional/sql-server.bicep' = if (optional) {
  name: 'deployment-sql-database'
  params: {
    workloadName: workloadName
    resourceGroupLocation: resourceGroupLocation
    sqlDatabaseCollation: sqlDatabaseCollation
    sqlDatabaseMaxSizeGigabytes: sqlDatabaseMaxSizeGigabytes
    sqlServerAdminLoginUserName: sqlServerAdminLoginUserName
    sqlServerAdminLoginPassword: sqlServerAdminLoginPassword
    sqlServerName: sqlServerName
    sqlServerDatabaseName: sqlServerDatabaseName
    userAssignedManagedIdentityName: userAssignedManagedIdentity.name
    webAppName: webApp.name
  }
}

module streamAnalytics 'optional/stream-analytics.bicep' = if (optional) {
  name: 'deployment-stream-analytics'
  params: {
    workloadName: workloadName
    resourceGroupLocation: resourceGroupLocation
    iotHubName: iotHub.name
    sqlServerName: sqlServerName
    sqlServerDatabaseName: sqlServerDatabaseName
    userAssignedManagedIdentityName: userAssignedManagedIdentity.name
  }
}

module serviceBus 'optional/service-bus.bicep' = if (optional) {
  name: 'deployment-service-bus'
  params: {
    workloadName: workloadName
    resourceGroupLocation: resourceGroupLocation
    serviceBusTier: serviceBusTier
    userAssignedManagedIdentityPrincipalId: userAssignedManagedIdentity.properties.principalId
    iotHubName: iotHubName
  }
}
