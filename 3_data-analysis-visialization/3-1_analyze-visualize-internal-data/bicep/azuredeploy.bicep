@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('Azure Storage Account の SKU を選択してください')
@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuCode string = 'Standard_LRS'

var resourceGroupId = resourceGroup().id
var resourceGroupLocation = resourceGroup().location

resource factory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: 'fd-${workloadName}'
  location: resourceGroupLocation
  properties: {}
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${sys.uniqueString(resourceGroupId)}'
  location: resourceGroupLocation
  kind: 'StorageV2'
  sku: {
    name: storageAccountSkuCode
  }
}

resource linkedServiceStorage 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'AzureBlobStorage1'
  parent: factory
  properties: {
    type: 'AzureBlobStorage'
    typeProperties: {
      connectionString: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
    }
  }
}
