targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //
@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'ms.healthcareapis.workspaces-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param location string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'hawcom'

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableDefaultTelemetry bool = true

// =========== //
// Deployments //
// =========== //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module resourceGroupResources 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-paramNested'
  params: {
    eventHubConsumerGroupName: '<<namePrefix>>-az-iomt-x-001'
    eventHubNamespaceName: 'dep-<<namePrefix>>-ehns-${serviceShort}'
    managedIdentityName: 'dep-<<namePrefix>>-msi-${serviceShort}'
    storageAccountName: 'dep<<namePrefix>>sa${serviceShort}'
  }
}

// Diagnostics
// ===========
module diagnosticDependencies '../../../../.shared/dependencyConstructs/diagnostic.dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-diagnosticDependencies'
  params: {
    storageAccountName: 'dep<<namePrefix>>diasa${serviceShort}01'
    logAnalyticsWorkspaceName: 'dep-<<namePrefix>>-law-${serviceShort}'
    eventHubNamespaceEventHubName: 'dep-<<namePrefix>>-evh-${serviceShort}'
    eventHubNamespaceName: 'dep-<<namePrefix>>-evhns-${serviceShort}'
    location: location
  }
}

// ============== //
// Test Execution //
// ============== //

module testDeployment '../../deploy.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name)}-test-${serviceShort}'
  params: {
    enableDefaultTelemetry: enableDefaultTelemetry
    name: '<<namePrefix>>${serviceShort}001'
    location: location
    publicNetworkAccess: 'Enabled'
    lock: ''
    fhirServices: [
      {
        name: '<<namePrefix>>-az-fhir-x-001'
        kind: 'fhir-R4'
        workspaceName: '<<namePrefix>>${serviceShort}001'
        corsOrigins: [ '*' ]
        corsHeaders: [ '*' ]
        corsMethods: [ 'GET' ]
        corsMaxAge: 600
        corsAllowCredentials: false
        location: location
        diagnosticLogsRetentionInDays: 7
        diagnosticStorageAccountId: diagnosticDependencies.outputs.storageAccountResourceId
        diagnosticWorkspaceId: diagnosticDependencies.outputs.logAnalyticsWorkspaceResourceId
        diagnosticEventHubAuthorizationRuleId: diagnosticDependencies.outputs.eventHubAuthorizationRuleId
        diagnosticEventHubName: diagnosticDependencies.outputs.eventHubNamespaceEventHubName
        publicNetworkAccess: 'Enabled'
        resourceVersionPolicy: 'versioned'
        smartProxyEnabled: false
        enableDefaultTelemetry: enableDefaultTelemetry
        systemAssignedIdentity: false
        importEnabled: false
        initialImportMode: false
        userAssignedIdentities: {
          '${resourceGroupResources.outputs.managedIdentityResourceId}': {}
        }
        roleAssignments: [
          {
            roleDefinitionIdOrName: resourceId('Microsoft.Authorization/roleDefinitions', '5a1fc7df-4bf1-4951-a576-89034ee01acd')
            principalIds: [
              resourceGroupResources.outputs.managedIdentityPrincipalId
            ]
            principalType: 'ServicePrincipal'
          }
        ]
      }
    ]
    dicomServices: [
      {
        name: '<<namePrefix>>-az-dicom-x-001'
        workspaceName: '<<namePrefix>>${serviceShort}001'
        corsOrigins: [ '*' ]
        corsHeaders: [ '*' ]
        corsMethods: [ 'GET' ]
        corsMaxAge: 600
        corsAllowCredentials: false
        location: location
        diagnosticLogsRetentionInDays: 7
        diagnosticStorageAccountId: diagnosticDependencies.outputs.storageAccountResourceId
        diagnosticWorkspaceId: diagnosticDependencies.outputs.logAnalyticsWorkspaceResourceId
        diagnosticEventHubAuthorizationRuleId: diagnosticDependencies.outputs.eventHubAuthorizationRuleId
        diagnosticEventHubName: diagnosticDependencies.outputs.eventHubNamespaceEventHubName
        publicNetworkAccess: 'Enabled'
        enableDefaultTelemetry: enableDefaultTelemetry
        systemAssignedIdentity: false
        userAssignedIdentities: {
          '${resourceGroupResources.outputs.managedIdentityResourceId}': {}
        }
      }
    ]
  }
}
