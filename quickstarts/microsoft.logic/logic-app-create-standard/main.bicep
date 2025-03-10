@description('App Service Hosting Plan Sku Name')
@allowed(['WS1'])
param logicApphostingPlanSkuCode string = 'WS1'


@description('App Service Hosting Plan Sku Tier')
@allowed(['WorkflowStandard'])
param logicApphostingPlanSkuTier string = 'WorkflowStandard'


param serviceName string

param resourceLocation string = resourceGroup().location

@maxLength(20)
param storageAccountName string 

@description('User Managed Identity Name')
var userManagedIdentityName = '${serviceName}-MI'
var logAnalyticsResourceName = '${serviceName}-LA'
var appInsightResourceName = '${serviceName}-AI'

resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: userManagedIdentityName
  location: resourceLocation
}

resource logicAppHostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'ASP-${serviceName}-logicapp'
  location: resourceGroup().location
  sku: {
    name: logicApphostingPlanSkuCode
    tier: logicApphostingPlanSkuTier

  }
  kind: 'elastic'
}


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: resourceLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  identity: {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: {
      '${userManagedIdentity.id}': {}
    }
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    supportsHttpsTrafficOnly: true
  }
}

resource logicAppStandard 'Microsoft.Web/sites@2023-12-01' = {
  name: '${serviceName}-logicapp'
  location: resourceLocation
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userManagedIdentity.id}': {}
    }
  }
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${serviceName}-logicapp.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${serviceName}-logicapp.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    serverFarmId: logicAppHostingPlan.id
    httpsOnly: true
    siteConfig: {
      ftpsState: 'FtpsOnly'
      netFrameworkVersion:'v6.0'
    }
    publicNetworkAccess: 'Enabled'
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsResourceName
  location: resourceLocation
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightResourceName
  location: resourceLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource logicAppsAppSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: logicAppStandard
  name: 'appsettings'
  properties: {
    APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'dotnet'
    WEBSITE_NODE_DEFAULT_VERSION: '~18'
    AzureWebJobsStorage__managedIdentityResourceId: userManagedIdentity.id
    AzureWebJobsStorage__blobServiceUri: storageAccount.properties.primaryEndpoints.blob
    AzureWebJobsStorage__queueServiceUri: storageAccount.properties.primaryEndpoints.queue
    AzureWebJobsStorage__tableServiceUri: storageAccount.properties.primaryEndpoints.table
    AzureWebJobsStorage__credential: 'managedidentity'
    AzureFunctionsJobHost__extensionBundle__id: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
    AzureFunctionsJobHost__extensionBundle__version: '[1.*, 2.0.0)'
    APP_KIND: 'workflowApp'
  }
}

@description('Storage Account Contributor. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-account-contributor')
resource storageAccountContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
}

@description('Storage Blob Data Contributor. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-blob-data-contributor')
resource storageAccountBlobContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

@description('Storage Blob Data Owner. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-blob-data-owner')
resource storageAccountBlobOwnerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
}

@description('Storage Blob Data Owner. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-table-data-contributor')
resource storageAccountTableDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
}

@description('Storage Queue Data Contributor. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-queue-data-contributor')
resource storageAccountQueueContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
}


@description('Give role to Web App system identity for storage queue for function')
resource storageAccountQueueContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, logicAppStandard.id, storageAccountQueueContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageAccountQueueContributorRoleDefinition.id
    principalId: userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Give role to functions system identity for storage for function storage data contributor')
resource storageAccountBlobContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, logicAppStandard.id, storageAccountBlobContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageAccountBlobContributorRoleDefinition.id
    principalId: userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('give role to functions system identity for storage account contributor')
resource storageAccountContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, logicAppStandard.id, storageAccountContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageAccountContributorRoleDefinition.id
    principalId: userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


@description('give role to functions system identity for storage data owner')
resource storageAccountBlobOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, logicAppStandard.id, storageAccountBlobOwnerRoleDefinition.id)
  properties: {
    roleDefinitionId: storageAccountBlobOwnerRoleDefinition.id
    principalId: userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


@description('give role to functions system identity for storage table data contributor')
resource storageAccountTableDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, logicAppStandard.id, storageAccountTableDataContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageAccountTableDataContributorRoleDefinition.id
    principalId: userManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
