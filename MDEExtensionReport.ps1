# Disclaimer section (unchanged)
Write-Host "************************* DISCLAIMER *************************"
Write-Host "The author of this script provides it 'as is' without any guarantees or warranties of any kind."
Write-Host "By using this script, you acknowledge that you are solely responsible for any damage, data loss, or other issues that may arise from its execution."
Write-Host "It is your responsibility to thoroughly test the script in a controlled environment before deploying it in a production setting."
Write-Host "The author will not be held liable for any consequences resulting from the use of this script. Use at your own risk."
Write-Host "***************************************************************"
Write-Host ""

# Prompt the user for consent after displaying the disclaimer
$consent = Read-Host -Prompt "Do you consent to proceed with the script? (Type 'yes' to continue)"

# If the user does not consent, exit the script
if ($consent -ne "yes") {
    Write-Host "You did not consent. Exiting the script."
    exit
}

# If consent is given, continue with the rest of the script
Write-Host "Proceeding with the script..."

$csvFilePath = "/home/abhishek/MDEExtReport/mdeextreport_output.csv"  # Update with your desired path

# Ensure the folder exists
$folderPath = [System.IO.Path]::GetDirectoryName($csvFilePath)
if (-not (Test-Path -Path $folderPath)) {
    Write-Host "The folder does not exist. Creating folder: $folderPath"
    New-Item -Path $folderPath -ItemType Directory -Force
}

# Retrieve the VM and extension status for both Windows and Linux VMs
$extensionStatus = Get-AzVM | ForEach-Object { 
    $vm = $_
    $osType = $vm.StorageProfile.OsDisk.OsType  # Determine OS type (Windows or Linux)
    $extensionName = if ($osType -eq "Windows") { "MDE.Windows" } else { "MDE.Linux" }  # Set the extension name based on OS type
    
    # Get the subscription name (simplified to only the subscription name, no extra info)
    $subscriptionName = (Get-AzContext).Subscription.Name

    $resourceGroupName = $vm.ResourceGroupName  # Get the resource group name
    
    # Get the extensions for the VM
    $extensions = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name
    $mdeExtension = $extensions | Where-Object { $_.Name -eq $extensionName }

    if ($mdeExtension) {
        # If the MDE extension is found, display its status
        $status = $mdeExtension.Statuses | Select-Object -First 1

        # Check if the status indicates success or failure
        if ($status.Code -eq "ProvisioningState/succeeded") {
            # Success case
            [PSCustomObject]@{
                SubscriptionName  = $subscriptionName
                ResourceGroup     = $resourceGroupName
                VMName            = $vm.Name
                OS                = $osType
                ExtensionName     = $mdeExtension.Name
                ProvisioningState = $mdeExtension.ProvisioningState
                Status            = $status.Code
                Message           = "Successfully deployed"
            }
        } else {
            # Failure case: Display failure status and message
            [PSCustomObject]@{
                SubscriptionName  = $subscriptionName
                ResourceGroup     = $resourceGroupName
                VMName            = $vm.Name
                OS                = $osType
                ExtensionName     = $mdeExtension.Name
                ProvisioningState = $mdeExtension.ProvisioningState
                Status            = $status.Code
                Message           = $status.Message
            }
        }
    } else {
        # If the MDE extension is missing, indicate it in the table
        [PSCustomObject]@{
            SubscriptionName  = $subscriptionName
            ResourceGroup     = $resourceGroupName
            VMName            = $vm.Name
            OS                = $osType
            ExtensionName     = $extensionName
            ProvisioningState = "Extension Missing"
            Status            = "N/A"
            Message           = "Extension is not installed"
        }
    }
}

# Output to table format for console display
$extensionStatus | Format-Table -AutoSize

# Export to CSV file
$extensionStatus | Export-Csv -Path $csvFilePath -NoTypeInformation -Force

Write-Host "MDE extension status report has been written to $csvFilePath"
