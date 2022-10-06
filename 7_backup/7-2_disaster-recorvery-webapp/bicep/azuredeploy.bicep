@description('リソース名に付与する識別用の文字列（プロジェクト名など）を入力してください')
param workloadName string

@description('メインリージョンを選択してください')
@allowed(['East US', 'East US 2', 'South Central US', 'West US 2', 'West US 3', 'Australia East', 'Southeast Asia', 'North Europe', 'Sweden Central', 'UK South', 'West Europe', 'Central US', 'South Africa North', 'Central India', 'East Asia', 'Japan East', 'Korea Central', 'Canada Central', 'France Central', 'Germany West Central', 'Norway East', 'Switzerland North', 'UAE North', 'Brazil South', 'East US 2 EUAP', 'Qatar Central', 'Central US (Stage)', 'East US (Stage)', 'East US 2 (Stage)', 'North Central US (Stage)', 'South Central US (Stage)', 'West US (Stage)', 'West US 2 (Stage)', 'Asia', 'Asia Pacific', 'Australia', 'Brazil', 'Canada', 'Europe', 'France', 'Germany', 'Global', 'India', 'Japan', 'Korea', 'Norway', 'Singapore', 'South Africa', 'Switzerland', 'United Arab Emirates', 'United Kingdom', 'United States', 'United States EUAP', 'East Asia (Stage)', 'Southeast Asia (Stage)', 'East US STG', 'South Central US STG', 'North Central US', 'West US', 'Jio India West', 'Central US EUAP', 'West Central US', 'South Africa West', 'Australia Central', 'Australia Central 2', 'Australia Southeast', 'Japan West', 'Jio India Central', 'Korea South', 'South India', 'West India', 'Canada East', 'France South', 'Germany North', 'Norway West', 'Switzerland West', 'UK West', 'UAE Central', 'Brazil Southeast'])
param regionMain string = 'Japan East'

@description('サブリージョンを選択してください')
@allowed(['East US', 'East US 2', 'South Central US', 'West US 2', 'West US 3', 'Australia East', 'Southeast Asia', 'North Europe', 'Sweden Central', 'UK South', 'West Europe', 'Central US', 'South Africa North', 'Central India', 'East Asia', 'Japan East', 'Korea Central', 'Canada Central', 'France Central', 'Germany West Central', 'Norway East', 'Switzerland North', 'UAE North', 'Brazil South', 'East US 2 EUAP', 'Qatar Central', 'Central US (Stage)', 'East US (Stage)', 'East US 2 (Stage)', 'North Central US (Stage)', 'South Central US (Stage)', 'West US (Stage)', 'West US 2 (Stage)', 'Asia', 'Asia Pacific', 'Australia', 'Brazil', 'Canada', 'Europe', 'France', 'Germany', 'Global', 'India', 'Japan', 'Korea', 'Norway', 'Singapore', 'South Africa', 'Switzerland', 'United Arab Emirates', 'United Kingdom', 'United States', 'United States EUAP', 'East Asia (Stage)', 'Southeast Asia (Stage)', 'East US STG', 'South Central US STG', 'North Central US', 'West US', 'Jio India West', 'Central US EUAP', 'West Central US', 'South Africa West', 'Australia Central', 'Australia Central 2', 'Australia Southeast', 'Japan West', 'Jio India Central', 'Korea South', 'South India', 'West India', 'Canada East', 'France South', 'Germany North', 'Norway West', 'Switzerland West', 'UK West', 'UAE Central', 'Brazil Southeast'])
param regionSub string = 'Japan West'

@description('Azure App Service Plan のプランを選択してください')
@allowed(['F1', 'B1', 'B2', 'B3', 'D1', 'S1', 'S2', 'S3', 'Y1', 'P1v2', 'P2v2', 'P3v2', 'P1v3', 'P2v3', 'P3v3'])
param appServicePlanSkuCode string = 'P1v2'

@description('Azure SQL Database の照合順序を選択してください')
param sqlDatabaseCollation string = 'Japanese_CI_AS'

@description('Azure SQL Database の最大サイズを入力してください（GB）')
param sqlDatabaseMaxSizeGigabytes int = 32

@description('Azure SQL Server の管理者ユーザー名を入力してください')
param sqlServerAdminLoginUserName string

@description('Azure SQL Server の管理者パスワードを入力してください')
@secure()
param sqlServerAdminLoginPassword string

module main 'modules/site.bicep' = {
  name: 'deployment-main'
  params: {
    workloadName: workloadName
    role: 'main'
    resourceGroupLocation: regionMain
    appServicePlanSkuCode: appServicePlanSkuCode
    sqlDatabaseCollation: sqlDatabaseCollation
    sqlDatabaseMaxSizeGigabytes: sqlDatabaseMaxSizeGigabytes
    sqlServerAdminLoginUserName: sqlServerAdminLoginUserName
    sqlServerAdminLoginPassword: sqlServerAdminLoginPassword
    sqlDatabaseCreateMode: 'Default'
    frontDoorId: frontDoor.properties.frontDoorId
  }
}

module sub 'modules/site.bicep' = {
  name: 'deployment-sub'
  params: {
    workloadName: workloadName
    role: 'sub'
    resourceGroupLocation: regionSub
    appServicePlanSkuCode: appServicePlanSkuCode
    sqlDatabaseCollation: sqlDatabaseCollation
    sqlDatabaseMaxSizeGigabytes: sqlDatabaseMaxSizeGigabytes
    sqlServerAdminLoginUserName: sqlServerAdminLoginUserName
    sqlServerAdminLoginPassword: sqlServerAdminLoginPassword
    sqlDatabaseCreateMode: 'Secondary'
    sqlDatabaseSourceDatabaseId: main.outputs.sqlDatabaseId
    frontDoorId: frontDoor.properties.frontDoorId
  }
}


resource frontDoor 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: 'fd-${workloadName}'
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: 'cdne-${workloadName}'
  parent: frontDoor
  location: 'global'
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: 'app'
  parent: endpoint
  properties: {
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'MatchRequest'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
  dependsOn: [
    originMain
    originSub
  ]
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: 'default'
  parent: frontDoor
  properties: {
    healthProbeSettings: {
      probeIntervalInSeconds: 100
      probePath: '/'
      probeProtocol: 'Http'
      probeRequestType: 'HEAD'
    }
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    sessionAffinityState: 'Enabled'
  }
}

resource originMain 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: 'main'
  parent: originGroup
  properties: {
    hostName: main.outputs.webAppDefaultHostName
    httpPort: 80
    httpsPort: 443
    weight: 1000
    originHostHeader: main.outputs.webAppDefaultHostName
    priority: 1
  }
}

resource originSub 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: 'sub'
  parent: originGroup
  properties: {
    hostName: sub.outputs.webAppDefaultHostName
    httpPort: 80
    httpsPort: 443
    weight: 1000
    originHostHeader: sub.outputs.webAppDefaultHostName
    priority: 2
  }
}
