param workloadName string
param role string
param resourceGroupLocation string
param appServicePlanSkuCode string
param sqlDatabaseCollation string = 'Japanese_CI_AS'
param sqlDatabaseMaxSizeGigabytes int = 32
param sqlServerAdminLoginUserName string
@secure()
param sqlServerAdminLoginPassword string
@allowed(['Default', 'Secondary'])
param sqlDatabaseCreateMode string
param sqlDatabaseSourceDatabaseId string = ''
param frontDoorId string

// Virtual Network --

var sqlDatabaseMaxSizeBytes = sqlDatabaseMaxSizeGigabytes * 1024 * 1024 * 1024
var sqlDatabaseReadOnly = sqlDatabaseCreateMode == 'Secondary'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'vnet-${workloadName}-${role}'
  location: resourceGroupLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

resource subnetDefault 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  name: 'default'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.0.0/24'
    delegations: [
      {
        name: 'delegation'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
}

// App Service --

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'plan-${workloadName}-${role}'
  location: resourceGroupLocation
  sku: {
    name: appServicePlanSkuCode
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}


resource webapp 'Microsoft.Web/sites@2022-03-01' = {
  name: 'app-${workloadName}-${role}'
  location: resourceGroupLocation
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    reserved: true
    vnetRouteAllEnabled: true
    siteConfig: {
      linuxFxVersion: 'NODE|16-lts'
      alwaysOn: !contains([
        'F1', 'D1'], appServicePlanSkuCode)
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      publicNetworkAccess: 'Enabled'
      ipSecurityRestrictions: [
        {
          ipAddress: 'AzureFrontDoor.Backend'
          action: 'Allow'
          tag: 'ServiceTag'
          priority: 300
          name: 'from front door'
          headers: {
            'X-Azure-FDID': [
              frontDoorId
            ]
          }
        }
      ]
      appSettings: [
        {
          name: 'SQL_DATABASE_SERVER'
          value: sqlServer.properties.fullyQualifiedDomainName
        }
        {
          name: 'SQL_DATABASE_USERNAME'
          value: sqlServerAdminLoginUserName
        }
        {
          name: 'SQL_DATABASE_PASSWORD'
          value: sqlServerAdminLoginPassword
        }
        {
          name: 'SQL_DATABASE_NAME'
          value: sqlServerDatabase.name
        }
        {
          name: 'SQL_DATABASE_READONLY'
          value: string(sqlDatabaseReadOnly)
        }
      ]
    }
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetId: subnetDefault.id
  }
}

// SQL Server --

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' ={
  name: 'sql-${workloadName}-${role}'
  location: resourceGroupLocation
  properties: {
    administratorLogin: sqlServerAdminLoginUserName
    administratorLoginPassword: sqlServerAdminLoginPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlServerDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: 'sqldb-${workloadName}'
  parent: sqlServer
  location: resourceGroupLocation
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: sqlDatabaseCollation
    maxSizeBytes: sqlDatabaseMaxSizeBytes
    createMode: sqlDatabaseCreateMode
    sourceDatabaseId: sqlDatabaseSourceDatabaseId != '' ? sqlDatabaseSourceDatabaseId : null
  }
}

resource sqlServerFirewallRule 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output sqlDatabaseId string = sqlServerDatabase.id
output webAppDefaultHostName string = webapp.properties.defaultHostName
