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
        
        Write-Verbose "[$(Get-Date -Format 'HH:mm:ss')]$VMName complete."
        return $NewVM
    }
    catch{
        Write-Error $Error[0]
        return
    }
}

function Remove-LabVM{
    param([string]$VMName)

    $CurrVM = Get-VM -Name $VMName

    if($CurrVM.State -eq 'Running'){
        $CurrVM | Stop-VM
    }

    foreach($vhd in $CurrVM.HardDrives.Path){
        if(Test-Path $vhd){
            Remove-Item -Path $vhd -force
        }
    }
    
    Remove-VM -Name $VMName -Force

    if(Test-Path $CurrVM.ConfigurationLocation){
        Remove-Item -Path $CurrVM.ConfigurationLocation -Recurse -Force
    }

    if(Test-Path $CurrVM.SnapshotFileLocation){
        Remove-Item -Path $CurrVM.ConfigurationLocation -Recurse -Force
    }

    if(Test-Path $CurrVM.Path){
        Remove-Item -Path $CurrVM.ConfigurationLocation -Recurse -Force
    }
}