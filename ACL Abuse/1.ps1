#Promotes a server to a dc, adds a static IP, creates the domain and reboots

# Set a static IP of 192.168.223.135
New-NetIPAddress -IPAddress 192.168.223.135 -PrefixLength 24 -InterfaceAlias "Ethernet0"

# Promote the server to a domain controller
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# Set up a new domain called "test.net"
$Password = "Water#123"
$SecureString = ConvertTo-SecureString $Password -AsPlainText -Force

Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "Win2012R2" `
    -DomainName "test.net" `
    -DomainNetbiosName "TEST" `
    -ForestMode "Win2012R2" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true `
    -SafeModeAdministratorPassword $SecureString
