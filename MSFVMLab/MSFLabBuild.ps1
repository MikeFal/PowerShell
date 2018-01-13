#Load MSFVMLab module
Import-Module C:\git-repositories\PowerShell\MSFVMLab\MSFVMLab.psm1 -Force

$LabConfig = Get-Content C:\git-repositories\PowerShell\MSFVMLab\LabVMS.json | ConvertFrom-Json
$Servers = $LabConfig.Servers
$Domain = $LabConfig.Domain

#Create VM Switches
foreach($network in $LabConfig.Switches){
    If(!(Get-VMSwitch $network.Name -ErrorAction SilentlyContinue)){
            New-VMSwitch -Name $network.Name -SwitchType $network.Type
        }
}

#Set creds
$LocalAdminCred = Get-Credential -Message 'Local Adminstrator Credential' -UserName 'localhost\administrator'
$DomainCred = Get-Credential -Message 'Domain Credential' -UserName "$domain\administrator"
$sqlsvccred = Get-Credential -Message 'SQL Server Service credential' -UserName "$domain\sqlsvc"

#create VMs
foreach($Server in $Servers){

if(!(Get-VM -Name $Server.name -ErrorAction SilentlyContinue)){

    $img=switch($Server.Type){
        'Full'{'C:\VMs\ISOs\GM2016Full.vhdx'}
        default{'C:\VMs\ISOs\GM2016Core.vhdx'}
    }
     $server.Name
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
foreach($Server in $Servers){
    $VMName = $Server.name
    Get-VM -Name $VMName | Get-VMIntegrationService | Where-Object {!($_.Enabled)} | Enable-VMIntegrationService -Verbose

    #load dependencies
    Invoke-Command -VMName $VMName {Get-PackageProvider -Name NuGet -ForceBootstrap; Install-Module @('xComputerManagement','xActiveDirectory','xNetworking','xDHCPServer','SqlServer') -Force} -Credential $LocalAdminCred
    
   if($Server.Type -eq 'Core'){
        #If Core, set default shell to Powershell
        Invoke-Command -VMName $VMName -Credential $LocalAdminCred {set-itemproperty "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon" shell 'powershell.exe -noexit -command "$psversiontable;"';Rename-Computer -NewName $using:VMName -Force –Restart}
    }
    else{
        Invoke-Command -VMName $VMName -Credential $LocalAdminCred { Rename-Computer -NewName $using:VMName -Force –Restart}
    }
}


#Use DSC to deploy AD DC
$dc = ($Servers | Where-Object {$_.Class -eq 'DomainController'}).Name

#Load DSC Files
Copy-VMFile -Name $dc -SourcePath 'C:\git-repositories\PowerShell\MSFVMLab\VMDSC.ps1' -DestinationPath 'C:\Temp\VMDSC.ps1' -CreateFullPath -FileSource Host -Force
Copy-VMFile -Name $dc -SourcePath 'C:\git-repositories\PowerShell\MSFVMLab\SQLDSC.ps1' -DestinationPath 'C:\Temp\SQLDSC.ps1' -CreateFullPath -FileSource Host -Force

Invoke-Command -VMName $dc -ScriptBlock {. C:\Temp\VMDSC.ps1 -DName "$using:Domain.com" -DCred $using:DomainCred} -Credential $LocalAdminCred

#Restart DC to complete
Stop-VM $dc
Start-VM $dc

#Log on to DC and complete config








foreach($node in $sqlnodes){
    Copy-VMFile -Name $node -SourcePath 'C:\git-repositories\PowerShell\MSFVMLab\2016install.ini' -DestinationPath 'C:\TEMP\2016install.ini' -CreateFullPath -FileSource Host -Force
    Invoke-Command -VMName $node -ScriptBlock $cmd -Credential $DomainCred
}





###################################
#Commented out for safeties sake
#This destroys the lab
###################################
foreach($Server in $Servers){
    Remove-LabVM $Server.Name
}
