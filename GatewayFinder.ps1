# Gateway Locator and Router adder 
# IN our network configuration either the first or last usable host address is used as the Gateway IP. 
# This script will calculate what the gateway would be based on the IP configuration of the server and add any static routes supplied to it.
# The script also locates the Public Nic of the server based on the Network configuration of the Server
# BASIC NETWORK CONFIGURATION SHOULD BE COMPLETED BEFORE THIS SCRIPT IS RUN 
# 
# Written by: mf2201 - 03/03/2016 
Param 
(
    [Parameter(Mandatory=$true)][string]$GWLocation,
    [Parameter(Mandatory=$true)][string]$Route,
    [Parameter(Mandatory=$true)][string]$Environment
)

$GWLocation = $GWLocation.ToLower()

switch ($GWLocation) {
    "first" { 
        $BinaryFill = "0" 
        $BinaryEnd = "1" 
     }
     "last" {
        $BinaryFill = "1"
        $BinaryEnd = "0"
     } 
}       
 
# Find the Interface with the default route 
$DefaultInterface = Get-NetAdapter -InterfaceIndex $((get-netroute -DestinationPrefix 0.0.0.0/0).ifIndex) -Physical

# Assuming all servers only have 2 Nics the one without the default route should be our Public interface
$PublicInterface = Get-NetAdapter -Physical | Where-Object { $_.ifIndex -ne $DefaultInterface.ifIndex -and $_.Status -eq "Up" } 
$PublicIP = (Get-NetIPAddress -InterfaceIndex $($PublicInterface.ifIndex) | Where-Object {$_.AddressFamily -eq "IPv4" -and $_.Type -eq "Unicast" })[0]

# Convert the IP to Binary 
$HostBinary = ""
$HostBinary = ([Convert]::toString(([IPAddress][String]([IPAddress]$($PublicIP.IPAddress)).Address).Address,2)).PadLeft(32, "0")

#Split the Binary IP into Network/Host based on the Interfaces subnet mask - Keep the Network Binary part (the First part of the string)
$NetworkId = ""
$NetworkId = ($HostBinary | Where {$_ -match "^(.{$($PublicIP.PrefixLength)})"} | ForEach{ [PSCustomObject]@{ 'BinaryNet' = $Matches[0] } }).BinaryNet

# Since Network ID +1 = 1st Address and Broadcast -1 = Last Usable address filling the Network ID with 1's or 0's and doing the opposite for the last bit will give you the IP in Binary 
While ( $NetworkId.Length -le 30 ) {
    $NetworkId = [String]$NetworkId + $BinaryFill
}  

if ($NetworkId.Length -eq 31) {
    $NetworkId = [string]$NetworkId + $BinaryEnd
}

# Convert the Binary IP back into Dotted Quad 
$GatewayIP = ([System.Net.IPAddress]"$([System.Convert]::ToInt64($NetworkId,2))").IPAddressToString

# Create the new route using the genrated Gateway 
$CreatedRoute = New-NetRoute -DestinationPrefix $Route -AddressFamily IPv4 -InterfaceIndex $($PublicInterface.ifIndex) -NextHop $GatewayIP -RouteMetric 1 
