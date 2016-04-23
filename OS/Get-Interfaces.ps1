function Get-NicIPs {
        $InterfaceDetails = New-Object System.Collections.ArrayList
        $Adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" } 
               
        foreach ( $Adapter in $Adapters ) {
            $IPDetails = Get-NetIPAddress -InterfaceIndex $($Adapter.InterfaceIndex) | Where-Object { $_.PrefixOrigin -eq "Manual" -or $_.PrefixOrigin -eq "DHCP"}
            $Interface = New-Object psobject
            $Interface | Add-Member -MemberType NoteProperty -Name Name -Value $($Adapter.Name)
            $Interface | Add-Member -MemberType NoteProperty -Name MacAddress -Value $($Adapter.MacAddress)
            $Interface | Add-Member -MemberType NoteProperty -Name IPAddress -Value $($IPDetails.IPAddress) 
            [void]$InterfaceDetails.Add($Interface) 
        }

        return $InterfaceDetails
}

Get-NicIPs 

