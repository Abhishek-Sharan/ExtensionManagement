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

# Get all VMs in the subscription
$vms = Get-AzVM

# Initialize an array to collect the output
$outputData = @()

# Loop through each VM and check extensions
$vms | ForEach-Object {
    $vm = $_

    # Get the VM status with extensions
    $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
    $extensions = ($vmStatus).Extensions | Where-Object { $_.Name -eq "MDE.Windows" -or $_.Name -eq "MDE.Linux" }

    $extensions | ForEach-Object {
        # Parse the JSON message
        $parsedMessage = try {
            $_.Statuses.Message | ConvertFrom-Json
        } catch {
            "Invalid JSON or no message"
        }

        # Limit or format the message for better readability
        $formattedMessage = if ($parsedMessage -is [string]) {
            if ($parsedMessage.Length -gt 100) {
                $parsedMessage.Substring(0, 100) + "..."
            } else {
                $parsedMessage
            }
        } else {
            $parsedMessage
        }

        # Create a custom object for the table output
        $outputData += [PSCustomObject]@{
            "Subscription Name" = (Get-AzContext).Subscription.Name
            "VM Name"           = $vm.Name
            "Extension Name"    = $_.Name
            "Display Status"    = $_.Statuses.DisplayStatus
            "Message"           = $formattedMessage
        }
    }
}

# Output to the console in a formatted table
$outputData | Format-Table -Property "Subscription Name", "VM Name", "Extension Name", "Display Status", "Message"

# Save the output to a CSV file locally
$csvFilePath = "/home/abhishek/MDEExtReport/mdeextreport_output.csv"  # Update the path to where you want to store the CSV
$outputData | Export-Csv -Path $csvFilePath -NoTypeInformation

Write-Host "The report has been saved to: $csvFilePath"
