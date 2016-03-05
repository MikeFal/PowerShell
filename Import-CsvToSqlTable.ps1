function Import-CsvToSqTable {
[CmdletBinding()]
param([string]$InstanceName
      ,[string]$Database
      ,[string]$SourceFile
      ,[string]$SqlDataType = 'VARCHAR(255)'
      ,[string]$StagingTableName
      ,[Switch]$Append
      )

    #Check file existince. Should be a perfmon csv
    if(-not (Test-Path $SourceFile) -and $SourceFile -notlike '*.csv'){
        Write-Error "Invalid file: $SourceFile"
    }

    $source = Get-ChildItem $SourceFile

    #Cleanup input file (Quoted Identifiers)
    Write-Verbose "[Clean Inputs]"
    (Get-Content $source).Replace('"','') | Set-Content $source
    
    #Get csv header row, create staging table for load, remove first item 'cause it's junk
    $Header = (Get-Content $source | Select-Object -First 1).Split(',')
    $CleanHeader = @()

    #Cleanup header names to be used column names
    #Remove non-alphanumeric characters
    foreach($h in $Header){
        $CleanValue = $h -Replace '[^a-zA-Z0-9_]',''
        $CleanHeader += $CleanValue
        Write-Verbose "[Cleaned Header] $h -> $CleanValue"
    }

    #Build create table statement if target table does not exist
    if(-not $Append){
        $sql = @("IF EXISTS (SELECT 1 FROM sys.tables WHERE name  = '$StagingTableName') DROP TABLE [$StagingTableName];")
    } else {
         $sql = @("IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name  = '$StagingTableName')")
    }
    $sql += ("CREATE TABLE [$StagingTableName]($($CleanHeader[0]) $SqlDataType `n")
    $CleanHeader[1..$CleanHeader.Length] | ForEach-Object {$sql += ",$_ $SqlDataType `n"}
    $sql += ");"
    Write-Verbose "[CREATE TABLE Statement] $sql"
    
    try{
        Invoke-Sqlcmd -ServerInstance $InstanceName -Database $Database -Query ($sql -join "`n")
        $cmd = "bcp '$Database.dbo.[$StagingTableName]' in '$SourceFile' -S'$InstanceName' -F2 -T -c -t','"
        Write-Verbose "[BCP Command] $cmd"
    
        $cmdout = Invoke-Expression $cmd
        if($cmdout -join '' -like '*error*'){
            throw $cmdout
        }
        Write-Verbose "[BCP Results] $cmdout"

        $rowcount = Invoke-Sqlcmd -ServerInstance $InstanceName -Database $Database -Query "SELECT COUNT(1) [RowCount] FROM [$StagingTableName];"

        $output = New-Object PSObject -Property @{'Instance'=$InstanceName;'Database'=$Database;'Table'="$StagingTableName";'RowCount'=$rowcount.RowCount}

        return $output
    }
    catch{
        Write-Error $Error[0] -ErrorAction Stop
    }
}