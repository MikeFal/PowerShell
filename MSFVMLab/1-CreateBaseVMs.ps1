param([Switch]$SqlOnly)
#Load MSFVMLab module
Import-Module C:\git-repositories\PowerShell\MSFVMLab\MSFVMLab.psm1 -Force

$LabConfig = Get-Content C:\git-repositories\PowerShell\MSFVMLab\LabVMS.json | ConvertFrom-Json
$Servers = if($SqlOnly){$LabConfig.Servers | Where-Object {$_.class -ne 'DomainController'}} else {$LabConfig.Servers}
$WorkingDirectory = $LabConfig.WorkingDirectory

#Check for working directory
If(-not (Test-Path $WorkingDirectory)){
    Write-Error "$WorkingDirectory does not exist!" -ErrorAction Stop
}

$LocalAdminCred = Import-Clixml "$WorkingDirectory\vmlab_localadmin.xml"
#create VMs
foreach($Server in $Servers){

if(!(Get-VM -Name $Server.name -ErrorAction SilentlyContinue)){

    $img=switch($Server.Type){
        'Full'{'C:\VMs\ISOs\GM2016Full.vhdx'}
        default{'C:\VMs\ISOs\GM2016Core.vhdx'}
    }
    New-LabVM -VMName $Server.name `
        -VMPath 'C:\VMs\Machines' `
        -VHDPath 'C:\VMs\VHDs' `
        -ISOs @('C:\VMs\ISOs\en_windows_server_2016_x64_dvd_9718492.ISO','C:\VMs\ISOs\en_sql_server_2016_developer_with_service_pack_1_x64_dvd_9548071.iso') `
        -VMSource $img `
        -VMSwitches @('HostNetwork','LabNetwork') `
        -Verbose
    }
}


#Run this once all machines are up and available to rename
#You will need to connect and log in to the AD machine. Because it's dumb.
#Also enable the VMIntegrationService
Get-VM -Name $Servers.Name | Get-VMIntegrationService | Where-Object {!($_.Enabled)} | Enable-VMIntegrationService -Verbose
Invoke-Command -VMName $Servers.Name {Get-PackageProvider -Name NuGet -ForceBootstrap; Install-Module @('xComputerManagement','xActiveDirectory','xNetworking','xDHCPServer','SqlServer') -Force} -Credential $LocalAdminCred
($Servers | Where-Object {$_.Type -eq 'Core'}).name |
    ForEach-Object{Invoke-Command -VMName $_ -Credential $LocalAdminCred {set-itemproperty "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon" shell 'powershell.exe -noexit -command "$psversiontable;"';Rename-Computer -Force -Restart -NewName $using:_ }}

($Servers | Where-Object {$_.Type -ne 'Core'}).Name |
    ForEach-Object {Invoke-Command -VMName $_  -Credential $LocalAdminCred { Rename-Computer -NewName $using:_ -Force -Restart}}
