param($eventGridEvent, $TriggerMetadata)

# Make sure to pass hashtables to Out-String so they're logged correctly
# $eventGridEvent | Out-String | Write-Host

$tAction = ($eventGridEvent.data.authorization.action -split "/")[-2]
$tVmName = ($eventGridEvent.data.authorization.scope -split "/")[-1]
$tSubscriptionId = $eventGridEvent.data.subscriptionId

# preflight check
Write-Host "Check trigger action"
if (($tAction -ne "start") -and ($tAction -ne "deallocate")) {
    Write-Warning "Unsupported action: [$tAction], we stop here"
    break
}
Write-Host "##################### Triggerinformation #####################"
Write-Host "Vm: $tVmName"
Write-Host "Action: $tAction"
Write-Host "Subscription: $tSubscriptionId"

Write-Host "Get information about trigger vm"
$context = Set-AzContext -SubscriptionId $tSubscriptionId

if ($context.Subscription.Id -ne $tSubscriptionId) {
    # break if no access
    throw "Azure Function have no access to subscription with id [$tSubscriptionId], check permissions on managed identity"
}

$tVm = Get-AzVM -Name $tVmName
$bindingGroup = $tVm.Tags.bootbinding

if (!$bindingGroup) {
    Write-Warning "No tag with bootbinding found for [$tVmName], check your tagging"
    break
}

# main
Write-Host "Query all subscriptions"
$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) {

    Write-Host "Set context to subscription [$($sub.Name)] with id [$($sub.id)]"
    $context = Set-AzContext -SubscriptionId $sub.id

    if (!$context) {

        # break if no access
        Write-Warning "Azure Function have no access to subscription with id [$tSubscriptionId], check permissions on managed identity"
        return
    }

    # get vms with bootbinding tag
    $azVMs = Get-AzVM -Status -ErrorAction SilentlyContinue |  Where-Object { ($_.Tags.bootbinding -eq $bindingGroup) -and ($_.Name -ne $tVmName) }
    if ($azVMs) {
        $azVMs | ForEach-Object {
            Write-Host "VM [$($_.Name)] is in same bindinggroup, perform needed action "
            $vmSplatt = @{
                Name              = $_.Name
                ResourceGroupName = $_.ResourceGroupName
                NoWait            = $true
            }
            switch ($tAction) {
                start {
                    Write-Host "Start VM"
                    $_.PowerState -ne 'VM running' ? (Start-AzVM @vmSplatt | Out-Null) : (Write-Warning "$($_.Name) is already running")
                }
                deallocate {
                    Write-Host "Stop VM"
                    $_.PowerState -ne 'VM deallocated' ? (Stop-AzVM @vmSplatt -Force | Out-Null) : (Write-Warning "$($_.Name) is already running")
                }
                Default {}
            }
        }
    }
}