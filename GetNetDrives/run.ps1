using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$user = $Request.Query.User
if (-not $user) {
    $user = $Request.Body.User
    $status = [HttpStatusCode]::BadRequest
    $result = @{"Error" = "Please pass a name on the query string or in the request body."} | ConvertTo-Json
}

$csv_path = "$PSScriptRoot/drivemap.csv"
$drives = Get-Content $csv_path | ConvertFrom-Csv

# main
if ($user) {
    $status = [HttpStatusCode]::OK
    $result = "no drives for $user"

    Write-Host "Trying to get authentication token from managed identity."
    $authToken = Receive-MyMsiGraphToken

    #Invoke REST call to Graph API
    $userId = Get-MyUserID -AuthToken $authToken -UserName $user
    if ($userId) {
        $groups = Get-MyGroupMemberships -AuthToken $authToken -UserID $userId
        Write-Host "Groupmember of: $($groups | ConvertTo-Json)"
    }

    # array with drives
    $drive_map = @()
    $drive_map += $drives | Where-Object { $_.Group -eq "ALL"}
    foreach ($group in $groups) {
        $drive_map += $drives | Where-Object { $_.Group -eq $group}
    }
    $result = [PSCustomObject]@{
        drives = $drive_map | Select-Object -ExcludeProperty Group -Property *
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $result
})