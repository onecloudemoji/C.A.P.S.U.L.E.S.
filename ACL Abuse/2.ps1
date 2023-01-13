#adds the groups, users and ACLs needed to run the scenario
#comments do """spoil""" what this does but this isnt designed to be a surprise game. Its practice.

# Add users "1" and "2"
New-ADUser -Name "1" -SamAccountName "1" -UserPrincipalName "1@test.net" -AccountPassword (ConvertTo-SecureString "Water#123" -AsPlainText -Force) -Enabled $true
New-ADUser -Name "2" -SamAccountName "2" -UserPrincipalName "2@test.net" -AccountPassword (ConvertTo-SecureString (ConvertTo-SecureString (ConvertTo-SecureString (New-Object System.Security.SecureString) -AsPlainText -Force) -AsPlainText -Force) -AsPlainText -Force) -Enabled $true

# Add user "3" with a complex random password
New-ADUser -Name "3" -SamAccountName "3" -UserPrincipalName "3@test.net" -AccountPassword (ConvertTo-SecureString (ConvertTo-SecureString (ConvertTo-SecureString (New-Object System.Security.SecureString) -AsPlainText -Force) -AsPlainText -Force) -AsPlainText -Force) -Enabled $true

# set up 3 groups
$groups = @("group_elevated1", "group_elevated2", "group_elevated3")

foreach ($group in $groups) {
    New-ADGroup -Name $group -GroupCategory Security -GroupScope Global
}


# add users to groups
Add-ADGroupMember -Identity "group_elevated1" -Members "2"
Add-ADGroupMember -Identity "group_elevated3" -Members "3"
Add-ADGroupMember -Identity "Server Operators" -Members "1"
Add-ADGroupMember -Identity "Server Operators" -Members "2"
Add-ADGroupMember -Identity "Server Operators" -Members "3"

#allow user 1 to perform password reset on user 2
dsacls "CN=2,CN=Users,DC=test,DC=net" /G "test\1:CA;Reset Password;"

#set group_elevated1 to have GenericWrite over group_elevated2
#this means we can self add user2 to the group_elevated2 bc user2 is part of elevated1
dsacls "CN=group_elevated2,CN=Users,DC=test,DC=net" /G "CN=group_elevated1,CN=Users,DC=test,DC=net:GW"

#elevated2 has genericall to user3
#this means user 2 can change pw of user3 because user2 is in elevated2 which user 2 has added himself to and that group has direct control over user3
dsacls "CN=3,CN=Users,DC=test,DC=net" /G "CN=group_elevated2,CN=Users,DC=test,DC=net:GA"

#group_elevated3 has writedacl (generic all in this case) to dc 
#user3 is part of elevated3 so can perform the action in powerview to add the dcsync rights to themselves.

dsacls "DC=test,DC=net" /I:T /G "CN=group_elevated3,CN=Users,DC=test,DC=net:GA"
