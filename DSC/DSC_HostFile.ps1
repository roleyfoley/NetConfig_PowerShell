set-location C:\Users\Michael\Source\Repos\PowerShell_NetConfig\DSC

Configuration SpazHome_NetConfig_BasicSetup
{ 
  import-dscresource -Module xNetworking

  node $AllNodes.NodeName 
  {       
      xDHCPClient DisableDHCPIpv4
      {
          State = 'Enabled'
          InterfaceAlias = $Node.IntAlias
          AddressFamily = 'IPv4'
      }
      xDHCPClient DisableDHCPIpv6
      {
          State = 'Enabled'
          InterfaceAlias = $Node.IntAlias
          AddressFamily = 'IPv6'
      }
  }

  node $AllNodes.Where{$_.Role -eq "Application"}.NodeName
  { 
      # Interface Configuration
      xDefaultGatewayAddress Pub_NoIpv4Gateway
      {
          AddressFamily = 'IPv4'
          InterfaceAlias = $Node.PubIntAlias
      }
      xDefaultGatewayAddress Pub_NoIpv6Gateway {
          AddressFamily =  'IPv6'
          InterfaceAlias = $Node.PubIntAlias 
      }
      xNetConnectionProfile Pub_IntProfile {
          InterfaceAlias = $Node.PubIntAlias
          NetworkCategory = 'Public'
          IPv4Connectivity = 'Internet'
          IPv6Connectivity = 'Disconnected'
      }
      
      xFirewall Permit_IIS {
          Name = 'IIS-WebServerRole-HTTP-In-TCP'
          Ensure = 'Present'
          Enabled = 'True'
          DependsOn = '[WindowsFeature]Add_IIS'
      }
      

      # Feature Installaion
      WindowsFeature Add_IIS {
          Name = "WebServer"
          Ensure = 'Present'
      }
      
  }
}

# Node Configuration Data Goes here 
$ConfigData = 
@{
    AllNodes = 
    @(

        @{
            NodeName = '192.168.2.33'
            Role = 'Application'
            IntAlias = 'Ethernet0'
            PubIntAlias = 'Ethernet1'
        }
    );
     NonNodeData = ""  
}


$User = 'Administrator'
$Pass = 'S0mething!'

$secpasswd = ConvertTo-SecureString $Pass -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential ($User, $secpasswd)

Write-Output "Creating Configuration"
SpazHome_NetConfig_BasicSetup -ConfigurationData $ConfigData 

write-output "ApplyConfiguration "
Start-DscConfiguration -Path SpazHome_NetConfig_BasicSetup -Wait -Verbose -Force -Credential $Creds -ComputerName 192.168.2.33