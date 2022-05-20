param($eventHubMessages, $TriggerMetadata)

# Write-Host "PowerShell eventhub trigger function called for message array: $eventHubMessages"

$eventHubMessages | ForEach-Object {

    # get Intune device id
    $jsonOut = $_ | convertto-json
    Write-Host "Processing event: $jsonOut"

    $deviceID = $_.properties.IntuneDeviceId
    Write-Host "DeviceID: $deviceID"

    try {
        # request accesstoken from managed identity
        Write-Host "Trying to get authentication token from managed identity."
        $authToken = Receive-MyMsiGraphToken

        #Invoke REST call to Graph API
        Write-Host "Call Microsoft Graph to remove primary user from device."
        Remove-MyPrimaryUser -IntuneDeviceID $deviceID -AuthToken $authToken
    }
    catch {
        Write-Error $_
    }
}
