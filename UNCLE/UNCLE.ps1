#Creates a scheulded task to reach out to a UNC share that doesnt exist at regular intervals. Designed to add realism to a scenario you would use responder.

$taskName = "SMB Share Access"
$taskDescription = "Accesses specified SMB shares every 5 minutes for user $username"
$taskAction = "cmd.exe /c net use \\Documents\Finance /user:1 Water#123"
schtasks.exe /create /tn $taskName /tr $taskAction /sc MINUTE /mo 5 /ru "NT AUTHORITY\SYSTEM" /f
