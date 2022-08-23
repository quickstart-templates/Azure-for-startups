param identifier string

@allowed(['Y1', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param planSkuName string = 'P1v2'

@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageSkuName string = 'Standard_LRS'

@allowed(['Central US', 'East US 2', 'East Asia', 'West Europe', 'West US 2'])
param staticAppLocation string = 'East Asia'
param appLocation string = 'nuxt-app'
param appArtifactLocation string = '.output/public'
param appBuildCommand string = 'npm run generate'
param skipGithubActionWorkflowGeneration bool = false
param githubRepositoryBranch string = 'main'
param githubRepositoryUrl string
param githubAccessToken string

var resourceGroupId = resourceGroup().id
var resourceGroupLocation = resourceGroup().location

resource storageForFunc 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: 'st${sys.uniqueString(resourceGroupId)}'
  location: resourceGroupLocation
  kind: 'StorageV2'
  sku: {
    name: storageSkuName
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: 'plan-${identifier}'
  location: resourceGroupLocation
  sku: {
    name: planSkuName
    capacity: 1
  }
}

resource function 'Microsoft.Web/sites@2022-03-01' = {
  name: 'func-${identifier}'
  location: resourceGroupLocation
  kind: 'functionapp'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsDashboard'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageForFunc.name};AccountKey=${storageForFunc.listKeys().keys[0].value}'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageForFunc.name};AccountKey=${storageForFunc.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageForFunc.name};AccountKey=${storageForFunc.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('func-${identifier}')
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference(appInsights.id, '2020-02-02').InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: reference(appInsights.id, '2020-02-02').ConnectionString
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
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${identifier}'
  location: resourceGroupLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource staticWebApp 'Microsoft.Web/staticSites@2021-03-01' = {
  name: 'stapp-${identifier}'
  location: staticAppLocation
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    repositoryUrl: githubRepositoryUrl
    repositoryToken: githubAccessToken
    branch: githubRepositoryBranch
    buildProperties: {
      appLocation: appLocation
      appArtifactLocation: appArtifactLocation
      appBuildCommand: appBuildCommand
      skipGithubActionWorkflowGeneration: skipGithubActionWorkflowGeneration
    }
  }

  resource linkedBackend 'linkedBackends@2022-03-01' = {
    name: 'backend'
    properties: {
      region: function.location
      backendResourceId: function.id
    }
  }
}
