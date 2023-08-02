# C.A.P.S.U.L.E.S
Crafting Alternative Powershell Scenarios Utilising Learning Environment Scripts.

![capsules](https://raw.githubusercontent.com/onecloudemoji/onecloudemoji.github.io/master/assets/images/CAPSULES.jpg)

Extensible modules designed to make a red team and pentesting lab that is more flexible, has depth and automation. Stand alone kits designed to work together or alone, as part of a larger build or a self contained deployment. These kits are not designed to automatically build infrastructure for you, [I have already build that project](https://github.com/onecloudemoji/ADLAB). These will not deploy flags, and the point isnt always root.

All scripts come with twelve months of WOMM&trade; (works on my machine) warranty.


## ACL Abuse
A two script kit to build a domain controller, then add the necessary groups, users and permissions to practice some ACL abuse and edges you might miss in BloodHound. Drop in as user 1 for an assumed breach or combine with the 'UNCLE' kit to use responder and collect hashes from outside.

## UNCLE
A short script that will add a scheulded task to force a specified user to check for a non existant UNC share at a periodic interval. Presently leverages users from the ACL Abuse kit, change these as required.

## Suspicious Mail Tampering Platform
Host an SMTP server that will save all attachments received to a specified folder, which will be checked every two minutes and will execute all files with the listed keywords in them. A small scale phishing simulation. Use send.py to avoid having to craft SMTP messages yourself.
