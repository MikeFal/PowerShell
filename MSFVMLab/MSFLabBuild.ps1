#dot source Lab VM Functions
. C:\git-repositories\PowerShell\MSFVMLab\New-LabVM.ps1

#Create VM Switches
If(!(Get-VMSwitch 'HostNetwork' -ErrorAction SilentlyContinue)){New-VMSwitch -Name 'HostNetwork' -SwitchType Internal}
If(!(Get-VMSwitch 'LabNetwork' -ErrorAction SilentlyContinue)){New-VMSwitch -Name 'LabNetwork' -SwitchType Private}

$Servers = @()
$Servers += New-Object psobject -Property @{Name='PIKE';Type='Full';Class='DomainController'}
$Servers += New-Object psobject -Property @{Name='PICARD';Type='Core';Class='SQLServer'}
$Servers += New-Object psobject -Property @{Name='RIKER';Type='Core';Class='SQLServer'}

$Domain = 'STARFLEET'
#create VM
$LocalAdminCred = Get-Credential -Message 'Local Adminstrator Credential' -UserName 'localhost\administrator'
$DomainCred = Get-Credential -Message 'Domain Credential' -UserName "$domain\administrator"
$sqlsvccred = Get-Credential -Message 'Please enter the SQL Server Service credential' -UserName "$domain\sqlsvc"

foreach($Server in $Servers){

if(!(Get-VM -Name $Server.name -ErrorAction SilentlyContinue)){

    $img=switch($Server.Type){
        'Full'{'F:\VMs\ISOs\GM2016Full.vhdx'}
        default{'F:\VMs\ISOs\GM2016Core.vhdx'}
    }
     
    New-LabVM -VMName $Server.name `
        -LocalCred $LocalAdminCred `
        -VMPath 'F:\VMs\Machines' `
        -VHDPath 'F:\VMs\VHDs' `
        -ISOs @('F:\VMs\ISOs\en_windows_server_2016_technical_preview_4_x64_dvd_7258292.iso','F:\VMs\ISOs\en_sql_server_2016_ctp3.2_x64_dvd_8169194.iso') `
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
    Invoke-Command -VMName $VMName {Get-PackageProvider -Name NuGet -ForceBootstrap; Install-Module @('xComputerManagement','xActiveDirectory','xNetworking','xDHCPServer','xSqlServer') -Force} -Credential $DomainCred
    <#
    if($Server.Type -eq 'Core'){
        #If Core, set default shell to Powershell
        Invoke-Command -VMName $VMName -Credential $LocalAdminCred {set-itemproperty "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon" shell 'powershell.exe -noexit -command "$psversiontable;"';Rename-Computer -NewName $using:VMName -Force –Restart}
    }
    else{
        Invoke-Command -VMName $VMName -Credential $LocalAdminCred {Rename-Computer -NewName $using:VMName -Force –Restart}
    }#>
}


#Use DSC to deploy AD DC
$dc = ($Servers | Where-Object {$_.Class -eq 'DomainController'}).Name

#Load DSC Files
Copy-VMFile -Name $dc -SourcePath 'C:\git-repositories\PowerShell\MSFVMLab\VMDSC.ps1' -DestinationPath 'C:\Temp\VMDSC.ps1' -CreateFullPath -FileSource Host -Force
Copy-VMFile -Name $dc -SourcePath 'C:\git-repositories\PowerShell\MSFVMLab\VMDSC_DHCP.ps1' -DestinationPath 'C:\Temp\VMDSC_DHCP.ps1' -CreateFullPath -FileSource Host -Force
Copy-VMFile -Name $dc -SourcePath 'C:\git-repositories\PowerShell\MSFVMLab\SQLDSC.ps1' -DestinationPath 'C:\Temp\SQLDSC.ps1' -CreateFullPath -FileSource Host -Force

Invoke-Command -VMName $dc -ScriptBlock {. C:\Temp\VMDSC.ps1 -DName 'starfleet.com' -DCred $using:DomainCred} -Credential $LocalAdminCred

#Restart DC to complete
Stop-VM $dc
Start-VM $dc

#DHCP install
Invoke-Command -VMName $dc -ScriptBlock {. C:\Temp\VMDSC_DHCP.ps1 -DName 'starfleet.com'} -Credential $DomainCred #$LocalAdminCred

#Log on to DC and complete config

foreach($Server in $($Servers | Where-Object {$_.Class -ne 'DomainController'})){ 
    Invoke-Command -VMName $Server.Name -Credential $LocalAdminCred -ScriptBlock {ipconfig /release;ipconfig /renew;Add-Computer -DomainName 'starfleet.com' -Credential $using:DomainCred -Restart}
}


#Deploy SQL Servers
#Create Service Account

[ScriptBlock]$svccmd = {
param([PSCredential]$sqlsvc)
New-ADUser -Name $sqlsvc.GetNetworkCredential().UserName -AccountPassword $sqlsvc.Password -PasswordNeverExpires $true -CannotChangePassword $true
Enable-ADAccount -Identity $sqlsvc.GetNetworkCredential().UserName 
Add-ADGroupMember 'Domain Admins' -Members $sqlsvc.GetNetworkCredential().UserName
}

Invoke-Command -VMName $dc -ScriptBlock $svccmd -ArgumentList $sqlsvccred -Credential $DomainCred

$sqlnodes = ($Servers | Where-Object {$_.Class -eq 'SQLServer'}).Name

Invoke-Command -VMName $dc -ScriptBlock {. C:\Temp\SQLDSC.ps1 -SqlNodes $using:sqlnodes -SetupCredential $using:DomainCred -SqlSvcAccount $using:sqlsvccred -AgtSvcAccount $using:sqlsvccred -SqlAdmins 'STARFLEET\Domain Admins'} -Credential $DomainCred 


###################################
#Commented out for safeties sake
#This destroys the lab
###################################
foreach($Server in $Servers){
    Remove-LabVM $Server.Name
}
