# Step 3: Create Shared Folders and Set Permissions
$sharePath = "C:\Shares\Public"
$shareName = "PublicShare"

# Create the directory for the shared folder
New-Item -Path $sharePath -ItemType Directory -Force

# Create the SMB share
New-SmbShare -Name $shareName -Path $sharePath -FullAccess "EVIL\Domain Admins" -ChangeAccess "EVIL\Domain Users"

# Set NTFS Permissions (Domain Admins: Full Control, Domain Users: Modify)
$acl = Get-Acl -Path $sharePath
$domainAdmins = New-Object System.Security.Principal.NTAccount("EVIL\Domain Admins")
$domainUsers = New-Object System.Security.Principal.NTAccount("EVIL\Domain Users")

$permissionAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule($domainAdmins, "FullControl", "Allow")
$permissionUsers = New-Object System.Security.AccessControl.FileSystemAccessRule($domainUsers, "Modify", "Allow")

$acl.SetAccessRule($permissionAdmins)
$acl.SetAccessRule($permissionUsers)
Set-Acl -Path $sharePath -AclObject $acl

#add lsa protection
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -PropertyType DWORD -Force

#fw Setup
# Part 1 Script: Configure Windows Firewall Rules

# Define necessary ports for each machine
$firewallRules = @{
    "DC02" = @("53", "88", "135", "139", "389", "445", "464", "593", "636", "3268", "3389");
    "FILE01" = @("135", "445", "3389");
    "WEB01" = @("80", "3389");
}

# Get the computer name to determine which rules to apply
$computerName = $env:COMPUTERNAME

if ($firewallRules.ContainsKey($computerName)) {
    $portsToOpen = $firewallRules[$computerName]
    
    foreach ($port in $portsToOpen) {
        # Create a new inbound firewall rule to allow traffic on the specified port
        New-NetFirewallRule -DisplayName "Allow Port $port" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow
        Write-Host "Firewall rule added to allow TCP traffic on port $port."
    }
    
    Write-Host "Firewall configuration completed for $computerName."
} else {
    Write-Host "No specific firewall rules defined for this machine."
}


# Define the filename for the AppLocker XML policy file
$PolicyFileName = "AppLockerPolicy.xml"

# Get the current working directory
$CurrentDirectory = Get-Location

# Define the full path where the XML file will be saved
$PolicyFilePath = Join-Path -Path $CurrentDirectory -ChildPath $PolicyFileName

# Create the AppLocker policy XML content as a string
$AppLockerXml = @"
<AppLockerPolicy Version='1'>
    <RuleCollection Type='Exe' EnforcementMode='Enabled'>
        <FilePublisherRule Id='5040b75a-f81a-4a07-a543-ee1129a15fe4' Name='Allow Microsoft Signed Executables' Description=''
        UserOrGroupSid='S-1-1-0' Action='Allow'>
            <Conditions>
                <FilePublisherCondition PublisherName='O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US' ProductName='*' BinaryName='*'>
                    <BinaryVersionRange LowSection='*' HighSection='*'/>
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
    </RuleCollection>
    <RuleCollection Type='Msi' EnforcementMode='NotConfigured' />
    <RuleCollection Type='Script' EnforcementMode='NotConfigured' />
    <RuleCollection Type='Appx' EnforcementMode='NotConfigured' />
    <RuleCollection Type='Dll' EnforcementMode='NotConfigured' />
</AppLockerPolicy>
"@

# Save the AppLocker XML to a file in the current working directory with proper UTF8 BOM encoding
Write-Host "Saving XML policy to $PolicyFilePath..."
try {
    [System.IO.File]::WriteAllText($PolicyFilePath, $AppLockerXml, [System.Text.Encoding]::UTF8)
    Write-Host "XML policy saved successfully to $PolicyFilePath."
} catch {
    Write-Error "Failed to save XML policy: $_"
}

set-applockerpolicy -XmlPolicy .\AppLockerPolicy.xml


# Define variables for domain (NetBIOS), user, and password
$domain = "evil"  # NetBIOS name of the domain, typically the first part of the FQDN
$username = "paul"
$password = "Water#123"

# Define registry path
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Set the domain name
Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $domain -Type String

# Set the username
Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $username -Type String

# Set the password (Note: This stores the password in plaintext)
Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $password -Type String

# Enable auto-login
Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1" -Type String

# Optional: Set AutoLogonCount (can be adjusted or omitted)
Set-ItemProperty -Path $regPath -Name "AutoLogonCount" -Value "1" -Type String

Write-Host "Auto-login setup complete. Please restart the machine to apply changes."
