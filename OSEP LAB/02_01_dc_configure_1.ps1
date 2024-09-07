net user Administrator "Water#123"

# Step 1: Install Active Directory Domain Services (AD DS)
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Step 2: Promote the Server to a Domain Controller
$DomainName = "EVIL.COM"
$SafeModeAdminPassword = ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force  # Change the DSRM password as needed

Install-ADDSForest -DomainName $DomainName -CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" -DomainMode "7" -DomainNetbiosName "EVIL" `
-ForestMode "7" -InstallDns:$true -LogPath "C:\Windows\NTDS" -SysvolPath "C:\Windows\SYSVOL" `
-Force:$true -SafeModeAdministratorPassword $SafeModeAdminPassword

# Wait for the server to restart automatically after the promotion
Write-Host "Server will restart after Domain Controller promotion. Please wait..."