# Basic Network Module 
# --- This module consists of a set of basic powershell functions for some common network based work you might want to do 
# Written By MF2201 - 24/08/2016

function Get-NetworkDetails {
    <#
    .SYNOPSIS 
    Provides Basic network information about a given IP Adddress

    .DESCRIPTION 
    Given an IP Address in CIDR format calculate and return the following details about the Network the IP is part of:
    - The CidrMask for the Network
    - The Subnet Mask for the Network of the IP 
    - The Network ID for the Network 
    - The First usable host IP address in the Network
    - The Last usable host IP address in the Network 

    .EXAMPLE 
    Get-GatewayAddress -IPCidr 10.1.1.3/24 

    IP         : 10.1.1.3
    CidrMask   : 22
    SubnetMask : 255.255.252.0
    NetworkId  : 10.1.0.0
    FirstIP    : 10.1.0.1
    LastIP     : 10.1.3.254


    .PARAMETER IPCidr 
    A host IP Address with CIDR Mask 

    .INPUTS 
    None. You cannont pipe objects 

    .OUTPUTS
    PSObject. Returns a Custom PS object with the IP Details 
    #>
    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory=$true)][string]$IPCidr
    )

    # Split IP into IP and Mask
    $IPAddress = $IPCidr.Split('/')[0]
    $CidrMask = $IPCidr.Split('/')[1]

    if ( $IPAddress -eq $null -or $CidrMask -eq $null -or $CidrMask -NotIn 8..32  ) {
        throw "IP Address invalid - Check that you have submitted the IP in CIDR format"
    }  

    # Convert the IP to Binary 
    $HostBinary = ([Convert]::toString(([IPAddress][String]([IPAddress]$($IPAddress)).Address).Address,2)).PadLeft(32, "0") 

    if ($HostBinary -eq $null) {
        throw "Invalid IP Address"
    }

    #Split the Binary IP into Network/Host based on the Interfaces subnet mask - Keep the Network Binary part (the First part of the string)
    $NetworkSection = ($HostBinary | Where {$_ -match "^(.{$($CidrMask)})"} | ForEach{ [PSCustomObject]@{ 'BinaryNet' = $Matches[0] } }).BinaryNet

    $NetworkId = $NetworkSection
    $FirstIP = $NetworkSection
    $LastIP = $NetworkSection
    

    #Tell us what the Network ID is 
    While ( $NetworkId.Length -le 31 ) {
        $NetworkId = [string]$NetworkId + "0"
    }

     # Find the First usable IP in the network - Fill the host section with 0 except the last Number  
    While ( $FirstIP.Length -le 30 ) {
        $FirstIP = [String]$FirstIP + 0
    }  

    if ($FirstIP.Length -eq 31) {
        $FirstIP = [string]$FirstIP + 1
    }

    # Find the Last usable IP in the network - Fill the host section with 0 except the last Number   
    While ( $LastIP.Length -le 30 ) {
        $LastIP = [String]$LastIP + 1
    }  

    if ($LastIP.Length -eq 31) {
        $LastIP = [string]$LastIP + 0
    }

    # Tell me the Subnet Mask
    $SubnetMask = ""
    While ($SubnetMask.Length -le ([int]$CidrMask -1 ) ) {
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
    $GatewayDetails | Add-Member -MemberType NoteProperty -Name NetworkId -Value $(([System.Net.IPAddress]"$([System.Convert]::ToInt64($NetworkId,2))").IPAddressToString) 
    $GatewayDetails | Add-Member -MemberType NoteProperty -Name FirstIP -Value $(([System.Net.IPAddress]"$([System.Convert]::ToInt64($FirstIP,2))").IPAddressToString)
    $GatewayDetails | Add-Member -MemberType NoteProperty -Name LastIP -Value $(([System.Net.IPAddress]"$([System.Convert]::ToInt64($LastIP,2))").IPAddressToString)
    $GatewayDetails | Add-Member -MemberType NoteProperty -Name NetworkBinary -Value $NetworkId
    $GatewayDetails | Add-Member -MemberType NoteProperty -Name HostBinary -Value $HostBinary

    return $GatewayDetails
}

