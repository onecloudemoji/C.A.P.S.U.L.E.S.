# Script: Configure Constrained Delegation and Privileges for WEB01 from DC02

# Import the Active Directory module (ensure RSAT tools are installed)
Import-Module ActiveDirectory

$webServer = "WEB01"
$fileServer = "FILE01"
$serviceAccount = "CIFS"
$domain = "EVIL.COM"

# Step 1: Configure Constrained Delegation for WEB01

# Define the delegation setting for the CIFS service on FILE01
$delegationService = "$serviceAccount/$fileServer.$domain"

# Get the existing msDS-AllowedToDelegateTo property
$existingDelegation = (Get-ADComputer -Identity $webServer -Properties "msDS-AllowedToDelegateTo")."msDS-AllowedToDelegateTo"

# Add the CIFS service delegation if it's not already present
if ($existingDelegation -notcontains $delegationService) {
    Set-ADComputer -Identity $webServer -Add @{"msDS-AllowedToDelegateTo" = $delegationService}
    Write-Host "Added constrained delegation for $webServer to CIFS service on $fileServer."
} else {
    Write-Host "Constrained delegation already exists for $webServer to CIFS service on $fileServer."
}

# Enable "Trusted to authenticate for delegation" (flag 0x1000000 in userAccountControl)
$webServerObject = Get-ADComputer -Identity $webServer
if (($webServerObject.userAccountControl -band 0x1000000) -eq 0) {
    # Set the "Trusted to authenticate for delegation" flag
    $userAccountControlValue = $webServerObject.userAccountControl -bor 0x1000000
    Set-ADComputer -Identity $webServer -Replace @{"userAccountControl" = $userAccountControlValue}
    Write-Host "'Trusted to authenticate for delegation' flag enabled for $webServer."
} else {
    Write-Host "'Trusted to authenticate for delegation' flag is already set for $webServer."
}




Write-Host "Delegation and privilege configurations completed. Verifying:"

Get-ADComputer -Identity "WEB01" -Properties "msDS-AllowedToDelegateTo" | Select-Object -ExpandProperty msDS-AllowedToDelegateTo