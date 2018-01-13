#Load MSFVMLab module
Import-Module C:\git-repositories\PowerShell\MSFVMLab\MSFVMLab.psm1 -Force

$LabConfig = Get-Content C:\git-repositories\PowerShell\MSFVMLab\LabVMS.json | ConvertFrom-Json
$WorkingDirectory = $LabConfig.WorkingDirectory
$DomainCred = Import-Clixml "$WorkingDirectory\vmlab_domainadmin.xml"
$LocalAdminCred = Import-Clixml "$WorkingDirectory\vmlab_localadmin.xml"
$sqlsvccred = Import-Clixml "$WorkingDirectory\vmlab_sqlsvc.xml"

$dc = ( $LabConfig.Servers | Where-Object {$_.Class -eq 'DomainController'}).Name
$sqlnodes = ($LabConfig.servers | Where-Object {$_.Class -eq 'SQLServer'}).Name

#Create Service Account
[ScriptBlock]$svccmd = {
    param([PSCredential]$sqlsvc)
    New-ADUser -Name $sqlsvc.GetNetworkCredential().UserName -AccountPassword $sqlsvc.Password -PasswordNeverExpires $true -CannotChangePassword $true
    Enable-ADAccount -Identity $sqlsvc.GetNetworkCredential().UserName 

    New-ADUser -Name 'mike.fal' -AccountPassword (ConvertTo-SecureString 'P@ssw0rd!' -AsPlainText -Force) -ChangePasswordAtLogon $true
    Enable-ADAccount -Identity 'mike.fal'

    Add-ADGroupMember 'Domain Admins' -Members @($sqlsvc.GetNetworkCredential().UserName,'mike.fal')
}
Invoke-Command -VMName $dc -ScriptBlock $svccmd -ArgumentList $sqlsvccred -Credential $DomainCred

#Set DNS for lab network adapters
Invoke-Command -VMName $sqlnodes { ipconfig /release ; ipconfig /renew ; $idx = (Get-NetIPAddress | Where-Object {$_.IPAddress -like '10*'}).InterfaceIndex; Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses '10.10.10.1'} -Credential $LocalAdminCred

Write-Warning 'Sleeping for 60 seconds for DNS cache to update.'
Start-Sleep -Seconds 60

Invoke-Command -VMName $sqlnodes -Credential $LocalAdminCred -ScriptBlock {Add-Computer -DomainName "$($using:Labconfig.domain).com" -Credential $using:DomainCred -Restart}