function Get-InterfaceIPs {
    <#
    .SYNOPSIS 
    Find all the active Interfaces and return their IP Addresses

    .DESCRIPTION 
    A simplified version of get-netipaddress, only gets the UP Interfaces and returns IP addresses that have been assigned via DHCP or manual 
    Does not include internal, loopback or IPv6 IP addreseses

    .EXAMPLE 

    Get-InterfaceIPs

    Name           : Private Network Connection
    IFIndex        : 12
    MacAddress     : 02-21-DC-6A-FC-C1
    IPAddress      : {10.5.24.153/24}
    PSComputerName : ZDEXDWS007
    RunspaceId     : 38cfa688-6b7d-4d3f-8e56-bbbb651cb61e


    .PARAMETER ComputerName
    A remote computer that you want to find the IP addresses for 

    .INPUTS 
    None. You cannont pipe objects 

    .OUTPUTS
    PSObject. Returns a Custom PS object with Interface Details 
    #>
    [CmdletBinding()]
    param(
        [string]$ComputerName
    )
    if (!$ComputerName) { 
        $ComputerName = $env:COMPUTERNAME
    }
    $InterfaceDetails = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
    $InterfaceDetails = New-Object System.Collections.ArrayList
    $Adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
    foreach ( $Adapter in $Adapters ) {
        $IPDetails = Get-NetIPAddress -InterfaceIndex $($Adapter.InterfaceIndex) | Where-Object { $_.PrefixOrigin -eq "Manual" -or $_.PrefixOrigin -eq "DHCP"}
        $Interface = New-Object psobject
        $Interface | Add-Member -MemberType NoteProperty -Name Name -Value $($Adapter.Name)
        $Interface | Add-Member -MemberType NoteProperty -Name IFIndex -Value $($Adapter.InterfaceIndex)
        $Interface | Add-Member -MemberType NoteProperty -Name MacAddress -Value $($Adapter.MacAddress)
        $IPArray = New-Object System.Collections.ArrayList
        foreach ($IP in $IPDetails ) {
            [void]$IPArray.Add("$($IP.IPAddress)/$($IP.PrefixLength)")
        }
        $Interface | Add-Member -MemberType NoteProperty -Name IPAddress -Value $IPArray

        [void]$InterfaceDetails.Add($Interface) 
    }

    return $InterfaceDetails
    }
    return $InterfaceDetails
}

function Get-StaticRouteTable {
    <#
    .SYNOPSIS 
    A simplified get-netroute with filters so you don't have to remember the basic IPv4 Route table filters

    .DESCRIPTION 
    Get-Netroute by itself returns the full OS level route table which inclues magical internal routes and IPv6 stuff. 
    This function applies filters to only show IPv4 and routes added manually or via the Interface Configuration

    .EXAMPLE 

    Get-StaticRouteTable


    ifIndex DestinationPrefix                              NextHop                                  RouteMetric PolicyStore
    ------- -----------------                              -------                                  ----------- -----------
    12      169.254.169.254/32                             10.5.24.1                                          0 ActiveStore
    12      169.254.169.251/32                             10.5.24.1                                          0 ActiveStore
    12      169.254.169.250/32                             10.5.24.1                                          0 ActiveStore
    12      0.0.0.0/0                                      10.5.24.1                                          0 ActiveStore

    .INPUTS 
    None. You cannont pipe objects 

    .OUTPUTS
    System.Array 
    #>
    [CmdletBinding()]
    Param()
   $StaticRoutes =  get-NetRoute -Protocol NetMgmt -AddressFamily IPv4 
   return $StaticRoutes
}

function Test-IPInRange { 
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][string]$IPAddress,
        [Parameter(Mandatory=$true)][string[]]$Networks
    )
    $IPSubjectBinary = Get-NetworkDetails -IPCidr "$($IPAddress)/32" 
    $IPInRange = New-Object System.Collections.ArrayList
    $IPOutRange = New-Object System.Collections.ArrayList

    foreach ($Network in $Networks ) { 
        $NetworkDetails = Get-NetworkDetails -IPCidr $Network 
        if ( ($NetworkDetails.NetworkBinary).Substring(0,$($NetworkDetails.CidrMask)) -eq (($IPSubjectBinary.HostBinary).Substring(0,$($NetworkDetails.CidrMask))) ) {
            [void]$IPInRange.Add("$($Network)")
        }
        else {
            [void]$IPOutRange.Add("$($Network)")
        }
    }

    $ReturnObject = New-Object psobject
    $ReturnObject | Add-Member -MemberType NoteProperty -Name InRange -Value $IPInRange
    $ReturnObject | Add-Member -MemberType NoteProperty -Name OutRange -Value $IPOutRange 
    $ReturnObject | Add-Member -MemberType NoteProperty -Name IPAddress -Value $IPAddress 

    return $ReturnObject
}

