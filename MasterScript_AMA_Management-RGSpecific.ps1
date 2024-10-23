# **Disclaimer:**

# The author of this script provides it "as is" without any guarantees or warranties of any kind. 
# By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution. 
# It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting. 
# The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk.

# Prompt the user to enter the resource group name
$resourceGroupName = Read-Host -Prompt "This script can install/uninstall AMA extension on VMs in a specific resource group; specify your resource group to continue"

# Prompt the user to enter the operating system (Windows/Linux)
$osType = Read-Host -Prompt "Enter the Operating System (Windows/Linux)"

# Prompt the user to enter the operation (Install/Uninstall)
$operation = Read-Host -Prompt "Enter the Operation (Install/Uninstall)"

# If the operation is Install, prompt the user to enter the type handler version
if ($operation -eq "Install") {
    $typeHandlerVersion = Read-Host -Prompt "Enter the Type Handler Version"
}

# Get all VMs in the specified resource group
$vms = Get-AzVM -ResourceGroupName $resourceGroupName

# Check if there are any VMs with the specified operating system
$osVms = $vms | Where-Object {
    if ($osType -eq "Windows") {
        $_.StorageProfile.OSDisk.OSType -eq "Windows"
    } elseif ($osType -eq "Linux") {
        $_.StorageProfile.OSDisk.OSType -eq "Linux"
    } else {
        Write-Host "Invalid Operating System specified. Please enter either 'Windows' or 'Linux'." -ForegroundColor Red
        exit
    }
}

if ($osVms.Count -eq 0) {
    Write-Host "No VMs with the specified operating system found in the resource group." -ForegroundColor Red
    exit
}

# Loop through each VM and perform the specified operation
foreach ($vm in $osVms) {
    if ($osType -eq "Windows") {
        $extensionName = "AzureMonitorWindowsAgent"
    } elseif ($osType -eq "Linux") {
        $extensionName = "AzureMonitorLinuxAgent"
    }

    if ($operation -eq "Install") {
        try {
            Set-AzVMExtension -Name $extensionName `
                              -ExtensionType $extensionName `
                              -Publisher "Microsoft.Azure.Monitor" `
                              -ResourceGroupName $resourceGroupName `
                              -VMName $vm.Name `
                              -Location $vm.Location `
                              -TypeHandlerVersion $typeHandlerVersion `
                              -EnableAutomaticUpgrade $true

            Write-Host "Successfully installed Azure Monitor Agent on VM: $($vm.Name)" -ForegroundColor Green
        } catch {
            Write-Host "Failed to install Azure Monitor Agent on VM: $($vm.Name). Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    } elseif ($operation -eq "Uninstall") {
        try {
            Remove-AzVMExtension -ResourceGroupName $resourceGroupName `
                                 -VMName $vm.Name `
                                 -Name $extensionName `
                                 -Force

            Write-Host "Successfully uninstalled Azure Monitor Agent from VM: $($vm.Name)" -ForegroundColor Green
        } catch {
            Write-Host "Failed to uninstall Azure Monitor Agent from VM: $($vm.Name). Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Invalid Operation specified. Please enter either 'Install' or 'Uninstall'." -ForegroundColor Red
        exit
    }
}

Write-Host "Operation process completed."