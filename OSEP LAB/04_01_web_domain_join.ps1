# Part 1 Script: Join Domain and Install IIS

# Step 1: Join the VM to the EVIL.COM Domain using Administrator credentials
$domainName = "EVIL.COM"
$adminUser = "administrator"
$adminPassword = "Water#123"
$securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
$domainCredential = New-Object System.Management.Automation.PSCredential("$domainName\$adminUser", $securePassword)

# Join the domain and restart the computer
Add-Computer -DomainName $domainName -Credential $domainCredential -Restart