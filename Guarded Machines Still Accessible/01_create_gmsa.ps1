#for ease of life run this from the dc
Import-Module ActiveDirectory

# Define the name for the gMSA
$gMSAName = "test_gmsa_iis13"

# dc needs to be allowed to manipulate gmsa, needs to be explicvitly defined
$hostname = hostname
$hostname_as_computername = $hostname + '$'

#server running iis. needs $ aftername.
$iis_server_name = 'CAPSULES_IIS$'

# Define the DNS hostname of the Active Directory domain
$domain = (Get-ADDomain).DNSRoot

# Create a new KDS root key if it doesn't already exist
# This is only necessary once per forest. If a key already exists, this step can be skipped.
if (-not (Get-KdsRootKey)) {
    Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))
    Write-Host "KDS root key created. Please wait for Active Directory replication to complete."
    Start-Sleep -Seconds 60 # Wait for 1 minutes to allow replication
}

# Create the gMSA
try {
    New-ADServiceAccount -Name $gMSAName -DNSHostName $domain -ManagedPasswordIntervalInDays 30
    Write-Host "gMSA '$gMSAName' created successfully."
} catch {
    Write-Error "Failed to create gMSA. Error: $_"
}

# Retrieve AD computer objects for both machines
$computer1 = Get-ADComputer -Identity $hostname_as_computername
$computer2 = Get-ADComputer -Identity $iis_server_name

# Combine the computer objects into an array, can NOT be positional args for more than one computer
$computers = @($computer1, $computer2)

# Set the gMSA to be managed by both machines
Set-ADServiceAccount -Identity $gMSAName -PrincipalsAllowedToRetrieveManagedPassword $computers


# Example to install the gMSA on the local machine (optional)
Install-ADServiceAccount -Identity $gMSAName
# Test the installation (optional)
Test-ADServiceAccount -Identity $gMSAName
