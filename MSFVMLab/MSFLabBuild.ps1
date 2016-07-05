#Load MSFVMLab module
Import-Module C:\git-repositories\PowerShell\MSFVMLab\MSFVMLab.psm1 -Force

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
        'Full'{'C:\VMs\ISOs\GM2016TP5Full.vhdx'}
        default{'C:\VMs\ISOs\GM2016TP5Core.vhdx'}
    }
     $server.Name
    New-LabVM -VMName $Server.name `
        -VMPath 'C:\VMs\Machines' `
        -VHDPath 'C:\VMs\VHDs' `
        -ISOs @('C:\VMs\ISOs\14300.1000.160324-1723.RS1_RELEASE_SVC_SERVER_OEMRET_X64FRE_EN-US.ISO','C:\VMs\ISOs\en_sql_server_2016_developer_x64_dvd_8777069.iso') `
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
    Invoke-Command -VMName $VMName {Get-PackageProvider -Name NuGet -ForceBootstrap; Install-Module @('xComputerManagement','xActiveDirectory','xNetworking','xDHCPServer','xSqlServer') -Force} -Credential $LocalAdminCred
    
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
#Set DNS
Invoke-Command -VMName $Server.Name { ipconfig /release ; ipconfig /renew ; $idx = (Get-NetIPAddress | Where-Object {$_.IPAddress -like '10*'}).InterfaceIndex; Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses '10.10.10.1'} -Credential $LocalAdminCred
    Invoke-Command -VMName $Server.Name -Credential $LocalAdminCred -ScriptBlock {Add-Computer -DomainName 'starfleet.com' -Credential $using:DomainCred -Restart}
}


#Deploy SQL Servers
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

$sqlnodes = ($Servers | Where-Object {$_.Class -eq 'SQLServer'}).Name
$cmd = [ScriptBlock]::Create("& E:\setup.exe /CONFIGURATIONFILE='C:\TEMP\2016install.ini' /SQLSVCACCOUNT='STARFLEET\$($sqlsvccred.GetNetworkCredential().UserName)' /SQLSVCPASSWORD='$($sqlsvccred.GetNetworkCredential().Password)' /AGTSVCACCOUNT='STARFLEET\$($sqlsvccred.GetNetworkCredential().UserName)' /AGTSVCPASSWORD='$($sqlsvccred.GetNetworkCredential().Password)' /SAPWD='$($sqlsvccred.GetNetworkCredential().Password)' /IACCEPTSQLSERVERLICENSETERMS")
Invoke-Command -VMName $dc -ScriptBlock {. C:\Temp\SQLDSC.ps1 -SqlNodes $using:sqlnodes} -Credential $DomainCred 

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
