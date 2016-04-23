function Get-NicIPs {
        $InterfaceDetails = New-Object System.Collections.ArrayList
        $Adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" } 
               
        foreach ( $Adapter in $Adapters ) {
        $IPDetails = Get-NetIPAddress -InterfaceIndex $($Adapter.InterfaceIndex)
        $Interface = New-Object psobject
        $Interface | Add-Member -MemberType NoteProperty -Name Name -Value $($Adapter.Name)
        $Interface | Add-Member -MemberType NoteProperty -Name MacAddress -Value $($Adapter.MacAddress)
        $Interface | Add-Member -MemberType NoteProperty -Name IPAddress -Value $($IPDetails.IPAddress)
        $InterfaceDetails.Add($Interface) 
    }

        return $InterfaceDetails
}

Get-NicIPs | ConvertTo-Json

