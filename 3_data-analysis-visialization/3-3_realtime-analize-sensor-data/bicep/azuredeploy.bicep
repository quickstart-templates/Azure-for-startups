@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('Azure IoT Hub のプランを選択してください')
@allowed(['F1', 'B1', 'B2', 'B3', 'S1', 'S2', 'S3'])
param iotHubSkuCode string = 'F1'

@description('Azure Stream Analytics 用の Azure Storage Account の SKU を選択してください')
@allowed(['Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuCodeStreamAnalytics string = 'Standard_LRS'

@description('Azure Synapse Analytics 用の Azure Storage Account の SKU を選択してください')
@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuCodeSynapse string = 'Standard_LRS'

@description('Azure SQL Database の照合順序を選択してください')
param sqlDatabaseCollation string = 'Japanese_CI_AS'

var resourceGroupLocation = resourceGroup().location

var synapseAnalyticsWorkspaceName = 'synw-${workloadName}'
var streamAnalyticsInputName = 'iothub'
var iotHubConsumerGroupStreamAnalytics = 'stream-analytics'

// IoT Hub --

resource iotHub 'Microsoft.Devices/IotHubs@2022-04-30-preview' = {
  name: 'iot-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: iotHubSkuCode
    capacity: 1
  }
  properties: {
    routing: {
      routes: [
        {
          name: 'default'
          source: 'DeviceMessages'
          condition: 'true'
          endpointNames: [
            'events'
          ]
          isEnabled: true
        }      
      ]
    }
  }
}

resource iotHubKeyService 'Microsoft.Devices/IoTHubs/IoTHubKeys@2022-04-30-preview' existing = {
  name: 'service'
  parent: iotHub
}

resource iotHubConsumerGroup 'Microsoft.Devices/IotHubs/eventHubEndpoints/ConsumerGroups@2022-04-30-preview' = {
  name: '${iotHub.name}/events/${iotHubConsumerGroupStreamAnalytics}'
  properties: {
    name: iotHubConsumerGroupStreamAnalytics
  }
}

// Stream Analytics --

resource streamAnalytics 'Microsoft.StreamAnalytics/streamingjobs@2021-10-01-preview' = {
  name: 'asa-${workloadName}'
  location: resourceGroupLocation
  properties: {
    sku: {
      name: 'Standard'
    }
    jobType: 'Cloud'
    transformation: {
      name: 'Transformation'
      properties: {
        query: 'SELECT * INTO [syanapse] FROM [${streamAnalyticsInputName}]'
      }
    }
    jobStorageAccount: {
      authenticationMode: 'Msi'
      accountName: storageAccountStreamAnalytics.name
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource storageAccountStreamAnalytics 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${uniqueString(resourceGroup().id, 'stream-analytics')}'
  location: resourceGroupLocation
  sku: {
    name: storageAccountSkuCodeStreamAnalytics
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource streamAnalyticsInput 'Microsoft.StreamAnalytics/streamingjobs/inputs@2021-10-01-preview' = {
  name: streamAnalyticsInputName
  parent: streamAnalytics
  properties: {
    type: 'Stream'
    datasource: {
      type: 'Microsoft.Devices/IotHubs'
      properties: {
        iotHubNamespace: iotHub.name
        sharedAccessPolicyName: 'service'
        sharedAccessPolicyKey: iotHubKeyService.listKeys().primaryKey
        endpoint: 'messages/events'
        consumerGroupName: iotHubConsumerGroupStreamAnalytics
      }
    }
    serialization: {
      type: 'Json'
      properties: {
        encoding: 'UTF8'
      }
    }
  }
}

// Synapse Analytics --

resource storageAccountSynapse 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${uniqueString(resourceGroup().id, 'synapse')}'
  location: resourceGroupLocation
  sku: {
    name: storageAccountSkuCodeSynapse
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      resourceAccessRules: [
        {
          tenantId: subscription().tenantId
          resourceId: resourceId('Microsoft.Synapse/workspaces', synapseAnalyticsWorkspaceName)
        }
      ]
    }
  }
}

resource blobServiceSynapse 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  name: 'default'
  parent: storageAccountSynapse
}

resource containerSynapse 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: 'data'
  parent: blobServiceSynapse
}

resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseAnalyticsWorkspaceName
  location: resourceGroupLocation
  properties: {
    defaultDataLakeStorage: {
      resourceId: storageAccountSynapse.id
      accountUrl: 'https://${storageAccountSynapse.name}.dfs.${environment().suffixes.storage}'
      filesystem: 'data'
    }
    trustedServiceBypassEnabled: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource synapseADOnlyAuth 'Microsoft.Synapse/workspaces/azureADOnlyAuthentications@2021-06-01' = {
  name: 'default'
  parent: synapseWorkspace
  properties: {
    azureADOnlyAuthentication: true
  }
}

resource synapseAllowAllAzureIps 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  name: 'AllowAllWindowsAzureIps'
  parent: synapseWorkspace
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource synapseSqlPool 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = {
  name: 'syndp${join(split(workloadName, '-'), '')}'
  parent: synapseWorkspace
  location: resourceGroupLocation
  sku: {
    name: 'DW100c'
  }
  properties: {
    collation: sqlDatabaseCollation
    storageAccountType: 'LRS'
  }
}
