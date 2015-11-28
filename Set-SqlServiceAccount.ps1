#HT http://blogs.technet.com/b/heyscriptingguy/archive/2010/11/03/use-powershell-to-change-sql-server-s-service-accounts.aspx
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement')| Out-Null
function Set-SqlServiceAccount{
    param([string] $Instance
        ,[System.Management.Automation.PSCredential]$ServiceAccount
        ,[ValidateSet('SqlServer','SqlAgent')] $Service = 'SqlServer'
    )
    
    #Get Service Account name from credential object
    $account =$ServiceAccount.GetNetworkCredential().Domain +'\'+ $ServiceAccount.GetNetworkCredential().UserName
    
    #Parse host and instance names
    $HostName = ($instance.Split('\'))[0]
    $InstanceName = ($instance.Split('\'))[1]

    #Get service account names, set service account for change
    $sqlsvc = if($InstanceName){"MSSQL`$$InstanceName"}else{'MSSQLSERVER'}
    $agtsvc = if($InstanceName){"SQLAGENT`$$InstanceName"}else{'SQLSERVERAGENT'}

    $ServiceName = switch($service){
        'SqlServer'{$sqlsvc}
        'SqlAgent'{$agtsvc}
    }

    #Use wmi to change account
    $smowmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $HostName
    $wmisvc = $smowmi.Services | Where-Object {$_.Name -eq $ServiceName}
    $wmisvc.SetServiceAccount($account,$ServiceAccount.GetNetworkCredential().Password)
    
    #If Agent service isn't running (happens if you reset SQL Service), start it
    $wmiagt = $smowmi.Services | Where-Object {$_.Name -eq $agtsvc}
    if($wmiagt.ServiceSatus -ne 'Running'){$wmiagt.Start()}      

}


<#
$cred = Get-Credential 'Enter Service Account'
Set-SqlServiceAccount -Instance PICARD -ServiceAccount $cred -Service SqlServer
#>