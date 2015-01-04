#load assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null

function Out-DataTable 
{ 
    [CmdletBinding()] 
    param([Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [PSObject[]]$InputObject) 
 
    Begin 
    { 
        $dt = new-object Data.datatable   
        $First = $true  
    } 
    Process 
    { 
        foreach ($object in $InputObject) 
        { 
            $DR = $DT.NewRow()   
            foreach($property in $object.PsObject.get_properties()) 
            {   
                if ($first) 
                {   
                    $Col =  new-object Data.DataColumn   
                    $Col.ColumnName = $property.Name.ToString()   
                    if ($property.value) 
                    { 
                        if ($property.value -isnot [System.DBNull]) 
                        { $Col.DataType = $property.value.gettype() } 
                    } 
                    $DT.Columns.Add($Col) 
                }   
                if ($property.IsArray) 
                { $DR.Item($property.Name) =$property.value | ConvertTo-XML -AS String -NoTypeInformation -Depth 1 }   
                else { $DR.Item($property.Name) = $property.value }   
            }   
            $DT.Rows.Add($DR)   
            $First = $false 
        } 
    }  
      
    End 
    { 
        Write-Output @(,($dt)) 
    } 
 
} #Out-DataTable
$ErrorActionPreference = "Inquire"

function Out-DataTable 
{ 
    [CmdletBinding()] 
    param([Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [PSObject[]]$InputObject) 
 
    Begin 
    { 
        $dt = new-object Data.datatable   
        $First = $true  
    } 
    Process 
    { 
        foreach ($object in $InputObject) 
        { 
            $DR = $DT.NewRow()   
            foreach($property in $object.PsObject.get_properties()) 
            {   
                if ($first) 
                {   
                    $Col =  new-object Data.DataColumn   
                    $Col.ColumnName = $property.Name.ToString()   
                    if ($property.value) 
                    { 
                        if ($property.value -isnot [System.DBNull]) 
                        { $Col.DataType = $property.value.gettype() } 
                    } 
                    $DT.Columns.Add($Col) 
                }   
                if ($property.IsArray) 
                { $DR.Item($property.Name) =$property.value | ConvertTo-XML -AS String -NoTypeInformation -Depth 1 }   
                else { $DR.Item($property.Name) = $property.value }   
            }   
            $DT.Rows.Add($DR)   
            $First = $false 
        } 
    }  
      
    End 
    { 
        Write-Output @(,($dt)) 
    } 
 
} #Out-DataTable

function Get-Instance([string]$name)
{ 
try
{
	$smo = new-object ('Microsoft.SqlServer.Management.Smo.Server') $name
	$sname = $smo.NetName
	$iname = $smo.InstanceName
	if($iname.Length -eq 0 -or $iname -eq $null) { $iname = "MSSQLSERVER" }

	$managedcomp = new-object ('Microsoft.SqlServer.Management.Smo.WMI.ManagedComputer') $sname
	$output = New-Object System.Object

	$port = $managedcomp.ServerInstances[$iname].ServerProtocols["Tcp"].IPAddresses["IPAll"].IPAddressProperties["TcpPort"].Value
	$ip = (Test-Connection $sname -count 1).IPV4Address.ToString()
    
    $output | Add-Member -type NoteProperty -name InstanceName -Value $iname
	$output | Add-Member -type NoteProperty -name SQLVersion -value $smo.VersionString
	$output | Add-Member -type NoteProperty -name SQLVersionDesc -value $smo.ProductLevel
	$output | Add-Member -type NoteProperty -name SQLEdition -value $smo.Edition
	$output | Add-Member -type NoteProperty -name MemoryMinMB -value $smo.Configuration.MinServerMemory.RunValue
	$output | Add-Member -type NoteProperty -name MemoryMaxMB -value $smo.Configuration.MaxServerMemory.RunValue
	$output | Add-Member -type NoteProperty -name MAXDOPVal -value $smo.Configuration.MaxDegreeOfParallelism.RunValue
	$output | Add-Member -type NoteProperty -name IP -value $ip
	$output | Add-Member -type NoteProperty -name Port -value $port
	$output | Add-Member -type NoteProperty -name ServerName -value $smo.ComputerNamePhysicalNetBIOS
	return $output
}
catch
{
	write-host "Error collecting $name"
	return $null
}
}#Get-Instance

#Get host machine information via WMI
function Get-Server([string]$name)
{
 try{
	$comp = gwmi Win32_ComputerSystem -Computer $name | select Model,Manufacturer,TotalPhysicalMemory
	$proc = gwmi Win32_Processor -Computer $name | select NumberOfLogicalProcessors,MaxClockSpeed
	$os = gwmi Win32_OperatingSystem -Computer $name | select OSArchitecture,Name,Version,ServicePackMajorVersion,ServicePackMinorVersion 

	$output = New-Object System.Object

	$output | Add-Member -type NoteProperty -name ServerName -value $name
	$output | Add-Member -type NoteProperty -name Model -value $comp.Model
	$output | Add-Member -type NoteProperty -name Manufacturer -value $comp.Manufacturer
	$output | Add-Member -type NoteProperty -name Architechture -value $os.OSArchitecture
	$output | Add-Member -type NoteProperty -name PhysicalCPUs -value $(if(!$proc.Length){"1"}else{$proc.Length})
	$output | Add-Member -type NoteProperty -name LogicalCPUs -value ($proc | Measure-Object NumberOfLogicalProcessors -sum).Sum
	$output | Add-Member -type NoteProperty -name CPUSpeed -value ($proc | Measure-Object MaxClockSpeed -max).Maximum
	$output | Add-Member -type NoteProperty -name MaxMemory -value ($comp.TotalPhysicalMemory/1MB)
	$output | Add-Member -type NoteProperty -name OSName -value $os.name.split("|")[0]
	$output | Add-Member -type NoteProperty -name OsVersion -value $os.Version
	$SPMaj = $os.ServicePackMajorVersion
	$SPMin = $os.ServicePackMinorVersion
	$output | Add-Member -type NoteProperty -name SPVersion -value "$SPMaj.$SPMin"

	return $output
}
catch{
	write-error "Error collecting $name"
	return $null
} 
}#Get-Server

#Bulk load data into destination table
function Load-Data($dt,$cxn,$desttbl)
{
    $cxn.Open()
    $bulkloader = new-object("Data.SqlClient.SqlBulkCopy") $cxn
    $bulkloader.DestinationTableName=$desttbl
    $bulkloader.WriteToServer($dt)
    $cxn.Close()
}#Load-Data


function Get-SQLInventory{
   param([string] $invserv = "localhost",
	[string] $invdb = "MSFADMIN",
    [parameter(Mandatory=$true)][string[]] $invlist)

    $smoadmin = new-object ('Microsoft.SqlServer.Management.Smo.Server') $invserv
    $prepquery = "delete from dataload.InstanceLoad;
    delete from dataload.MachineLoad;"

    $smoadmin.Databases[$invdb].ExecuteNonQuery($prepquery)

    #init reporting collections
    $instances = @()
    $servers = @()

    foreach($inv in $invlist){
        $newinst = $null
        $newinst = Get-Instance $inv
	    if($newinst -ne $null) {
            $instances += $newinst

                if($servers.ServerName -notcontains $newinst.ServerName){
                    
                    $servers += Get-Server $newinst.ServerName
            }
        }
    }

    $instload = $instances | select ServerName,InstanceName,sqlversion,sqlversiondesc,sqledition,IP,Port,memoryminmb,memorymaxmb,maxdopval | out-datatable
    $srvload = $servers | select ServerName,Model,Manufacturer,Architechture,PhysicalCPUs,LogicalCPUs,CPUSpeed,MaxMemory,OSName,OSVersion,SPVersion | out-datatable

    $conn = New-Object system.data.sqlclient.sqlconnection("Data Source=$invserv;Initial Catalog=$invdb;Trusted_Connection=True;")


    Load-Data $instload $conn "dataload.InstanceLoad"
    Load-Data $srvload $conn "dataload.MachineLoad" 

    $smoadmin.Databases[$invdb].ExecuteNonQuery('execute dbo.dbasp_ProcessInventory;')
}

Get-SQLInventory -invlist @('localhost','localhost\ALBEDO')


