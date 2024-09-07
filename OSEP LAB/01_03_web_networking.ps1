# Detect the network adapter alias
$interface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1 -ExpandProperty Name

# Set IP Address
New-NetIPAddress -InterfaceAlias $interface -IPAddress 192.168.1.132 -PrefixLength 24 -DefaultGateway 192.168.1.1

# Set DNS Server
Set-DnsClientServerAddress -InterfaceAlias $interface -ServerAddresses 192.168.1.130

# Set Hostname
Rename-Computer -NewName "WEB01" -Force -Restart