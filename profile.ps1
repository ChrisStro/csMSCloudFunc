# Azure Functions profile.ps1
#
# This profile.ps1 will get executed every "cold start" of your Function App.
# "cold start" occurs when:
#
# * A Function App starts up for the very first time
# * A Function App starts up after being de-allocated due to inactivity
#
# You can define helper functions, run commands, or specify environment variables
# NOTE: any variables defined that are not environment variables will get reset after the first execution

# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.
if ($env:MSI_SECRET) {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity
}

# Uncomment the next line to enable legacy AzureRm alias in Azure PowerShell.
# Enable-AzureRmAlias

# You can also define functions or aliases that can be referenced in any of your PowerShell functions.
function Receive-MyMsiGraphToken {
    $Scope = "https://graph.microsoft.com/"
    $tokenAuthUri = $env:IDENTITY_ENDPOINT + "?resource=$Scope&api-version=2019-08-01"

    $splatt = @{
        Method = "Get"
        Uri = $tokenAuthUri
        UseBasicParsing = $true
        Headers = @{
            "X-IDENTITY-HEADER" = "$env:IDENTITY_HEADER"
        }
    }
    $response = Invoke-RestMethod @splatt
    $accessToken = $response.access_token

    if ($accessToken) {
        return $accessToken
    }
    else {
        throw "Could not receive auth token for msgraph, maybe managed Identity is not enabled for this function"
    }
}
# RemovePrimaryUser
function Remove-MyPrimaryUser {
    param (
        $AuthToken,
        $IntuneDeviceID
    )
    $splatt = @{
        Method = "DELETE"
        Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$IntuneDeviceID')/users/`$ref"
        UseBasicParsing = $true
        ContentType = "application/json"
        # ResponseHeadersVariable = "RES"
        Headers = @{
            'Content-Type'='application/json'
            'Authorization'= 'Bearer ' +  $AuthToken
        }
    }
    $result = (Invoke-RestMethod @splatt).value

    if ([string]::IsNullOrEmpty($result)) {
        return $true
    }
    else {
        throw "Removing primary user from device ('$IntuneDeviceID') failed"
    }
}
# GetNetDrives
function Get-MyUserID {
    param (
        $AuthToken,
        $UserName
    )
    $splatt = @{
        Method = "GET"
        Uri = "https://graph.microsoft.com/beta/users?`$filter=startswith(userPrincipalName,'$UserName')&`$select=id"
        UseBasicParsing = $true
        ContentType = "application/json"
        # ResponseHeadersVariable = "RES"
        Headers = @{
            'Content-Type'='application/json'
            'Authorization'= 'Bearer ' +  $AuthToken
        }
    }
    $result = Invoke-RestMethod @splatt

    if ([string]::IsNullOrEmpty($result)) {
        throw "Error getting user id for $Username"
    }
    return $result.value.id
}
function Get-MyGroupMemberships {
    param (
        $AuthToken,
        $UserID
    )
    $splatt = @{
        Method = "GET"
        Uri = "https://graph.microsoft.com/beta/users/$UserID/memberOf"
        UseBasicParsing = $true
        ContentType = "application/json"
        # ResponseHeadersVariable = "RES"
        Headers = @{
            'Content-Type'='application/json'
            'Authorization'= 'Bearer ' +  $AuthToken
        }
    }
    $result = Invoke-RestMethod @splatt

    if ([string]::IsNullOrEmpty($result)) {
        return @()
    }
    return $result.value.displayName
}
function Get-NetDrives {
    param (
        $AuthToken,
        $UserName
    )
    $splatt = @{
        Method = "DELETE"
        Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$IntuneDeviceID')/users/`$ref"
        UseBasicParsing = $true
        ContentType = "application/json"
        # ResponseHeadersVariable = "RES"
        Headers = @{
            'Content-Type'='application/json'
            'Authorization'= 'Bearer ' +  $AuthToken
        }
    }
    $result = (Invoke-RestMethod @splatt).value

    if ([string]::IsNullOrEmpty($result)) {
        return $true
    }
    else {
        throw "Removing primary user from device ('$IntuneDeviceID') failed"
    }
}
