Import-Module GroupPolicy
Import-Module ActiveDirectory

# Step 1: Create the GPO named 'test_gpo'
$gpo = New-GPO -Name "test_gpo" -Comment "This GPO adds a registry key to HKLM"

# Step 2: Link the GPO to the current domain
$domain = Get-ADDomain
New-GPLink -Name $gpo.DisplayName -Target $domain.DistinguishedName

#define params so it adds the reg key
$params = @{
    Name      = 'test_gpo'
    Key       = 'HKCU\TestGPO'
    ValueName = 'testgpo_was_here'
    Value     = 900
    Type      = 'DWORD'
}

#apply params
Set-GPRegistryValue @params

#add perms so domain users can modify this gpo
Set-GPPermission -Name test_gpo -TargetName "Domain Users" -TargetType Group -PermissionLevel GpoEdit
