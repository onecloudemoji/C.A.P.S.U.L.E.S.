# Detect the network adapter alias
$interface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1 -ExpandProperty Name

# Set IP Address
New-NetIPAddress -InterfaceAlias $interface -IPAddress 192.168.1.130 -PrefixLength 24 -DefaultGateway 192.168.1.1

# Set Hostname
Rename-Computer -NewName "DC02" -Force -Restart