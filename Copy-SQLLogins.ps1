
function Copy-SqlLogins{
<#
.SYNOPSIS
   Copies logins from source server to target server.

.DESCRIPTION
   Scripts logins out from a source server using the SMO and 
   copies them to the target.  It uses the .Script() method 
   and also applies all the roles.

.PARAMETER source
   REQUIRED.  Source server that logins are gathered from.

.PARAMETER target
   Target server that logins are created on.

.Parameter logins
   Array of logins that will be created

.Parameter Script
   Switch parameter. When true, output will be SQL statement for login creation.

.EXAMPLE
   Copy-SqlLogins -source xerodb_master -target localhost
#>
  [cmdletbinding()]
  param([parameter(Mandatory=$true)][string] $source
    ,[string] $target
    ,[string[]] $logins
    ,[Switch] $Script
  )
  #create SMO objects for actions
  $smosource = new-object ('Microsoft.SqlServer.Management.Smo.Server') $source
  $smotarget = new-object ('Microsoft.SqlServer.Management.Smo.Server') $target 	
  
  #Scripting options
  $so = new-object microsoft.sqlserver.management.smo.scriptingoptions
  $so.LoginSid = $true

  #output array
  $outscript = @()
  
  #Get all SMO login objects, filtering out system, NT accounts, and including only selected logins if supplied
  if($logins){
    $matchstring = $logins -join '|'
    $loginsmo = $smosource.logins | Where-Object {$_.Name -match $logins -and $_.IsSystemObject -eq $false -and $_.Name -notlike 'NT*'}
  }
  else{
    $loginsmo = $smosource.logins | Where-Object {$_.IsSystemObject -eq $false -and $_.Name -notlike 'NT*'}
  }
  
  #Script each login and add to final output
  foreach($login in $loginsmo){
    #Filter out SMO's ALTER/DISABLE, comments about random password, and then compress into single string
    $lscript = $login.Script($so) | Where-Object {$_ -notlike 'ALTER LOGIN*DISABLE'}
    $lscript = $lscript.Replace('/* For security reasons the login is created disabled and with a random password. */','').Trim() -join "`n"
    
    #If SQL Login sort password, insert into script
    if($login.LoginType -eq 'SqlLogin'){
      
      $sql = "SELECT convert(varbinary(256),password_hash) as hashedpass FROM sys.sql_logins where name='"+$login.name+"'"
      $hashedpass = ($smosource.databases['tempdb'].ExecuteWithResults($sql)).Tables.hashedpass
      $passtring = Convert-SQLHashToString $hashedpass
      $rndpw = $lscript.Substring($lscript.IndexOf('PASSWORD'),$lscript.IndexOf(', SID')-$lscript.IndexOf('PASSWORD'))
      
      $lscript = $lscript.Replace($rndpw,"PASSWORD = $passtring hashed")
    }
    
    #Make the output nice
    $outscript += '/****************************************************'
    $outscript += "Login script for $($login.Name)"
    $outscript += '****************************************************/'
    $outscript += "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = '$($login.Name)')"
    $outscript += 'BEGIN'
    $outscript += "$lscript;"
    $outscript += 'END'
  }

  #Clean up formating
  $outscript = $outscript.Replace('WITH',"`nWITH`n`t").Replace(',',"`n`t,")

  if($Script){
    return $outscript
  }
  else{
    if($target.Length -eq 0){
        Write-Warning 'No target declared. Copy action halted'
    }
    else{
        $smotarget.Databases['tempdb'].ExecuteNonQuery($outscript)
    }
  }
}

function Convert-SQLHashToString{
  param([parameter(Mandatory=$true)] $binhash)
  
  $outstring = '0x'
  $binhash | ForEach-Object {$outstring += ('{0:X}' -f $_).PadLeft(2, '0')}
  
  return $outstring
}#Convert-SQLHashToString