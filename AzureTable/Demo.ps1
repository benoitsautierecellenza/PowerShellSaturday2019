$uri = "http://standards.ieee.org/develop/regauth/oui/oui.txt"
$output = "C:\temp\vendors.txt"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-RestMethod -Uri $uri -Method GET -OutFile $output