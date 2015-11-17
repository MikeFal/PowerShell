function New-LabVM{
    param([string]$VMName
        ,[string]$VMPath
        ,[string]$VHDPath
        ,[string[]]$VMSwitches
        ,[string[]]$ISOs
        ,[string]$VMSource
        ,[Parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$LocalCred
        )
    try{
        $VHDFile = Join-Path -Path $VHDPath -ChildPath "$VMName.vhdx"
        $VMFile = Join-Path -Path $VMPath -ChildPath "$VMName.vhdx"

        if($VMSource){
            Write-Verbose "[$(Get-Date -Format 'HH:mm:ss')]Creating $VHDFile from $VMSource ..."
            Copy-Item $VMSource $VHDFile
            Write-Verbose "[$(Get-Date -Format 'HH:mm:ss')]Setting boot order to VHD first..."
            $StartOrder = @("IDE","CD","LegacyNetworkAdapter","Floppy")
        }
        else{
            Write-Verbose "[$(Get-Date -Format 'HH:mm:ss')]Creating empty $VHDFile ($VHDSize GB) ..."
            $VHDSizeBytes = $VHDSizeGB*1GB
            New-VHD -Path $VHDFile -SizeBytes $VHDSizeBytes -Dynamic

            Write-Verbose "[$(Get-Date -Format 'HH:mm:ss')]Setting boot order to DVD first..."
            $StartOrder = @("CD","IDE","LegacyNetworkAdapter","Floppy")
        }

        Write-Verbose "[$(Get-Date -Format 'HH:mm:ss')]Creating $VMName..."    
        New-VM -Name $VMName -BootDevice CD -Generation 1 -Path $VMPath -SwitchName $VMSwitches[0]
        Set-VMBios -VMName $VMName -StartupOrder $StartOrder
        Add-VMHardDiskDrive -VMName $VMName -Path $VHDFile  -ControllerNumber 0 -ControllerLocation 0
        foreach($VMSwitch in $VMSwitches){
            if($VMSwitch -eq $VMSwitches[0]){
                Rename-VMNetworkAdapter -VMName $VMName -Name 'Network Adapter' -NewName $VMSwitch
            }
            else{
                Add-VMNetworkAdapter -VMName $VMName -Name $VMSwitch -SwitchName $VMSwitch
            }
        }

        foreach($ISO in $ISOs){
            if($ISO -eq $ISOs[0]){
                Set-VMDvdDrive -vmname $VMName -Path $ISO -ToControllerNumber 1 -ToControllerLocation 0
            }
            else{
                Add-VMDvdDrive -VMName $VMName -Path $ISO -ControllerNumber 1 -ControllerLocation $ISOs.IndexOf($ISO)
            }
        }
        
        Write-Verbose "[$(Get-Date -Format 'HH:mm:ss')]Starting $VMName..."
        $NewVM = Get-VM -Name $VMName
        $NewVM | Start-VM

        #Configure appropriate shell
        Write-Verbose "[$(Get-Date -Format 'HH:mm:ss')]Renaming computer..."
        Start-Sleep 60
        Invoke-Command -VMName $VMName -Credential $LocalCred {Rename-Computer -NewName $using:VMName -Force -Restart;}

        
        Write-Verbose "[$(Get-Date -Format 'HH:mm:ss')]$VMName complete."
        return $NewVM
    }
    catch{
        Write-Error $Error[0]
        return
    }
}

if (get-module WindowsImageTools) { Remove-Module WindowsImageTools}

import-module WindowsImageTools

Initialize-VHDPartition -Path $env:temp\temp1.vhdx -Dynamic -Verbose -DiskLayout UEFI -RecoveryImage -force -Passthru |  
    Set-VHDPartition  -SourcePath $PSScriptRoot\Example.wim -Index 1  -Confirm:$false -force -Verbose 

Convert-Wim2VHD -Path $env:temp\test2.vhdx -SourcePath $PSScriptRoot\Example.wim -DiskLayout BIOS -Dynamic -Index 1 -Size 50GB  -Force -Verbose
set
#Create VM Switch
If(!(Get-VMSwitch 'HostNetwork')){New-VMSwitch -Name 'HostNetwork' -SwitchType Internal}
If(!(Get-VMSwitch 'LabNetwork')){New-VMSwitch -Name 'LabNetwork' -SwitchType Private}

#Create GM image
if(Test-Path F:\VMs\ISOs\GM2016Tp3.vhdx){Remove-Item C:\VMs\ISOs\GM2016Tp3.vhdx}
Convert-WindowsImage -SourcePath C:\VMs\ISOs\en_windows_server_2016_technical_preview_3_x64_dvd_6942082.iso -VHDPath C:\VMs\ISOs\GM2016Tp3.vhdx -VHDFormat VHDX -VHDType Dynamic -Edition ServerDatacenterCore -VHDPartitionStyle MBR -UnattendPath C:\VMs\ISOs\unattend.xml

if(Test-Path C:\VMs\ISOs\GM2012R2Core.vhdx){Remove-Item C:\VMs\ISOs\GM2012R2Core.vhdx}
Convert-Wim2VHD -SourcePath C:\VMs\ISOs\en_windows_server_2012_r2_with_update_x64_dvd_6052708.iso -Path C:\VMs\ISOs\GM2012R2Core.vhdx -VHDFormat VHDX -Dynamic -Index 3 -DiskLayout BIOS -Unattend C:\VMs\ISOs\unattend.xml 

if(Test-Path C:\VMs\ISOs\GM2012R2Full.vhdx){Remove-Item C:\VMs\ISOs\GM2012R2Full.vhdx}
Convert-WindowsImage -SourcePath C:\VMs\ISOs\en_windows_server_2012_r2_with_update_x64_dvd_6052708.iso -VHDPath C:\VMs\ISOs\GM2012R2Full.vhdx -VHDFormat VHDX -VHDType Dynamic -Edition ServerDatacenter -VHDPartitionStyle MBR -UnattendPath C:\VMs\ISOs\unattend.xml


#add custom Powershell
$DriveLetter = (Mount-VHD F:\VMs\ISOs\GM2016Tp3.vhdx –PassThru | Get-Disk | Get-Partition | Get-Volume).DriveLetter
Copy-Item -Path C:\git-repositories\PowerShell\cSQLResources -Destination "$DriveLetter`:\Program Files\WindowsPowershell\Modules" -Recurse 
Copy-Item -Path C:\git-repositories\PowerShell\SqlConfiguration -Destination "$DriveLetter`:\Program Files\WindowsPowershell\Modules" -Recurse 
Dismount-VHD -Path F:\VMs\ISOs\GM2016Tp3.vhdx

$Servers = @()
$Servers += New-Object psobject -Property @{Name='PALPATINE';Type='Full';Class='DomainController'}
$Servers += New-Object psobject -Property @{Name='VADER';Type='Core';Class='SQLServer'}
$Servers += New-Object psobject -Property @{Name='TARKIN';Type='Core';Class='SQLServer'}

#create VM
$pw = ConvertTo-SecureString -String 'vanh0uten!42' -AsPlainText -Force
$LocalAdminCred = New-Object System.Management.Automation.PSCredential ('localhost\administrator',$pw)

foreach($Server in $Servers){

New-LabVM -VMName $Server.name `
    -LocalCred $LocalAdminCred `
    -OSType $Server.Type `
    -VMPath 'F:\VMs\Machines' `
    -VHDPath 'F:\VMs\VHDs' `
    -ISOs @('F:\VMs\ISOs\en_windows_server_2016_technical_preview_3_x64_dvd_6942082.iso','F:\VMs\ISOs\SQLServer2016CTP2.3-x64-ENU.iso') `
    -VMSource F:\VMs\ISOs\GM2016Tp3.vhdx `
    -VMSwitches @('HostNetwork','LabNetwork') `
    -Verbose 
}

New-LabVM -VMName 'RIKER' `
    -LocalCred $LocalAdminCred `
    -VMPath 'C:\VMs\Machines' `
    -VHDPath 'C:\VMs\VHDs' `
    -ISOs @('C:\VMs\ISOs\en_windows_server_2012_r2_with_update_x64_dvd_6052708.iso') `
    -VMSource C:\VMs\ISOs\GM2012R2Core.vhdx `
    -VMSwitches @('Host','VMSWitch') `
    -Verbose 



        switch($OSType){
            'Full'{Invoke-Command -VMName $VMName -Credential $LocalCred {Rename-Computer -NewName $using:VMName -Force;Get-WindowsFeature server-gui* | Add-WindowsFeature -Source wim:D:\sources\install.wim:4 –Restart}}
            'Core'Set-ItemProperty 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon' shell 'Powershell.exe -noexit -command "$psversiontable;"';Restart-Computer}}
        }



$Servers = @()
$Servers += New-Object psobject -Property @{Name='VADER';Type='Core';Class='SQLServer'}
$Servers += New-Object psobject -Property @{Name='TARKIN';Type='Core';Class='SQLServer'}

#create VM
$pw = ConvertTo-SecureString -String 'vanh0uten!42' -AsPlainText -Force
$LocalAdminCred = New-Object System.Management.Automation.PSCredential ('localhost\administrator',$pw)

foreach($Server in $Servers){

New-LabVM -VMName $Server.name `
    -LocalCred $LocalAdminCred `
    -VMPath 'C:\VMs\Machines' `
    -VHDPath 'C:\VMs\VHDs' `
    -ISOs @('C:\VMs\ISOs\en_windows_server_2016_technical_preview_3_x64_dvd_6942082.iso','C:\VMs\ISOs\en_sql_server_2014_developer_edition_x64_dvd_3940406.iso') `
    -VMSource C:\VMs\ISOs\GM2016Tp3.vhdx `
    -VMSwitches @('Host','VMSWitch') `
    -Verbose 

    Invoke-Command -VMName $Server.name `-Credential $LocalAdminCred {Set-ItemProperty 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\WinLogon' shell 'Powershell.exe -noexit -command "$psversiontable;"';Restart-Computer}

}

