# NetConfig_PowerShell
The NetConfig Tool set is used to find simple network level information via PowerShell. While the functions are available within Powershell the poitn of this tool set is to make it really easy to find our basic network information as part of your work. 

The main part ofthe NEtConfig Toolset is the BasicNetworking PowerShell Module. This module gives you a bunch of different details about the networking of a given IP. 

Running Get-BasicNetworking against an IP in CIDR format will give you subnet mask, first and last address within the Network in IP notation and binary, and the Network Id

PS C:\Users\mf2201_a> Get-NetworkDetails -IPCidr 10.1.1.1/24

IP            : 10.1.1.1
CidrMask      : 24
SubnetMask    : 255.255.255.0
NetworkId     : 10.1.1.0
FirstIP       : 10.1.1.1
LastIP        : 10.1.1.254
NetworkBinary : 00001010000000010000000100000000
HostBinary    : 00001010000000010000000100000001

