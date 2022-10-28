param workloadName string
param resourceGroupLocation string
param sqlDatabaseCollation string = 'Japanese_CI_AS'
param sqlDatabaseMaxSizeGigabytes int = 32
param sqlServerAdminLoginUserName string
@secure()
param sqlServerAdminLoginPassword string
param userAssignedManagedIdentityName string

var sqlDatabaseMaxSizeBytes = sqlDatabaseMaxSizeGigabytes * 1024 * 1024 * 1024

resource userAssignedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: userAssignedManagedIdentityName
}

// SQL Server --

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: 'sql-${workloadName}'
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
    createMode: 'Default'
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

resource sqlServerAdmin 'Microsoft.Sql/servers/administrators@2021-11-01' = {
  name: 'activeDirectory'
  parent: sqlServer
  properties: {
    administratorType: 'ActiveDirectory'
    login: userAssignedManagedIdentity.name
    sid: userAssignedManagedIdentity.properties.principalId
    tenantId: subscription().tenantId
  }
}

output sqlServerFullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName
output sqlServerName string = sqlServer.name
output sqlServerDatabaseName string = sqlServerDatabase.name
