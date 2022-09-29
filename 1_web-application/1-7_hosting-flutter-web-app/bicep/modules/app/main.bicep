param workloadName string
param resourceGroupLocation string = resourceGroup().location
@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuCode string = 'Standard_LRS'

resource storageAccountContents 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${uniqueString(resourceGroup().id, 'contents')}'
  location: resourceGroupLocation
  sku: {
    name: storageAccountSkuCode
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }

  resource blob 'blobServices@2022-05-01' = {
    name: 'default'
    properties: {}

    resource containerContents 'containers@2022-05-01' = {
      name: 'contents'
      properties: {
        publicAccess: 'Blob'
      }
    }
  }
}

resource cdnProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: 'cdn-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: 'Standard_Verizon'
  }
  properties: {}
}

resource cdnProfileEndpoint 'Microsoft.Cdn/profiles/endpoints@2021-06-01' = {
  name: 'cdne-${workloadName}'
  parent: cdnProfile
  location: resourceGroupLocation
  properties: {
    originHostHeader: '${storageAccountContents.name}.blob.${environment().suffixes.storage}'
    originPath: '/contents'
    contentTypesToCompress: [
      'text/plain'
      'text/html'
      'text/css'
      'application/x-javascript'
      'text/javascript'
    ]
    isCompressionEnabled: true
    isHttpAllowed: true
    isHttpsAllowed: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    origins: [
      {
        name: 'origin1'
        properties: {
          hostName: '${storageAccountContents.name}.blob.${environment().suffixes.storage}'
        }
      }
    ]
  }
}
