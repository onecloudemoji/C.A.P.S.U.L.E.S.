# Step 1: Install IIS and Required Features
Write-Host "Installing IIS and necessary features for ASP.NET, ASP, and CGI..."
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name Web-Asp-Net45  # Install ASP.NET 4.5
Install-WindowsFeature -Name Web-ASP        # Install ASP support
Install-WindowsFeature -Name Web-CGI        # Install CGI support
Write-Host "IIS and all required features installed successfully."

# Step 2: Create Uploads Directory and Set Permissions
$uploadDir = "C:\inetpub\wwwroot\uploads"
Write-Host "Creating upload directory at $uploadDir..."
if (-Not (Test-Path $uploadDir)) {
    New-Item -Path $uploadDir -ItemType Directory
    Write-Host "Upload directory created successfully."
} else {
    Write-Host "Upload directory already exists."
}

Write-Host "Setting directory permissions to allow execution..."
# Set the permissions to allow execution for Everyone
$acl = Get-Acl $uploadDir
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($rule)
Set-Acl $uploadDir $acl
Write-Host "Permissions set successfully."

# Step 4: Allow Script Execution for Uploads Directory
Write-Host "Configuring upload directory to allow script execution..."
Import-Module WebAdministration
Set-WebConfigurationProperty -Filter "system.webServer/handlers" -PSPath "IIS:\Sites\Default Web Site" -Name "upload" -Value "True"
Write-Host "Script execution allowed for upload directory."

# Step 5: Test Web Server Configuration
$testFilePath = "$uploadDir\test_upload.aspx"
Write-Host "Creating a test ASPX file at $testFilePath..."
$testFileContent = @"
<%@ Page Language="C#" %>
<!DOCTYPE html>
<html>
<head>
    <title>Test Upload</title>
</head>
<body>
    <h1>Upload Test Successful</h1>
</body>
</html>
"@
New-Item -Path $testFilePath -ItemType File -Force -Value $testFileContent
Write-Host "Test ASPX file created."

Write-Host "Testing the IIS setup. Please open a browser and navigate to http://localhost/uploads/test_upload.aspx to verify."


#add lsa protection
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -PropertyType DWORD -Force

#fw setup

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