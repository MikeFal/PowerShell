#Load MSFVMLab module
Import-Module C:\git-repositories\PowerShell\MSFVMLab\MSFVMLab.psm1 -Force

$LabConfig = Get-Content C:\git-repositories\PowerShell\MSFVMLab\LabVMS.json | ConvertFrom-Json
$WorkingDirectory = $LabConfig.WorkingDirectory
$Domain = $LabConfig.Domain
$LocalAdminCred = Import-Clixml "$WorkingDirectory\vmlab_localadmin.xml"
$DomainCred = Import-Clixml "$WorkingDirectory\vmlab_domainadmin.xml"

#Use DSC to deploy AD DC
$dc = ( $LabConfig.Servers | Where-Object {$_.Class -eq 'DomainController'}).Name

#Load DSC Files
Copy-VMFile -Name $dc -SourcePath 'C:\git-repositories\PowerShell\MSFVMLab\VMDSC.ps1' -DestinationPath 'C:\Temp\VMDSC.ps1' -CreateFullPath -FileSource Host -Force
Copy-VMFile -Name $dc -SourcePath 'C:\git-repositories\PowerShell\MSFVMLab\VMDSC_DHCP.ps1' -DestinationPath 'C:\Temp\VMDSC_DHCP.ps1' -CreateFullPath -FileSource Host -Force
Copy-VMFile -Name $dc -SourcePath 'C:\git-repositories\PowerShell\MSFVMLab\SQLDSC.ps1' -DestinationPath 'C:\Temp\SQLDSC.ps1' -CreateFullPath -FileSource Host -Force

Invoke-Command -VMName $dc -ScriptBlock {. C:\Temp\VMDSC.ps1 -DName "$using:Domain.com" -DCred $using:DomainCred} -Credential $LocalAdminCred

#Restart DC to complete
Stop-VM $dc
Start-VM $dc

#Log on to DC and complete config
Write-Warning "Log into the DC and complete promotion!"
