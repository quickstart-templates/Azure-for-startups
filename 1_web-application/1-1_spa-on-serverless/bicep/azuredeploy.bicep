@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('Azure App Service Plan のプランを選択してください')
@allowed(['F1', 'B1', 'B2', 'B3', 'D1', 'S1', 'S2', 'S3', 'Y1', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param AppServicePlanSkuCode string = 'P1v2'

@description('Azure Storage Account の SKU を選択してください')
@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuName string = 'Standard_LRS'

@description('Azure Static Web App の API におけるリージョンを選択してください（実際には Azure Function をリンクするので内蔵APIは使用しませんが、必須項目のため）')
@allowed(['Central US', 'East US 2', 'East Asia', 'West Europe', 'West US 2'])
param staticAppLocation string = 'East Asia'

@description('Azure Static Web App のビルド構成の app_location を指定してください')
param staticAppConfigAppLocation string = 'nuxt-app'

@description('Azure Static Web App のビルド構成の output_location を指定してください')
param staticAppConfigAppOutputLocation string = '.output/public'

@description('Azure Static Web App のビルド構成の app_build_command を指定してください')
param staticAppConfigAppBuildCommand string = 'npm run generate'

@description('Azure Static Web App にデプロイするコードを含む GitHub リポジトリのURLを指定してください')
param staticAppGithubRepositoryUrl string

@description('Azure Static Web App にデプロイするブランチを入力してください')
param staticAppGithubRepositoryBranch string = 'main'

@description('指定したソースリポジトリに対する GitHub Actions のワークフローファイルの生成をスキップするかどうかを選択してください')
param staticAppSkipGithubActionWorkflowGeneration bool = false

@description('GitHub personal access token を入力してください（必要なスコープ repo, workflow）')
param staticAppGithubAccessToken string = ''

var resourceGroupId = resourceGroup().id
var resourceGroupLocation = resourceGroup().location

resource storageForFunc 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: 'st${sys.uniqueString(resourceGroupId)}'
  location: resourceGroupLocation
  kind: 'StorageV2'
  sku: {
    name: storageAccountSkuName
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'plan-${workloadName}'
  location: resourceGroupLocation
  sku: {
    name: AppServicePlanSkuCode
  }
  properties: {}
}

resource function 'Microsoft.Web/sites@2022-03-01' = {
  name: 'func-${workloadName}'
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
          value: toLower('func-${workloadName}')
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
  name: 'appi-${workloadName}'
  location: resourceGroupLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource staticWebApp 'Microsoft.Web/staticSites@2021-03-01' = {
  name: 'stapp-${workloadName}'
  location: staticAppLocation
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    repositoryUrl: staticAppGithubRepositoryUrl
    repositoryToken: staticAppGithubAccessToken
    branch: staticAppGithubRepositoryBranch
    buildProperties: {
      appLocation: staticAppConfigAppLocation
      outputLocation: staticAppConfigAppOutputLocation
      appBuildCommand: staticAppConfigAppBuildCommand
      skipGithubActionWorkflowGeneration: staticAppSkipGithubActionWorkflowGeneration
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
