# Enable File and Print Sharing via PS 
Get-netFirewallRule -DisaplyGroup @( 'File and Printer Sharing', 'Windows Remote Management' ) | Enable-NetFirewallRule 

# Change Net Connection Profile - Might not be required if use the firewall stuff. 
Get-NetAdapter | Set-NetConnectionProfile -NetworkCategory Private 
