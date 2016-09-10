# Gateway Locator 

# In most networks either the first or last usable host address in a network is used as the Gateway IP. 
# This script will calculate what the gateway would be based on a given IP in CIDR format
# 
function Get-NetworkDetails {
    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory=$true)][string]$IPCidr
    )

    # Split IP into IP and Mask
    $IPAddress = $IPCidr.Split('/')[0]
    $CidrMask = $IPCidr.Split('/')[1]

    if ( $IPAddress -eq $null -or $CidrMask -eq $null -or $CidrMask -NotIn 8..32  ) {
        Write-Error "IP Address invalid - Check that you have submitted the IP in CIDR format" -ErrorAction Stop
    }  

    # Convert the IP to Binary 
    $HostBinary = ([Convert]::toString(([IPAddress][String]([IPAddress]$($IPAddress)).Address).Address,2)).PadLeft(32, "0") 

    if ($HostBinary -eq $null) {
        Write-Error "IP Address Invalide - Could not convert to IPAddress" -ErrorAction Stop
    }

    #Split the Binary IP into Network/Host based on the Interfaces subnet mask - Keep the Network Binary part (the First part of the string)
    $NetworkId = ($HostBinary | Where {$_ -match "^(.{$($CidrMask)})"} | ForEach{ [PSCustomObject]@{ 'BinaryNet' = $Matches[0] } }).BinaryNet

    $FirstHost = $NetworkId
    #First Host in a network is the Host range all set to 0 except the last bit 
    While ( $FirstHost.Length -le 30 ) {
        $FirstHost = [String]$FirstHost + 0
    }  

    if ($FirstHost.Length -eq 31) {
        $FirstHost = [string]$FirstHost + 1
    }

    #Last Host in a network is the Host range all set to 1 except the last bit 
    $LastHost = $NetworkId
    While ( $LastHost.Length -le 30 ) {
        $LastHost = [String]$LastHost + 1
    }  

    if ($LastHost.Length -eq 31) {
        $LastHost = [string]$LastHost + 0
    }

    # Tell me the Subnet Mask
    $SubnetMask = ""
    While ($SubnetMask.Length -le ([int]$CidrMask-1) ) {
        $SubnetMask = [String]$SubnetMask + 1 
    } 

    While ($SubnetMask.Length -le 31 ) {
        $SubnetMask = [string]$SubnetMask + 0
    }

    # Convert the Binary IP back into Dotted Quad 
    $GatewayDetails = New-Object psobject
    $GatewayDetails | Add-Member -MemberType NoteProperty -Name IP -Value $IPAddress
    $GatewayDetails | Add-Member -MemberType NoteProperty -Name CidrMask -Value $CidrMask
    $GatewayDetails | Add-Member -MemberType NoteProperty -Name SubnetMask -Value  $(([System.Net.IPAddress]"$([System.Convert]::ToInt64($SubnetMask,2))").IPAddressToString) 
    $GatewayDetails | Add-Member -MemberType NoteProperty -Name FirstHost -Value $(([System.Net.IPAddress]"$([System.Convert]::ToInt64($FirstHost,2))").IPAddressToString)
    $GatewayDetails | Add-Member -MemberType NoteProperty -Name LastHost -Value $(([System.Net.IPAddress]"$([System.Convert]::ToInt64($LastHost,2))").IPAddressToString)

    return $GatewayDetails

}
