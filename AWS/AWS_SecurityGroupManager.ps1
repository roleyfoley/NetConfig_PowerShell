Param (
	[string]$AccountPath='.\AWSKeys.csv',
	[string]$TemplateGroupPath='.\AWSSecGroups.csv'
)

# Environement Setup
import-module AWSPowerShell
Set-AWSProxy -Hostname proxy.dmz.ige -Port 8080

# Create a dummy profile and set the region 
Set-AWSCredentials -AccessKey "abc123" -SecretKey "abc123" -StoreAs "Credential_Dummy" 
Initialize-AWSDefaults -ProfileName "Credential_Dummy" -Region "ap-southeast-2"

# Load up the Account Details CSV File
[System.Collections.ArrayList]$AccountCSV = Import-Csv -Path $AccountPath -ErrorAction Stop

# Load up the Security rules CSV File 
$TemplateCSV = import-csv -Path $TemplateGroupPath -ErrorAction Stop

function Get-VPCDetails {
	Param (
		[System.Collections.ArrayList]$AccountDetails
	)
	#Create account credentials and get the VPC ID for each account 
	foreach ( $AWSAccount in $AccountDetails) { 
		# Create Auth Profile
		Set-AWSCredentials -AccessKey $AWSAccount.AccessKey -SecretKey $AWSAccount.SecretKey -StoreAs "Credential_$($AWSAccount.Agency)-$($AWSAccount.Environment)"
		Initialize-AWSDefaults -ProfileName "Credential_$($AWSAccount.Agency)-$($AWSAccount.Environment)" 
		
		$AWSVpcId = $(Get-EC2Vpc -Filters @( @{name='tag:Environment'; values=$($AWSAccount.Environment)}; @{name='tag:Agency'; values=$($AWSAccount.Agency)}; )).VpcId
		
		if ( $AWSVpcId -eq $null ) { 
		Write-Error "Couldn't find a VPC that matched $($AWSAccount.Environment) - $($AWSAccount.Agency) using the provided keys" -ErrorAction Stop
		} 

		$AWSAccount | Add-Member -MemberType NoteProperty -Name VpcId -Value $AWSVpcId
		$AWSAccount | Add-Member -MemberType NoteProperty -Name AccountId -Value  $((((Get-IAMUser -ProfileName "Credential_$($AWSAccount.Agency)-$($AWSAccount.Environment)").Arn).TrimStart('arn:aws:iam::')).Split(':')[0])	
}
	
	return $AccountDetails
}


function Get-SecurityGroups {
	param ( [string]$Agency, [string]$Environment, [string]$VpcId )
	$VPCSecGroups = New-Object System.Collections.ArrayList
	$SecGroups = Get-EC2SecurityGroup -ProfileName "Credential_$($Agency)-$($Environment)" -Filter @( @{name="vpc-id"; value=$VpcId }; )
		Foreach ($SecGroup in $SecGroups) {
		$SecGroupInfo = New-Object -TypeName psobject
		$SecGroupInfo | Add-Member -MemberType NoteProperty -Name Name -Value $SecGroup.GroupName
		$SecGroupInfo | Add-Member -MemberType NoteProperty -Name GroupId -Value $SecGroup.GroupId
		$SecGroupInfo | Add-Member -MemberType NoteProperty -Name Agency -Value $AWSVPC.Agency
		$SecGroupInfo | Add-Member -MemberType NoteProperty -Name Environment -Value $AWSVPC.Environment
		[void]$VPCSecGroups.Add($SecGroupInfo)
		}
	return $VPCSecGroups
}

# Get Account Details
$VPCDetails = Get-VPCDetails -AccountDetails $AccountCSV

# Get all the Security Groups and add to a table
$SecGroupList = @()

foreach ( $AWSVPC in $VPCDetails ) {
		$VPCGroupList = Get-SecurityGroups -Agency $($AWSVPC.Agency) -Environment $($AWSVPC.Environment) -VpcId $($AWSVPC.VpcId)
		$SecGroupList = $SecGroupList + $VPCGroupList
}

# ----- Security Group Creation ------  
# Get the list of the unique security groups 
$TemplateSecGroups = $TemplateCSV | Select GroupName,Description | get-unique -asstring 

# Compare the template security groups to the Destination Groups and create if it doesn't exist
foreach ($VPC in $VPCDetails) {
	ForEach ($TemplateGroup in $TemplateSecGroups ) {
       $TemplateGroupName = $VPC.Environment + "_" + $TemplateGroup.GroupName  
       if ( ($SecGroupList | Where-Object {$_.Agency -eq $VPC.Agency -and $_.Environment -eq $VPC.Environment}).Name -notcontains $TemplateGroupName ) {
            # New-EC2SecurityGroup -Description $TemplateGroup.Description -GroupName $TemplateGroupName -VpcId $VPC.VpcId -ProfileName "Credential_$($VPC.Agency)-$($VPC.Environment)"
		   Write-Output "Creating a new Group - $($VPC.Agency) - $($VPC.Environment) - Group Name: $($TemplateGroupName)" 
        }
    }
}

# After new groups have been created run a refresh of the security groups
Remove-Variable SecGroupList
$SecGroupList = @()

foreach ( $AWSVPC in $VPCDetails ) {
		$VPCSecGroupList = Get-SecurityGroups -Agency $($AWSVPC.Agency) -Environment $($AWSVPC.Environment) -VpcId $($AWSVPC.VpcId)
		$SecGroupList = $SecGroupList + $VPCSecGroupList
}

