function New-LabVM{
param([parameter(Mandatory=$true)][string]$VMName
    ,[ValidateSet('Full','Core')] [string]$InstallType
    )

#These are premade disk images with server installs syspreped
$SourceVHD = switch($InstallType){
    'Full'{'C:\vms\VHDs\GM-Server2012Full.vhdx'}
    'Core'{'C:\vms\VHDs\GM-Server2012R2Core.vhdx'}
}

#Create VM
new-VM -Name $VMName -BootDevice CD -SwitchName 'VMSwitch'

#Copy the syspreped VHDX so it is a separate file for the VM. Attach it.
Copy-Item $SourceVHD "C:\vms\VHDs\$VMname.vhdx"
Add-VMHardDiskDrive -VMName $VMName -Path "C:\vms\VHDs\$VMname.vhdx"  -ControllerNumber 0 -ControllerLocation 0

#Set DVDdrive to ISO image
Set-VMDvdDrive -vmname $VMName -Path C:\VMs\ISOs\en_windows_server_2012_r2_with_update_x64_dvd_6052708.iso -ToControllerNumber 1 -ToControllerLocation 0

#Set Dynamic memory
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true

#Rename the NIC
Rename-VMNetworkAdapter -VMName $VMName -Name 'Network Adapter' -NewName 'LocalNetwork'

#Start VM
Get-VM -Name $VMName | Start-VM
}

New-LabVM -VMName 'Kirk-Core' -InstallType Core
New-LabVM -VMName 'Spock-Core' -InstallType Core
#New-LabVM -VMName 'Wesley-Full' -InstallType Full