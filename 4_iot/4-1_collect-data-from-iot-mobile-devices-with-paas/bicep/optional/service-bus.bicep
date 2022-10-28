param workloadName string
param resourceGroupLocation string
@allowed(['Basic', 'Standard', 'Premium'])
param serviceBusTier string = 'Standard'
param userAssignedManagedIdentityName string
param iotHubName string

// Role definition ID if Azure Service Bus Data Sender
var roleDefinitionIdServiceBusDataSender = resourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39')

resource userAssignedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: userAssignedManagedIdentityName
}

// Service Bus --

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: 'sb-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: serviceBusTier
  }
  properties: {
    zoneRedundant: false
  }
}

resource serviceBusTopic 'Microsoft.ServiceBus/namespaces/topics@2022-01-01-preview' = {
  name: 'fromiothub'
  parent: serviceBus
  properties: {
    enableBatchedOperations: true
  }
}

resource roleAssignmentServiceBus 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: serviceBus
  name: guid(serviceBus.id, roleDefinitionIdServiceBusDataSender, resourceId('Microsoft.Devices/IotHubs', iotHubName))
  properties: {
    roleDefinitionId: roleDefinitionIdServiceBusDataSender
    principalId: userAssignedManagedIdentity.properties.principalId
  }
}

output serviceBusName string = serviceBus.name
output serviceBusTopicName string = serviceBusTopic.name
