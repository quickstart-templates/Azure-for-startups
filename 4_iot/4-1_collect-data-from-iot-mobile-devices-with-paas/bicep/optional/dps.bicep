param workloadName string
param resourceGroupLocation string
param iotHubName string

var iotHubKey = 'iothubowner'

resource iotHub 'Microsoft.Devices/IotHubs@2022-04-30-preview' existing = {
  name: iotHubName
}

// IoT Hub Device Provisioning Service --

resource provisionServices 'Microsoft.Devices/provisioningServices@2022-02-05' = {
  name: 'provs-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: 'S1'
    capacity: 1
  }
  properties: {
    iotHubs: [
      {
        connectionString: 'HostName=${iotHub.properties.hostName};SharedAccessKeyName=${iotHubKey};SharedAccessKey=${iotHub.listkeys().value}'
        location: iotHub.location
      }
    ]
  }
}
