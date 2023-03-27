param (
    [String]$localenv = 'dev',
    [Bool]$dologin = $true
)

#Get the local environment into a consistent state
$localenv = $localenv.ToLower()

$subId = "8eef5bcc-4fc3-43bc-b817-048a708743c3"
$rgName = "RG-SystemC-POC"
$location = "uksouth"

if ((!$localenv) -and ($localenv -ne 'dev') -and ($localenv -ne 'prod')) {
    Write-Host "Error: Please specify a valid environment to deploy to [dev | prod]" -ForegroundColor Red
    exit 1
}

write-host "Working with environment: $localenv"

#Login to azure (if required) - if you have already done this once, then it is unlikley you will need to do it again for the remainer of the session
if ($dologin) {
    Write-Host "Log in to Azure using an account with permission to create Resource Groups and Assign Permissions" -ForegroundColor Green
    Connect-AzAccount -Subscription $subID
} else {
    Write-Warning "Login skipped"
}

#check that the subscription ID we are connected to matches the one we want and change it to the right one if not
Write-Host "Checking we are connected to the correct subscription (context)" -ForegroundColor Green
if ((Get-AzContext).Subscription.Id -ne $subID) {
    #they dont match so try and change the context
    Write-Warning "Changing context to subscription: $subID"
    $context = Set-AzContext -SubscriptionId $subID

    if ($context.Subscription.Id -ne $subID) {
        Write-Error "ERROR: Cannot change to subscription: $subID"
        exit 1
    }

    Write-Host "Changed context to subscription: $subID" -ForegroundColor Green
}

#Check if privateDnsZones is registered with the subscription.  Enable it if not
Write-Host "Checking if privateDnsZones is registered with the subscription" -ForegroundColor Green
$privateDnsZones = Get-AzResourceProvider -ProviderNamespace Microsoft.Network | Where-Object { $_.RegistrationState -eq "Registered" }
if (!$privateDnsZones) {
    Write-Host "Enabling privateDnsZones" -ForegroundColor Green
    Register-AzResourceProvider -ProviderNamespace Microsoft.Network
}



#Create a resource group for the resources if it does not already exist then check it has been created successfully
if (-not (Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Resource Group: $rgName" -ForegroundColor Green
    if (-not (New-AzResourceGroup -Name $rgName -Location $location)) {
        Write-Error "ERROR: Cannot create Resource Group: $rgName"
        exit 1
    }
}

#Deploy the diagnostic.bicep code to that RG we just created
Write-Host "Deploying deploy.bicep to Resource Group: $rgName" -ForegroundColor Green
New-AzResourceGroupDeployment -Name "Deploy" -ResourceGroupName $rgName -TemplateFile "./deploy.bicep" -Verbose