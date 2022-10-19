@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('Azure Storage Account の SKU を選択してください')
@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuCode string = 'Standard_LRS'

@description('Azure App Service Plan のプランを選択してください')
@allowed(['F1', 'B1', 'B2', 'B3', 'D1', 'S1', 'S2', 'S3', 'Y1', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSkuCode string = 'P1v2'

@description('Azure SQL Database の照合順序を選択してください')
param sqlDatabaseCollation string = 'Japanese_CI_AS'

var resourceGroupLocation = resourceGroup().location

// User-assigned Managed Identity --

resource userAssignedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'id-${workloadName}'
  location: resourceGroupLocation
}

// Data Factory --

resource factory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: 'fd-${workloadName}'
  location: resourceGroupLocation
  properties: {}
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: json('{"${userAssignedManagedIdentity.id}": {}}')
  }
}

resource factoryCredencial 'Microsoft.DataFactory/factories/credentials@2018-06-01' = {
  name: 'credential1'
  parent: factory
  properties: {
    type: 'ManagedIdentity'
    typeProperties: {
      resourceId: userAssignedManagedIdentity.id
    }
  }
}

resource factoryLinkedServiceSynapse 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: 'AzureSynapseAnalytics1'
  parent: factory
  properties: {
    type: 'AzureSqlDW'
    typeProperties: {
      connectionString: ''
      credential: {
        referenceName: factoryCredencial.name
        type: 'CredentialReference'
      }
    }
  }
}

// Functions --

resource storageAccountFunc 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${uniqueString(resourceGroup().id, 'func')}'
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

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'plan-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: appServicePlanSkuCode
  }
  kind: 'app'
  properties: {}
}

resource functions 'Microsoft.Web/sites@2022-03-01' = {
  name: 'func-${workloadName}'
  location: resourceGroupLocation
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
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
      ]
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: json('{"${userAssignedManagedIdentity.id}": {}}')
  }
}

// Synapse Analytics --

resource storageAccountSynapse 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'st${uniqueString(resourceGroup().id, 'synapse')}'
  location: resourceGroupLocation
  sku: {
    name: storageAccountSkuCode
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: true
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

resource synapse 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: 'syn-${workloadName}'
  location: resourceGroupLocation
  properties: {
    defaultDataLakeStorage: {
      resourceId: storageAccountSynapse.id
      accountUrl: 'https://${storageAccountSynapse.name}.dfs.${environment().suffixes.storage}'
      filesystem: 'data'
    }
  }
}

resource synapseAdmin 'Microsoft.Synapse/workspaces/administrators@2021-06-01' = {
  name: 'activeDirectory'
  parent: synapse
  properties: {
    login: userAssignedManagedIdentity.name
    sid: userAssignedManagedIdentity.properties.principalId
    tenantId: subscription().tenantId
  }
}

resource synapseADOnlyAuth 'Microsoft.Synapse/workspaces/azureADOnlyAuthentications@2021-06-01' = {
  name: 'default'
  parent: synapse
  properties: {
    azureADOnlyAuthentication: true
  }
}

resource synapseSqlPool 'Microsoft.Synapse/workspaces/sqlPools@2021-06-01' = {
  name: 'syndp${workloadName}'
  parent: synapse
  location: resourceGroupLocation
  sku: {
    name: 'DW100c'
  }
  properties: {
    collation: sqlDatabaseCollation
    storageAccountType: 'LRS'
  }
}
