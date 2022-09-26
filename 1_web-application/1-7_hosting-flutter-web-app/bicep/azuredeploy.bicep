@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('Azure API Management の SKU 名を入力してください')
@allowed(['Basic', 'Consumption', 'Developer', 'Isolated', 'Premium', 'Standard'])
param apiManagementSkuName string = 'Developer'

@description('Azure API Management を管理する組織名を入力してください')
param apiManagementOrganizationName string

@description('Azure API Management からの通知を受け取る管理者のメールアドレスを入力してください')
param apiManagementAdministratorEmail string

@description('Azure App Service Plan のプランを選択してください')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSkuCode string = 'P1v2'

@description('Azure Storage Account の SKU を選択してください')
@allowed(['Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
param storageAccountSkuCode string = 'Standard_LRS'

@description('Azure Cosmos DB のロケーションを選択してください（状況によって利用できないリージョンがあります）')
@allowed(['Brazil Southeast', 'Central US', 'Australia Southeast', 'Canada Central', 'Central India', 'Southeast Asia', 'Switzerland North', 'UAE North', 'East Asia', 'UK West', 'Switzerland West', 'West Europe', 'East US 2', 'West US', 'East US', 'West US 3', 'Australia East', 'Brazil South', 'Germany West Central', 'France Central', 'Japan East', 'Japan West', 'Korea South', 'Germany North', 'France South', 'Australia Central', 'South Central US', 'South Africa North', 'Korea Central', 'South India', 'Norway East', 'Canada East', 'North Central US', 'Norway West', 'North Europe', 'South Africa West', 'Australia Central 2', 'UAE Central', 'UK South', 'West Central US', 'West India', 'West US 2', 'Jio India West', 'Jio India Central', 'Sweden Central', 'Sweden South', 'Qatar Central'])
param cosmosDbLocation string = 'Korea Central'

@description('Azure Cosmos DB の無料利用枠を利用するか否かを選択してください')
param cosmosDbEnableFreeTier bool = false

var resourceGroupLocation = resourceGroup().location

module app 'modules/app/main.bicep' = {
  name: 'deployment-app'
  params: {
    workloadName: workloadName
    resourceGroupLocation: resourceGroupLocation
    storageAccountSkuCode: storageAccountSkuCode
  }
}

module api 'modules/api/main.bicep' = {
  name: 'deployment-api'
  params: {
    workloadName: workloadName
    resourceGroupLocation: resourceGroupLocation
    apimSkuName: apiManagementSkuName
    apimOrganizationName: apiManagementOrganizationName
    apimAdministratorEmail: apiManagementAdministratorEmail
    appServicePlanSkuCode: appServicePlanSkuCode
    storageAccountSkuCode: storageAccountSkuCode
    cosmosDbLocation: cosmosDbLocation
    cosmosDbEnableFreeTier: cosmosDbEnableFreeTier
  }
}
