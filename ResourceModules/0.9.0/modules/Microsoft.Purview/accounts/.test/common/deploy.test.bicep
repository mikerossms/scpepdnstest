targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //
@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'ms.purview-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param location string = deployment().location

@description('Tags')
param tags object = {}

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'pvacom'

@description('Optional. Enable telemetry via a Globally Unique Identifier (GUID).')
param enableDefaultTelemetry bool = false

// =========== //
// Deployments //
// =========== //

// General resources
// =================

module nestedDependencies 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-nestedDependencies'
  params: {
    virtualNetworkName: 'dep-<<namePrefix>>-vnet-${serviceShort}'
    managedIdentityName: 'dep-<<namePrefix>>-msi-${serviceShort}'
  }
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// Diagnostics
// ===========
module diagnosticDependencies '../../../../.shared/dependencyConstructs/diagnostic.dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-diagnosticDependencies'
  params: {
    storageAccountName: 'dep<<namePrefix>>diasa${serviceShort}01'
    logAnalyticsWorkspaceName: 'dep-<<namePrefix>>-law-${serviceShort}'
    eventHubNamespaceEventHubName: 'dep-<<namePrefix>>-evh-${serviceShort}01'
    eventHubNamespaceName: 'dep-<<namePrefix>>-evhns-${serviceShort}01'
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
    name: '<<namePrefix>>${serviceShort}001'
    location: location
    tags: tags
    userAssignedIdentities: {
      '${nestedDependencies.outputs.managedIdentityResourceId}': {}
    }
    managedResourceGroupName: '<<namePrefix>>${serviceShort}001-managed-rg'
    publicNetworkAccess: 'Disabled'
    diagnosticLogsRetentionInDays: 7
    diagnosticStorageAccountId: diagnosticDependencies.outputs.storageAccountResourceId
    diagnosticWorkspaceId: diagnosticDependencies.outputs.logAnalyticsWorkspaceResourceId
    diagnosticEventHubAuthorizationRuleId: diagnosticDependencies.outputs.eventHubAuthorizationRuleId
    diagnosticEventHubName: diagnosticDependencies.outputs.eventHubNamespaceEventHubName
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Reader'
        principalIds: [
          nestedDependencies.outputs.managedIdentityPrincipalId
        ]
        principalType: 'ServicePrincipal'
      }
    ]
    accountPrivateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            nestedDependencies.outputs.purviewAccountPrivateDNSResourceId
          ]
        }
        service: 'account'
        subnetResourceId: nestedDependencies.outputs.subnetResourceId
      }
    ]
    portalPrivateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            nestedDependencies.outputs.purviewPortalPrivateDNSResourceId
          ]
        }
        service: 'portal'
        subnetResourceId: nestedDependencies.outputs.subnetResourceId
      }
    ]
    storageBlobPrivateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            nestedDependencies.outputs.storageBlobPrivateDNSResourceId
          ]
        }
        service: 'blob'
        subnetResourceId: nestedDependencies.outputs.subnetResourceId
      }
    ]
    storageQueuePrivateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            nestedDependencies.outputs.storageQueuePrivateDNSResourceId
          ]
        }
        service: 'queue'
        subnetResourceId: nestedDependencies.outputs.subnetResourceId
      }
    ]
    eventHubPrivateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            nestedDependencies.outputs.eventHubPrivateDNSResourceId
          ]
        }
        service: 'namespace'
        subnetResourceId: nestedDependencies.outputs.subnetResourceId
      }
    ]
    enableDefaultTelemetry: enableDefaultTelemetry
    diagnosticLogCategoriesToEnable: [ 'allLogs' ]
    diagnosticMetricsToEnable: [ 'AllMetrics' ]
    lock: 'CanNotDelete'
  }
}
