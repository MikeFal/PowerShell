[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement')| Out-Null

function Set-SQLStartupParameters{
    param([string[]] $Instance
        ,[string[]] $StartupParameters
    )
    [bool]$SystemPaths = $false
    
    #Loop through and change instances
    foreach($i in $Instance){
        #Parse host and instance names
        $HostName = ($i.Split('\'))[0]
        $InstanceName = ($i.Split('\'))[1]

        #Get service account names, set service account for change
        $ServiceName = if($InstanceName){"MSSQL`$$InstanceName"}else{'MSSQLSERVER'}

        #Use wmi to change account
        $smowmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $HostName
        $wmisvc = $smowmi.Services | Where-Object {$_.Name -eq $ServiceName}

        $oldparams = $wmisvc.StartupParameters -split ';'
        $newparams = @()
        foreach($param in $StartupParameters){
            if($param.Substring(0,2) -match '-d|-e|-l'){
                $SystemPaths = $true
                $newparams += $param
                $oldparams = $oldparams | Where-Object {$_.Substring(0,2) -ne $param.Substring(0,2)}
            }
            else{
                $newparams += $param
            }
        }

        $newparams += $oldparams | Where-Object {$_.Substring(0,2) -match '-d|-e|-l'}
        $wmisvc.StartupParameters = ($newparams | Sort-Object) -join ';'
        $wmisvc.Alter()
        
        Write-Warning "Startup Parameters for $i updated. You will need to restart the service for these changes to take effect."
        If($SystemPaths){Write-Warning "You have changed the system paths for $i. Please make sure the paths are valid before restarting the service"}

    }
}