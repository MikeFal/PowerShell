$LabConfig = Get-Content C:\git-repositories\PowerShell\MSFVMLab\LabVMS.json | ConvertFrom-Json
$WorkingDirectory = $LabConfig.WorkingDirectory
$DomainCred = Import-Clixml "$WorkingDirectory\vmlab_domainadmin.xml"
$dc = ( $LabConfig.Servers | Where-Object {$_.Class -eq 'DomainController'}).Name

Copy-VMFile -VMName $dc -SourcePath C:\Temp\AdventureWorks2014.Full.bak -DestinationPath C:\Temp\AdventureWorks2014.Full.bak -FileSource Host -CreateFullPath -Force
Copy-VMFile -VMName $dc -SourcePath C:\git-repositories\PowerShell\MSFVMLab\BuildAG.ps1 -DestinationPath C:\Temp\BuildAG.ps1 -FileSource Host -CreateFullPath -Force

Invoke-Command -VMName $dc -ScriptBlock {C:\temp\BuildAG.ps1} -Credential $DomainCred