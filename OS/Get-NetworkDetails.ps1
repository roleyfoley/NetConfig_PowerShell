function Get-InterfaceIPs {
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

function Get-StaticRouteTable {
   $StaticRoutes =  get-NetRoute -Protocol NetMgmt -AddressFamily IPv4 
   
   return $StaticRoutes
}


