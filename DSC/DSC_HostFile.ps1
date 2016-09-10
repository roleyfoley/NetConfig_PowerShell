Configuration SpazHome_NetConfig_BasicSetup
{ 
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$NodeName,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$Role,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$IntAlias,
        [String]$PubIntAlias
    ) 
    # Add Extra DSC Resources
    import-dscresource -Module xNetworking

    Node $NodeName 

    if ( $Role -eq "Application") { 
        # Interface Configuration
        # - Removes Default Gateway from Pub Interface
        xDefaultGatewayAddress Pub_NoIpv4Gateway
        {
            AddressFamily = 'IPv4'
            InterfaceAlias = $PubIntAlias
        }
        xDefaultGatewayAddress Pub_NoIpv6Gateway {
            AddressFamily =  'IPv6'
            InterfaceAlias = $PubIntAlias 
        }

        xRoute Pub_TMGRoute {
        AddressFamily = 'IPv4'
        InterfaceAlias = $PubIntAlias
        DestinationPrefix = '10.11.249.0/24'
        NextHop = '10.1.1.1'
        }

        # - Sets the Network Connection Profile to Public Firewall 
        xNetConnectionProfile Pub_IntProfile {
            InterfaceAlias = $Node.PubIntAlias
            NetworkCategory = 'Public'
            IPv4Connectivity = 'LocalNetwork'
        }

        # - Permit IIS Traffic 
        xFirewall Permit_IIS {
            Name = 'IIS-WebServerRole-HTTP-In-TCP'
            Ensure = 'Present'
            Enabled = 'True'
            DependsOn = '[WindowsFeature]Add_IIS'
        }

        # Feature Installaion
        WindowsFeature Add_IIS {
            Name = "Web-Server"
            Ensure = 'Present'
        }

    }
}

# This creates the Configuration File 
Write-Output "Creating Configuration "
SpazHome_NetConfig_BasicSetup -NodeName 'ZPRITST001' -Role 'Application' -IntAlias 'Ethernet0' -PubIntAlias 'Ethernet1'

# This pushed the configuration file to the Computer and Applies it
write-output "ApplyConfiguration "
Start-DscConfiguration -Path SpazHome_NetConfig_BasicSetup -Wait -Verbose -Force -Credential $Creds -ComputerName ZPRITST001
