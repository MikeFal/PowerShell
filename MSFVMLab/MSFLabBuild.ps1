#dot source Lab VM Functions
. C:\git-repositories\PowerShell\MSFVMLab\New-LabVM.ps1
. C:\git-repositories\PowerShell\Convert-WindowsImage.ps1

#Create VM Switches
If(!(Get-VMSwitch 'HostNetwork' -ErrorAction SilentlyContinue)){New-VMSwitch -Name 'HostNetwork' -SwitchType Internal}
If(!(Get-VMSwitch 'LabNetwork' -ErrorAction SilentlyContinue)){New-VMSwitch -Name 'LabNetwork' -SwitchType Private}

$Server2016path = 'F:\VMs\ISOs\en_windows_server_2016_technical_preview_3_x64_dvd_6942082.iso'
$Server2012path = 'F:\VMs\ISOs\en_windows_server_2012_r2_with_update_x64_dvd_6052708.iso'

#Create GM image
if(Test-Path F:\VMs\ISOs\GM2016Tp3Core.vhdx){Remove-Item F:\VMs\ISOs\GM2016Tp3Core.vhdx}
Convert-WindowsImage -SourcePath $Server2016path -VHDPath F:\VMs\ISOs\GM2016Tp3Core.vhdx -VHDFormat VHDX -VHDType Dynamic -Edition ServerDatacenterCore -VHDPartitionStyle MBR -UnattendPath F:\VMs\ISOs\unattend.xml

if(Test-Path F:\VMs\ISOs\GM2016Tp3Full.vhdx){Remove-Item F:\VMs\ISOs\GM2016Tp3Full.vhdx}
Convert-WindowsImage -SourcePath $Server2016path -VHDPath F:\VMs\ISOs\GM2016Tp3Full.vhdx -VHDFormat VHDX -VHDType Dynamic -Edition ServerDatacenter -VHDPartitionStyle MBR -UnattendPath F:\VMs\ISOs\unattend.xml


if(Test-Path F:\VMs\ISOs\GM2012R2Core.vhdx){Remove-Item F:\VMs\ISOs\GM2012R2Core.vhdx}
Convert-WindowsImage -SourcePath $Server2016path -VHDPath F:\VMs\ISOs\GM2012R2Core.vhdx -VHDFormat VHDX -VHDType Dynamic -Edition ServerDatacenterCore -VHDPartitionStyle MBR -UnattendPath F:\VMs\ISOs\unattend.xml

if(Test-Path F:\VMs\ISOs\GM2012R2Full.vhdx){Remove-Item F:\VMs\ISOs\GM2012R2Full.vhdx}
Convert-WindowsImage -SourcePath $Server2016path -VHDPath F:\VMs\ISOs\GM2012R2Full.vhdx -VHDFormat VHDX -VHDType Dynamic -Edition ServerDatacenter -VHDPartitionStyle MBR -UnattendPath F:\VMs\ISOs\unattend.xml


#add custom Powershell
$DriveLetter = (Mount-VHD F:\VMs\ISOs\GM2016Tp3core.vhdx –PassThru | Get-Disk | Get-Partition | Get-Volume).DriveLetter
Copy-Item -Path C:\git-repositories\PowerShell\cSQLResources -Destination "$DriveLetter`:\Program Files\WindowsPowershell\Modules" -Recurse 
Copy-Item -Path C:\git-repositories\PowerShell\SqlConfiguration -Destination "$DriveLetter`:\Program Files\WindowsPowershell\Modules" -Recurse 
Dismount-VHD -Path F:\VMs\ISOs\GM2016Tp3core.vhdx

$Servers = @()
$Servers += New-Object psobject -Property @{Name='PIKE';Type='Full';Class='DomainController'}
$Servers += New-Object psobject -Property @{Name='PICARD';Type='Core';Class='SQLServer'}
$Servers += New-Object psobject -Property @{Name='RIKER';Type='Core';Class='SQLServer'}

#create VM
$pw = ConvertTo-SecureString -String 'vanh0uten!42' -AsPlainText -Force
$LocalAdminCred = New-Object System.Management.Automation.PSCredential ('localhost\administrator',$pw)

foreach($Server in $Servers){

if(!(Get-VM -Name $Server.name -ErrorAction SilentlyContinue)){

    $img=switch($Server.Type){
        'Full'{'F:\VMs\ISOs\GM2016Tp3Full.vhdx'}
        default{'F:\VMs\ISOs\GM2016Tp3Core.vhdx'}
    }
     
    New-LabVM -VMName $Server.name `
        -LocalCred $LocalAdminCred `
        -VMPath 'F:\VMs\Machines' `
        -VHDPath 'F:\VMs\VHDs' `
        -ISOs @('F:\VMs\ISOs\en_windows_server_2016_technical_preview_3_x64_dvd_6942082.iso','F:\VMs\ISOs\SQLServer2016CTP2.3-x64-ENU.iso') `
        -VMSource $img `
        -VMSwitches @('HostNetwork','LabNetwork') `
        -Verbose
    }
}


#Run this once all machines are up and available to rename
#You will need to connect and log in to the AD machine. Because it's dumb.
foreach($Server in $Servers){
    $VMName = $Server.name
    if($Server.Type -eq 'Core'){
        #If Core, set default shell to Powershell
        Invoke-Command -VMName $VMName -Credential $LocalAdminCred {set-itemproperty "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon" shell 'powershell.exe -noexit -command "$psversiontable;"';Rename-Computer -NewName $using:VMName -Force –Restart}
    }
    else{
        Invoke-Command -VMName $VMName -Credential $LocalAdminCred {Rename-Computer -NewName $using:VMName -Force –Restart}
    }
}


#Use DSC to deploy AD DC
$dc = ($Servers | Where-Object {$_.Class -eq 'DomainController'}).Name

#load dependencies
Invoke-Command -VMName $dc {Get-PackageProvider -Name NuGet -ForceBootstrap; Install-Module @('xComputerManagement','xActiveDirectory','xNetworking','xDHCPServer') -Force} -Credential $LocalAdminCred

#Install DC
$cmdstr = Get-Content C:\git-repositories\PowerShell\MSFVMLab\VMDSC.ps1
$cmd = [scriptBlock]::Create($cmdstr -join "`n")
Invoke-Command -VMName $dc $cmd -Credential $LocalAdminCred

#Restart DC to complete
Stop-VM $dc
Start-VM $dc

#DHCP install
$cmdstr = Get-Content C:\git-repositories\PowerShell\MSFVMLab\VMDSC_DHCP.ps1
$cmd = [scriptBlock]::Create($cmdstr -join "`n")
Invoke-Command -VMName $dc $cmd -Credential $DomainCred #$LocalAdminCred

#Log on to DC and complete config

#Join machines to domain
$DomainCred =  Get-Credential

foreach($Server in $($Servers | Where-Object {$_.Class -ne 'DomainController'})){
       Invoke-Command -VMName $Server.Name -Credential $LocalAdminCred -ScriptBlock {Add-Computer -DomainName 'DEATHSTAR.local' -Credential $using:DomainCred -Restart}

}

###################################
#Commented out for safeties sake
#This destroys the lab
###################################
foreach($Server in $Servers){
    Remove-LabVM $Server.Name
}
