# **Disclaimer:**
#
# The author of this script provides it "as is" without any guarantees or warranties of any kind.
# By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution.
# It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting.
# The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk.

# Required modules:
# Install-Module Az.Accounts, Az.ConnectedMachine, Az.Compute -Scope CurrentUser

$publisher = "Microsoft.Azure.Monitor"

# Prompt the user to enter the resource group name
$resourceGroupName = Read-Host -Prompt "This script can install/update/uninstall AMA extension on Azure Arc servers in a specific resource group; specify your resource group to continue"

# Prompt the user to enter the operating system (Windows/Linux)
$osType = Read-Host -Prompt "Enter the Operating System (Windows/Linux)"

# Prompt the user to enter the operation (Install/Update/Uninstall)
$operation = Read-Host -Prompt "Enter the Operation (Install/Update/Uninstall)"

# If the operation is Install or Update, prompt the user to enter the type handler version
if (($operation -eq "Install") -or ($operation -eq "Update")) {
    $typeHandlerVersion = Read-Host -Prompt "Enter the target Type Handler Version"
}

if ($osType -eq "Windows") {
    $extensionName = "AzureMonitorWindowsAgent"
} elseif ($osType -eq "Linux") {
    $extensionName = "AzureMonitorLinuxAgent"
} else {
    Write-Host "Invalid Operating System specified. Please enter either 'Windows' or 'Linux'." -ForegroundColor Red
    exit
}

if (($operation -ne "Install") -and ($operation -ne "Update") -and ($operation -ne "Uninstall")) {
    Write-Host "Invalid Operation specified. Please enter 'Install', 'Update', or 'Uninstall'." -ForegroundColor Red
    exit
}

# Get all Azure Arc-enabled servers in the specified resource group
$arcServers = Get-AzConnectedMachine -ResourceGroupName $resourceGroupName

# Check if there are any Arc servers with the specified operating system
$osArcServers = $arcServers | Where-Object {
    if ($null -ne $_.OSName) {
        $_.OSName -eq $osType
    } elseif ($null -ne $_.OSType) {
        $_.OSType -eq $osType
    }
}

if ($osArcServers.Count -eq 0) {
    Write-Host "No Azure Arc servers with the specified operating system found in the resource group." -ForegroundColor Red
    exit
}

# Loop through each Arc server and perform the specified operation
foreach ($arcServer in $osArcServers) {
    try {
        $existingExtension = Get-AzConnectedMachineExtension -ResourceGroupName $resourceGroupName `
                                                            -MachineName $arcServer.Name `
                                                            -Name $extensionName `
                                                            -ErrorAction SilentlyContinue

        if ($operation -eq "Install") {
            if ($null -ne $existingExtension) {
                Write-Host "AMA extension already exists on Azure Arc server: $($arcServer.Name). Use Update operation to change version." -ForegroundColor Yellow
                continue
            }

            New-AzConnectedMachineExtension -Name $extensionName `
                                            -ExtensionType $extensionName `
                                            -Publisher $publisher `
                                            -ResourceGroupName $resourceGroupName `
                                            -MachineName $arcServer.Name `
                                            -Location $arcServer.Location `
                                            -TypeHandlerVersion $typeHandlerVersion `
                                            -EnableAutomaticUpgrade `
                                            -AutoUpgradeMinorVersion | Out-Null

            Write-Host "Successfully installed Azure Monitor Agent on Azure Arc server: $($arcServer.Name)" -ForegroundColor Green
        } elseif ($operation -eq "Update") {
            if ($null -eq $existingExtension) {
                Write-Host "AMA extension is not installed on Azure Arc server: $($arcServer.Name). Use Install operation first." -ForegroundColor Yellow
                continue
            }

            $extensionTarget = @{
                "$publisher.$extensionName" = @{
                    targetVersion = $typeHandlerVersion
                }
            }

            Update-AzConnectedExtension -ResourceGroupName $resourceGroupName `
                                        -MachineName $arcServer.Name `
                                        -ExtensionTarget $extensionTarget | Out-Null

            Set-AzConnectedMachineExtension -Name $extensionName `
                                            -ExtensionType $extensionName `
                                            -Publisher $publisher `
                                            -ResourceGroupName $resourceGroupName `
                                            -MachineName $arcServer.Name `
                                            -Location $arcServer.Location `
                                            -TypeHandlerVersion $typeHandlerVersion `
                                            -EnableAutomaticUpgrade `
                                            -AutoUpgradeMinorVersion | Out-Null

            Write-Host "Successfully submitted Azure Monitor Agent update on Azure Arc server: $($arcServer.Name)" -ForegroundColor Green
        } elseif ($operation -eq "Uninstall") {
            if ($null -eq $existingExtension) {
                Write-Host "AMA extension is not installed on Azure Arc server: $($arcServer.Name)" -ForegroundColor Yellow
                continue
            }

            Remove-AzConnectedMachineExtension -ResourceGroupName $resourceGroupName `
                                               -MachineName $arcServer.Name `
                                               -Name $extensionName | Out-Null

            Write-Host "Successfully uninstalled Azure Monitor Agent from Azure Arc server: $($arcServer.Name)" -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to process Azure Arc server: $($arcServer.Name). Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Operation process completed."
