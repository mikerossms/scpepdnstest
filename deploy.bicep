//Scope
//PARAMETERS
@description('The local environment identifier.  Default: dev')
param localenv string = 'dev'

@description('Location of the Resources. Default: UK South')
param location string = 'uksouth'

@maxLength(4)
@description('Workload short code (max 4 chars)')
param workloadNameShort string = 'PDT'

@description('Workload short code (max 4 chars)')
param workloadName string = 'PDNSTest'

@description('Tags to be applied to all resources')
param tags object = {
  Environment: localenv
  WorkloadName: workloadName
  BusinessCriticality: 'medium'
  CostCentre: 'CSU'
  Owner: 'Mike Ross'
  DataClassification: 'general'
}

param netCIDR string = '10.99.0.0/24'
param dnsServers array = [
  '10.240.0.4'
  '10.240.0.5'
]

param identityVnetName string = 'vnet-identity'
param identityVnetRG string = 'rg-identity'
param identityVnetSub string = '152aa2a3-2d82-4724-b4d5-639edab485af'

param boundaryVnetName string = 'qbx-boundary-vnet-dev'
param boundaryVnetRG string = 'QBX-RG-BOUNDARY-DEV'
param boundaryVnetSub string = '8eef5bcc-4fc3-43bc-b817-048a708743c3'

@secure()
param localAdminPwd string
param localAdminUsername string = 'localvmadmin'


//VARIABLES
var nsgName = toLower('nsg-${workloadName}-${localenv}-${location}')
var vnetName = toLower('vnet-${workloadName}-${localenv}-${location}')
var snetName = toLower('snet-${workloadName}-${localenv}-${location}')
var pDNSStorageBlob = 'privatelink.blob.${environment().suffixes.storage}'
var pDNSStorageFile = 'privatelink.file.${environment().suffixes.storage}'

var storageWOPE = toLower('st${workloadNameShort}${localenv}${location}withoutpe')
var storageWithPE = toLower('st${workloadNameShort}${localenv}${location}withpe')

var vmName = toLower('vm${workloadNameShort}${localenv}')

//RESOURCES

//Get the existing Identity VNET
resource IdentityVnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: identityVnetName
  scope: resourceGroup(identityVnetSub,identityVnetRG)
}

//Get the existing Boundary VNET
resource BoundaryVnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: boundaryVnetName
  scope: resourceGroup(boundaryVnetSub,boundaryVnetRG)
}

//Add an NSG
module NSG './ResourceModules/0.9.0/modules/Microsoft.Network/networkSecurityGroups/deploy.bicep' = {
  name: 'NSG'
  params: {
    location: location
    name: nsgName
    tags: tags
    securityRules: []
  }
}

//Add a VNET + Subnet + Peering + Set DNS on VNET to the Identity AADDS
module pocVnet './ResourceModules/0.9.0/modules/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: 'pocVnet'
  params: {
    location: location
    name: vnetName
    tags: tags
    addressPrefixes: [
      netCIDR
    ]
    subnets: [
      {
        name: snetName
        addressPrefix: netCIDR
        networkSecurityGroupId: NSG.outputs.resourceId
      }
    ]
    dnsServers: dnsServers
    virtualNetworkPeerings: [
      {
        allowForwardedTraffic: false
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: false
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: '${identityVnetName}-to-${vnetName}'
        remoteVirtualNetworkId: IdentityVnet.id
        useRemoteGateways: false
      }
      {
        allowForwardedTraffic: false
        allowGatewayTransit: false
        allowVirtualNetworkAccess: true
        remotePeeringAllowForwardedTraffic: false
        remotePeeringAllowVirtualNetworkAccess: true
        remotePeeringEnabled: true
        remotePeeringName: '${boundaryVnetName}-to-${vnetName}'
        remoteVirtualNetworkId: BoundaryVnet.id
        useRemoteGateways: false
      }
    ]
  }
}

//Add a Private DNS Zone - privatelink.file.core.windows.net - Bind to identity VNET
module privateDNSStorageFile './ResourceModules/0.9.0/modules/Microsoft.Network/privateDnsZones/deploy.bicep' = {
  name: 'privateDNSStorageFile'
  params: {
    name: pDNSStorageFile
    location: 'global'
    virtualNetworkLinks: [
      {
        registrationEnabled: false
        virtualNetworkResourceId: IdentityVnet.id
      }
    ]
  }
}

//Add a Private DNS Zone - privatelink.blob.core.windows.net - Bind to identity VNET
module privateDNSStorageBlob './ResourceModules/0.9.0/modules/Microsoft.Network/privateDnsZones/deploy.bicep' = {
  name: 'privateDNSStorageBlob'
  params: {
    name: pDNSStorageBlob
    location: 'global'
    virtualNetworkLinks: [
      {
        registrationEnabled: false
        virtualNetworkResourceId: IdentityVnet.id
      }
    ]
  }
}


//Add a storage account without PE
module storageAccountsWithoutPE './ResourceModules/0.9.0/modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'storageAccountsWithoutPE'
  params: {
    location: location
    name: storageWOPE
    allowBlobPublicAccess: false
  }
}

//Get the subnetID
resource pocSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: '${pocVnet.outputs.name}/${snetName}'
}

//Add a Storage account with PE and register in PDNS
module storageAccountsWithPE './ResourceModules/0.9.0/modules/Microsoft.Storage/storageAccounts/deploy.bicep' = {
  name: 'storageAccountsWithPE'
  params: {
    location: location
    name: storageWithPE
    allowBlobPublicAccess: false
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            privateDNSStorageBlob.outputs.resourceId
          ]
        }
        service: 'blob'
        subnetResourceID: pocSubnet.id
      }
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            privateDNSStorageFile.outputs.resourceId
          ]
        }
        service: 'file'
        subnetResourceID: pocSubnet.id
      }
    ]
  }
}

//Create a VM
module windowsVM './ResourceModules/0.9.0/modules/Microsoft.Compute/virtualMachines/deploy.bicep' = {
  name: 'windowsVM'
  params: {
    location: location
    name: vmName
    adminUsername: localAdminUsername
    adminPassword: localAdminPwd
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: pocSubnet.id
          }
        ]
        nicSuffix: '-nic-01'
        enableAcceleratedNetworking: false
      }
    ]
    osDisk: {
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_B2s'
  }
}

