function New-MSFLabImage{
[CmdletBinding()]
param([string]$ISO
     ,[string]$OutputPath
     ,[string]$ImageName
     ,[string]$Edition
     ,[string]$UnattendXML
     ,[string[]]$CustomModules
)
$ErrorActionPreference = 'Stop'

#dot source image function
. C:\git-repositories\PowerShell\Convert-WindowsImage.ps1

#Validate paths
Write-Verbose "Validating Build Paths..."
if(!(Test-Path $ISO)){Write-Error "ISO Path invalid: $ISO"}
if(!(Test-Path $OutputPath)){Write-Error "ISO Path invalid: $OutputPath"}
#if($UnattendXML -ne $null -and (Test-Path $UnattendXML) -eq $false){Write-Error "UnattendXML Path invalid: $UnattendXML"}

$OutputFile = Join-Path -Path $OutputPath -ChildPath $ImageName

#Create GM image
if(Test-Path $OutputFile){Remove-Item $OutputFile}
if($UnattendXML.Length -gt 0){
        Write-Verbose "Creating image $ImageName using $UnattendXML"
        Convert-WindowsImage -SourcePath $ISO -VHDPath $OutputFile -VHDFormat VHDX -VHDType Dynamic -Edition $Edition -VHDPartitionStyle MBR -UnattendPath $UnattendXML
    }
    else{
        Write-Verbose "Creating image $ImageName"
        Convert-WindowsImage -SourcePath $ISO -VHDPath $OutputFile -VHDFormat VHDX -VHDType Dynamic -Edition $Edition -VHDPartitionStyle MBR
    }

if($CustomModules -and (Test-Path $OutputFile)){
    Write-Verbose "Mounting $ImageName to load custome Powershell modules"
    $DriveLetter = (Mount-VHD $OutputFile –PassThru | Get-Disk | Get-Partition | Get-Volume).DriveLetter
    foreach($Module in $CustomModules){
        if(Test-Path $Module){  
        Write-Verbose "Adding $Module"  
        Copy-Item -Path $module -Destination "$DriveLetter`:\Program Files\WindowsPowershell\Modules" -Recurse
            }
        }
    Write-Verbose "Dismounting $ImageName"
    Dismount-VHD -Path $OutputFile
    }
}

$custom = @('C:\git-repositories\PowerShell\SqlConfiguration')
New-MSFLabImage -ISO 'C:\VMS\ISOs\en_windows_server_2016_technical_preview_3_x64_dvd_6942082.iso' -OutputPath 'C:\VMS\ISOs' -ImageName 'GM2016TP3.vhdx' -Edition ServerStandard -CustomModules $custom -Verbose

#$Server2016path = 'F:\VMs\ISOs\en_windows_server_2016_technical_preview_4_x64_dvd_7258292.iso'
#$Server2012path = 'F:\VMs\ISOs\en_windows_server_2012_r2_with_update_x64_dvd_6052708.iso'