ForEach ( $AWSVPC in $VPCDetails ) {
	Write-host "Updating Security Groups for $($AWSVPC.Agency) - $($AWSVPC.Environment)" -ForegroundColor Green
	Initialize-AWSDefaults -ProfileName "Credential_$($AWSVPC.Agency)-$($AWSVPC.Environment)"  
	ForEach ( $TemplateACL in $TemplateCSV ) {
		# Only create the groups for Environment /Agency
		if ( (($TemplateACL.Agency -eq "all") -or ($TemplateACL.Agency -eq $($AWSVPC.Agency))) -and (($TemplateACL.Environment -eq "all") -or ($TemplateACL.Environment -eq $($AWSVPC.Environment)) ) )  {
			$IPPermission = New-Object Amazon.EC2.Model.IpPermission

			# Protocol - Match on Any Protocol
			# Convert any to AWS any
			if ($TemplateACL.Protocol -imatch 'any') {
					$TemplateACL.Protocol = "-1"
			}
      
			# Protocol - Drop the Case and create
			if ( $TemplateACL.Protocol) {
				$TemplateACL.Protocol = [string]$TemplateACL.Protocol.Trim()
				$TemplateACL.Protocol = [string]$TemplateACL.Protocol.ToLower()
				$IPPermission.IpProtocol = [string]$TemplateACL.Protocol
			}
    
			# Port - If we have a port range then Split it up
			if ( $TemplateACL.Port) {
				$TemplateACL.Port = [string]$TemplateACL.Port.Trim()
				if ( $TemplateACL.Port -like '*-*' ) {
						$PortRange = $TemplateACL.Port.Split("-")
						$IPPermission.FromPort = [Int32]$PortRange[0]
						$IPPermission.ToPort = [Int32]$PortRange[1]
					}
				# If it is not a range range = same port
				else {
     
					 # Port - match on Any Ports
					 if ( $TemplateACL.Port -imatch 'any') {
							$TemplateACL.Port = "-1"
					 }

						$IPPermission.ToPort = $TemplateACL.Port
						$IPPermission.FromPort = $TemplateACL.Port
				 }
			}

			# Check for IP based Rule 
			if (  $TemplateACL.Source ) {
				[ref]$ValidIP=[ipaddress]::None

				# Strip the CIDR to test for IP
				$IPAddress = $TemplateACL.Source.Split("/")[0] 
            
				# Test for IP Address Format
				if (  [IPAddress]::TryParse($IPAddress,$ValidIP) ) {
					$IpRange = New-Object 'collections.generic.list[string]'
					$IpRange.add($TemplateACL.Source)
					$IPPermission.IpRanges = $IpRange
				}
				# If it's not IP it must be a group 
				else {
					# Check to see if the Source agency and Environement have been set for this rule - Assume local if Empty, If populated use the details to find the different group  
					if ( $TemplateACL.SourceAgency -eq "" -or $TemplateACL.SourceEnvironment -eq "" ) {
                        $SourceGroupName = $AWSVPC.Environment + "_" + $TemplateACL.Source
					    $SourceGroup = $SecGroupList | Where-object { $_.Name -eq $SourceGroupName -and $_.Agency -eq $AWSVPC.Agency -and $_.Environment -eq $AWSVPC.Environment }
					}
					else {
                        $SourceGroupName = $TemplateACL.SourceEnvironment + "_" + $TemplateACL.Source
						$SourceGroup = $SecGroupList | Where-object { $_.Name -eq $SourceGroupName -and $_.Agency -eq $TemplateACL.SourceAgency -and $_.Environment -eq $TemplateACL.SourceEnvironment } 
					
					}
					$GroupList = New-Object Amazon.EC2.Model.UserIdGroupPair 
					$GroupList.GroupId = $SourceGroup.GroupId 
					$IPPermission.UserIdGroupPairs = $GroupList
				}
      
				  # Find the group we are applying the permissions to 
				  $ACLGroupName = $($AWSVPC.Environment) + "_" + $TemplateACL.GroupName
				  $ACLGroup = $SecGroupList | Where-object { $_.Name -eq $ACLGroupName -and $_.Agency -eq $($AWSVPC.Agency) -and $_.Environment -eq $($AWSVPC.Environment)}
				  $SecGroupApplyError = $false
					
				  try
				  {
				  # Apply the Permissions
				  Grant-EC2SecurityGroupIngress -GroupId $ACLGroup.GroupId -IpPermission $IPPermission               }
				  catch  
				  {
				   if ( $Error[0].Exception -like "*already exists*" ){
						$SecGroupApplyError = $true              
				   }
				   else {
						$RuleFailureMSG = "Rule failure " + $TemplateACL.GroupName + " Port: " + $TemplateACL.Port + " Protocol: " + $TemplateACL.Protocol  + " Source: "  + $TemplateACL.Source + " Exception: " + $Error[0].Exception
						Write-error $RuleFailureMSG -ErrorAction Stop
                    
				   }
				  }
				  if ( $SecGroupApplyError -eq $true) {
						Write-host "Applied Security Rule $($TemplateACL.GroupName) - $($TemplateACL.Source) - $($TemplateACL.Protocol)/$($TemplateACL.Port)"
				  }
			}
		}
	}
	# Reset Default profile to Dummy to prevent accidental updates
	Initialize-AWSDefaults -ProfileName "Credential_Dummy" 
}
