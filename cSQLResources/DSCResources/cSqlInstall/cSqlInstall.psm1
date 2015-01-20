function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$InstanceName = 'MSSQLSERVER',

		[parameter(Mandatory = $true)]
		[System.String]
		$InstallPath = $null,

		[parameter(Mandatory = $true)]
		[System.String]
		$ConfigPath = $null

	)

	$CheckName = $null
    
    if($InstanceName -eq 'MSSQLSERVER'){
        $CheckName = $InstanceName
    }
    else{
        $CheckName = 'MSSQL$' + $InstanceName
    }

    $SvcCheck = Get-Service
    if(!($SvcCheck.Name.Contains($CheckName))){
         $CheckName = $null
    }

    if(!(Test-Path $InstallPath)){
        $InstallPath = $null
    }

    if(!(Test-Path $ConfigPath)){
        $ConfigPath = $null
    }
    
	
	$returnValue = @{
		InstanceName = $CheckName;
        InstallPath = $InstallPath;
        ConfigPath = $ConfigPath;
	}

	return $returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$InstanceName,

		[parameter(Mandatory = $true)]
		[System.String]
		$InstallPath,

		[parameter(Mandatory = $true)]
		[System.String]
		$ConfigPath,

		[System.Boolean]
		$UpdateEnabled,

		[System.String]
		$UpdatePath,

        [System.Boolean]
        $MixedMode = $false
	)
    try{    
        if(!(Test-Path $InstallPath)){
            Write-Verbose "Invalid Installation Path $InstallPath.  Halting configuration."
            return
        }
    
        Write-Verbose "Installation Path validated."
    
        if(!(Test-Path $ConfigPath)){
            Write-Verbose "Invalid Configuration Path $ConfigPath.  Halting configuration."
            return
        }
    
        Write-Verbose "Configuration Path validated."
    
        $installcmd = Join-Path -Path $InstallPath -ChildPath 'setup.exe'
        $installcmd += " /QUIET /INDICATEPROGRESS=TRUE /INSTANCENAME=$InstanceName /INSTANCEID=$InstanceName  /CONFIGURATIONFILE=$ConfigPath"

        if($UpdateEnabled){
            if(!(Test-Path $UpdatePath)){
                Write-Verbose "Invalid Update Path $UpdatePath.  Halting configuration."
                return
            }
            Write-Verbose "Update Path validated"
            $installcmd += " /UPDATEENABLED=TRUE /UPDATESOURCE=$UpdatePath"
        }

        if($MixedMode){
            [Reflection.Assembly]::LoadWithPartialName(“System.Web”)
            $SAPassword = [System.Web.Security.Membership]::GeneratePassword(16,4)
            $installcmd += " /SECURITYMODE=SQL /SAPWD=`'$SAPassword`'"
        }

        $installcmd += " /IACCEPTSQLSERVERLICENSETERMS"

        Write-Verbose "Attempting install with: `n $installcmd"
        Invoke-Expression $installcmd

        $log =  Get-ChildItem 'C:\Program Files\Microsoft SQL Server' -Recurse | Where-Object {$_.FullName -like '*Setup Bootstrap*' -and $_.Name -eq 'Summary.txt'} |Sort-Object -Property LastWriteTime -Descending|Select-Object -First 1
        $InstallCheck = ($log |Get-Content |Select-Object -Skip 1 -First 1).Contains('Passed')

        if(!($InstallCheck)){
            throw 'Installation Unsuccessful'
        }

        'Installation successful, restarting server.' >> $log
        $global:DSCMachineStatus = 1
    }
    catch{
        Write-Verbose 'SQL Server Installation failed.'
    }
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$InstanceName,

		[parameter(Mandatory = $true)]
		[System.String]
		$InstallPath,

		[parameter(Mandatory = $true)]
		[System.String]
		$ConfigPath,

		[System.Boolean]
		$UpdateEnabled,

		[System.String]
		$UpdatePath,

        [System.Boolean]
        $MixedMode = $false
	)

    $check = Get-TargetResource -InstanceName $InstanceName -InstallPath $InstallPath -ConfigPath $ConfigPath

    $returnvalue = ($check.InstanceName -eq $InstanceName)
    Write-Verbose "Test-Target Resource will return $returnvalue."
    return ($check.InstanceName -eq $InstanceName)

}


Export-ModuleMember -Function *-TargetResource

