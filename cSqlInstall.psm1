<#
.SYNOPSIS
Demo DSC Resource for installing SQL Server.
.DESCRIPTION
This is a demo DSC resource based off of xSQLPS, available from Microsoft, for
installing SQL Server.  This code is expiremental and provided as is, with guarantees
expressed or implied.

Mike Fal (www.mikefal.net)
#>

#
# The Get-TargetResource cmdlet.
#
function Get-TargetResource
{
    param
    (   
        [string] $InstanceName = "MSSQLSERVER",
        
        [parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,
        [string] $configPath,
        [bool] $UpdateEnabled = $false,
        [string] $updatePath,

        [string] $Features="SQLEngine,SSMS",

        [PSCredential] $SqlAdministratorCredential,

        [string] $SvcAccount = $NULL,

        [string] $SysAdminAccounts = $NULL,
        [string] $AgentSvcAccount = $NULL
    )

    $list = Get-Service -Name MSSQL*
    $retInstanceName = $null

    if ($InstanceName -eq "MSSQLSERVER")
    {
        if ($list.Name -contains "MSSQLSERVER")
        {
            $retInstanceName = $InstanceName
        }
    }
    elseif ($list.Name -contains $("MSSQL$" + $InstanceName))
    {
        Write-Verbose -Message "SQL Instance $InstanceName is present"
        $retInstanceName = $InstanceName
    }


    $returnValue = @{
        InstanceName = $retInstanceName
    }

    return $returnValue
}


#
# The Set-TargetResource cmdlet.
#
function Set-TargetResource
{
    param
    (   
        [string] $InstanceName = "MSSQLSERVER",
        
        [parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,
        [string] $configPath,
        [bool] $UpdateEnabled = $false,
        [string] $updatePath,

        [string] $Features="SQLEngine,SSMS",

        [PSCredential] $SqlAdministratorCredential,

        [string] $SvcAccount = $NULL,

        [string] $SysAdminAccounts = $NULL,
        [string] $AgentSvcAccount = $NULL
    )
    $LogPath = Join-Path $env:SystemDrive -ChildPath "Logs"

    if (!(Test-Path $LogPath))
    {
        New-Item $LogPath -ItemType Directory
    }
    # SQL log from setup cmdline run output
    $logFile = Join-Path $LogPath -ChildPath "sqlInstall-log.txt"
    
    # SQL installer path       
    $cmd = Join-Path $SourcePath -ChildPath "Setup.exe"

    # TCPENABLED- Specifies the state of the TCP protocol for the SQL Server service. 
    # NPENABLED- Specifies the state of the Named Pipes protocol for the SQL Server service
    # tcp/ip and named pipes protocol needs to be enabled for web apps to access db instances. So these are being enabled as a part of default sql server installation
    if($configPath){
      $cmd += " /Q /IndicateProgress /CONFIGURATIONFILE=$updatePath "
    }
    else{
      $cmd += " /Q /ACTION=Install /IACCEPTSQLSERVERLICENSETERMS /IndicateProgress "
      $cmd += "/FEATURES=$Features /INSTANCENAME=$InstanceName /TCPENABLED=1 /NPENABLED=1 "
    }
    
    if ($SqlAdministratorCredential)
    {
        $saPwd = $SqlAdministratorCredential.GetNetworkCredential().Password
        $cmd += "/SECURITYMODE=SQL /SAPWD=$saPwd "
    }
    
    if ($UpdateEnabled)
    {
        $cmd += " /updateEnabled=true /UpdateSource=$updatePath "
    }
    
    if ($SysAdminAccounts)
    {
        $cmd += " /SQLSYSADMINACCOUNTS=$SysAdminAccounts "
    }
    
    if ($SvcAccount)
    {
        $cmd += " /SQLSVCACCOUNT=$SvcAccount "
    }
    
    if ($AgentSvcAccount)
    {    
        $cmd += " /AGTSVCACCOUNT=$AgentSvcAccount "
    }
    
    $cmd += " > $logFile 2>&1 "

    if($SourcePathCredential){
      NetUse -SharePath $SourcePath -SharePathCredential $SourcePathCredential -Ensure "Present"
    }

    try
    {
        Invoke-Expression $cmd
    }
    finally
    {
        NetUse -SharePath $SourcePath -SharePathCredential $SourcePathCredential -Ensure "Absent"
    }
    # Check the SQL logs for installation status.
    $installStatus = $false
    try
    {        
        # SQL Server log folder
        $sqlLogFile = Get-ChildItem $env:ProgramFiles -Recurse | Where-Object {$_.FullName -like '*Setup Bootstrap\Log*' -and $_.Name -eq 'summary.txt'} | Sort-Object LastWriteTime -desc | Select-Object -first 1      
        $sqlLog = Get-Content $sqlLogFile
        if($sqlLog -ne $null)
        {
            $message = $sqlLog | Format-List
            if($message -ne $null)
            {
                # sample report when the install is succesful
                #    Overall summary:
                #    Final result:                  Passed
                #    Exit code (Decimal):           0
                $finalResult = $message[1] | Out-String     
                $exitCode = $message[2] | Out-String    

                if(($finalResult.Contains("Passed") -eq $True) -and ($exitCode.Contains("0") -eq $True))
                {                     
                    $installStatus = $true
                }                
             }
        }
    }
    catch
    {
        Write-Verbose "SQL Installation did not succeed."
    }
    if($installStatus -eq $true)
    {
        # Tell the DSC Engine to restart the machine
        $global:DSCMachineStatus = 1
    }
    else    
    {        
        # Throw an error message indicating failure to install SQL Server install 
        $errorId = "InValidSQLServerInstall";
        $exceptionStr = "SQL Server installation did not succeed. For more details please refer to the logs under $LogPath folder."
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidResult;
        $exception = New-Object System.InvalidOperationException $exceptionStr; 
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord);
     }
}
#
# The Test-TargetResource cmdlet.
#
function Test-TargetResource
{
    param
    (   
        [string] $InstanceName = "MSSQLSERVER",
        
        [parameter(Mandatory)] 
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,
        [string] $configPath,
        [bool] $UpdateEnabled = $false,
        [string] $updatePath,

        [string] $Features="SQLEngine,SSMS",

        [PSCredential] $SqlAdministratorCredential,

        [string] $SvcAccount = $NULL,

        [string] $SysAdminAccounts = $NULL,
        [string] $AgentSvcAccount = $NULL
    )

    $info = Get-TargetResource -InstanceName $InstanceName -SourcePath $SourcePath -SqlAdministratorCredential $SqlAdministratorCredential
    
    return ($info.InstanceName -eq $InstanceName)
}



function NetUse
{
    param
    (   
        [parameter(Mandatory)] 
        [string] $SharePath,
        
        [PSCredential]$SharePathCredential,
        
        [string] $Ensure = "Present"
    )

    if ($null -eq $SharePathCredential)
    {
        return;
    }

    Write-Verbose -Message "NetUse set share $SharePath ..."

    if ($Ensure -eq "Absent")
    {
        $cmd = "net use $SharePath /DELETE"
    }
    else 
    {
        $cred = $SharePathCredential.GetNetworkCredential()
        $pwd = $cred.Password 
        $user = $cred.Domain + "\" + $cred.UserName
        $cmd = "net use $SharePath $pwd /user:$user"
    }

    Invoke-Expression $cmd
}

