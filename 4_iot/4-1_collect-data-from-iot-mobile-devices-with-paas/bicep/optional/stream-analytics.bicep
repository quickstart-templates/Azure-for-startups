param workloadName string
param resourceGroupLocation string
param iotHubName string
param sqlServerName string
param sqlServerDatabaseName string
param userAssignedManagedIdentityName string

var iotHubConsumerGroupStreamAnalytics = 'stream-analytics'
var streamAnalyticsInputName = 'iothub'
var streamAnalyticsOutputName = 'streamData'

resource userAssignedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: userAssignedManagedIdentityName
}

resource iotHub 'Microsoft.Devices/IotHubs@2022-04-30-preview' existing = {
  name: iotHubName
}

resource iotHubKeyService 'Microsoft.Devices/IoTHubs/IoTHubKeys@2022-04-30-preview' existing = {
  name: 'service'
  parent: iotHub
}

resource iotHubConsumerGroup 'Microsoft.Devices/IotHubs/eventHubEndpoints/ConsumerGroups@2022-04-30-preview' = {
  name: '${iotHubName}/events/${iotHubConsumerGroupStreamAnalytics}'
  properties: {
    name: iotHubConsumerGroupStreamAnalytics
  }
}

// Stream Analytics --

resource streamAnalytics 'Microsoft.StreamAnalytics/streamingjobs@2021-10-01-preview' = {
  name: 'asa-${workloadName}'
  location: resourceGroupLocation
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: json('{"${userAssignedManagedIdentity.id}": {}}')
  }
  properties: {
    sku: {
      name: 'Standard'
    }
    jobType: 'Cloud'
    transformation: {
      name: 'Transformation'
      properties: {
        query: 'SELECT * INTO [${streamAnalyticsOutputName}] FROM [${streamAnalyticsInputName}]'
      }
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
        iotHubNamespace: iotHubName
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

resource streamAnalyticsOutput 'Microsoft.StreamAnalytics/streamingjobs/outputs@2021-10-01-preview' = {
  name: streamAnalyticsOutputName
  parent: streamAnalytics
  properties: {
    datasource: {
      type: 'Microsoft.Sql/Server/Database'
      properties: {
        table: 'streamData'
        server: sqlServerName
        database: sqlServerDatabaseName
        authenticationMode: 'Msi'
      }
    }
  }
}
