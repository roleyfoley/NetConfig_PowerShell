# Returns the gateway address based on the IP of an interface's IP. 
# Assumes that the Gateway is either the Last or first IP in the Network. 
# Mf2201_g - 02/03/2016

$HostIP = [string](Get-NetIPAddress -ifIndex  $((Get-NetAdapter)[0].ifIndex) -AddressFamily IPv4).IPAddress
$SubnetMask = [string](Get-NetIPAddress -ifIndex  $((Get-NetAdapter)[0].ifIndex) -AddressFamily IPv4).PrefixLength

$HostBinary = [Convert]::ToString(([IPAddress][String]([IPAddress]$HostIP).Address).Address,2)

$NetworkId = ""

$NetworkId = ($HostBinary | Where {$_ -match "^(.{$SubnetMask})"} | ForEach{ [PSCustomObject]@{ 'BinaryNet' = $Matches[0] } }).BinaryNet

While ( $NetworkId.Length -le 30 ) {
    $NetworkId = [String]$NetworkId + "1"
}  

if ($NetworkId.Length -eq 31) {
    $NetworkId = [string]$NetworkId + "0"
}

$GatewayIP = ([System.Net.IPAddress]"$([System.Convert]::ToInt64($NetworkId,2))").IPAddressToString

Write-Output "IP Address $($HostIP) - Subnet Length $($SubnetMask) - Gateway $($GatewayIP)"  
