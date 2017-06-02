# Basic Firewall
Enable some of the Basics so that you can get to the box and it can do DNS....
```
Get-netFirewallRule -DisplayGroup @( 'File and Printer Sharing', 'Windows Remote Management' ) | Enable-NetFirewallRule 
Get-netFirewallRule -Name CoreNet-DNS-Out-UDP | Enable-netFirewallRule
```

# Versioning 
 http://semver.org

## MAJOR.MINOR.PATH
* Major - Changing something will break/modify an API
* Minor - Add something but don't break/remove anything
* Patch - Fixes that don't break/remove anything
 
 
