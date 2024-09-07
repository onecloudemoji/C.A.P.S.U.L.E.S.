$DomainName = "EVIL.COM"

# Step 3: Configure DNS
if (Get-DnsServerZone -Name $DomainName -ErrorAction SilentlyContinue) {
    Write-Host "Zone $DomainName already exists. Skipping creation."
} else {
    Add-DnsServerPrimaryZone -Name $DomainName -ReplicationScope "Forest" -PassThru
}

# Add Host (A) records for other servers
if (Get-DnsServerResourceRecord -ZoneName $DomainName -Name "FILE01" -ErrorAction SilentlyContinue) {
    Write-Host "DNS A record 'FILE01' already exists. Removing and re-adding it."
    Remove-DnsServerResourceRecord -ZoneName $DomainName -Name "FILE01" -RRType "A" -Force
}
Add-DnsServerResourceRecordA -Name "FILE01" -ZoneName $DomainName -IPv4Address "192.168.1.131"

if (Get-DnsServerResourceRecord -ZoneName $DomainName -Name "WEB01" -ErrorAction SilentlyContinue) {
    Write-Host "DNS A record 'WEB01' already exists. Removing and re-adding it."
    Remove-DnsServerResourceRecord -ZoneName $DomainName -Name "WEB01" -RRType "A" -Force
}
Add-DnsServerResourceRecordA -Name "WEB01" -ZoneName $DomainName -IPv4Address "192.168.1.132"

# Step 4: Create User in the 'Users' Container
Import-Module ActiveDirectory

# Create the user Paul
New-ADUser -Name "Paul" -SamAccountName "Paul" -UserPrincipalName "Paul@evil.com" -AccountPassword (ConvertTo-SecureString "Water#123" -AsPlainText -Force) -Enabled $true

# Add Paul to each group
$groups = @(
    "Administrators",
    "Domain Admins",
    "Domain Users",
    "Enterprise Admins",
    "Group Policy Creators Owners",
    "Schema Admins"
)

foreach ($group in $groups) {
    Add-ADGroupMember -Identity $group -Members "Paul"
}

#add lsa protection
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -PropertyType DWORD -Force


Write-Host "Domain Controller configuration is complete. Please verify settings."


#fw settings

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