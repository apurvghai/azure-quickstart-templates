# Ensure the script is running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator."
    exit
}

# Check if Az CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Az CLI is not installed. Do you want to install it now? (Y/N)"
    $response = Read-Host
    if ($response -eq 'Y') {
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
        Start-Process msiexec.exe -ArgumentList '/I AzureCLI.msi /quiet' -Wait
        Remove-Item .\AzureCLI.msi
    } else {
        Write-Host "Az CLI is required to run this script. Exiting."
        exit
    }
}

# Login to Azure
Write-Host "Please enter your Azure Tenant ID:"
$tenantId = Read-Host

Write-Host "Please login to your Azure account..."
az login --tenant $tenantId


# Prompt for resource group name
Write-Host "Please enter the name of the resource group to use or create:"
$resourceGroupName = Read-Host

# Check if resource group exists
$resourceGroup = az group show --name $resourceGroupName -o json -ErrorAction SilentlyContinue

if ($null -eq $resourceGroup) {
    Write-Host "Resource group '$resourceGroupName' does not exist. Creating resource group..."
    az group create --name $resourceGroupName --location 'westus2'

} else {
    Write-Host "Resource group '$resourceGroupName' already exists."
}

# Deploy resources
Write-Host "Deploying resources to '$resourceGroupName'..."
az deployment group create --resource-group $resourceGroupName --template-file main.json --parameters main.parameters.json

Write-Host "Deployment complete."