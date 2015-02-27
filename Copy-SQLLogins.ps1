function Copy-SQLLogins{
    [cmdletbinding()]
    param([parameter(Mandatory=$true)][string] $source
            ,[string] $ApplyTo
            ,[string[]] $logins
            ,[string] $outputpath=([Environment]::GetFolderPath("MyDocuments")))
#Load assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

#create initial SMO object
$smosource = new-object ('Microsoft.SqlServer.Management.Smo.Server') $source

#Make sure we script out the SID
$so = new-object microsoft.sqlserver.management.smo.scriptingoptions
$so.LoginSid = $true

#set output filename
$filename = $source.Replace('/','_') + '_' + (Get-Date -Format 'yyyyMMddHHmm') + '_logins.sql'
$outfile = Join-Path -Path $outputpath -ChildPath $filename

#If no logins explicitly declared, assume all non-system logins
if(!($logins)){
    $logins = $source.Logins.Name | Where-Object {$_.IsSystemObject -eq $false}
}

foreach($loginname in $logins){
    #get login object
    $login = $smosource.Logins[$loginname]

    #Script out the login, remove the "DISABLE" statement included by the .Script() method
    $lscript = $login.Script($so) | Where {$_ -notlike 'ALTER LOGIN*DISABLE'}
    $lscript = $lscript -join ' '

    #If SQL Login sort password, insert into script
    if($login.LoginType -eq 'SqlLogin'){
      
      $sql = "SELECT convert(varbinary(256),password_hash) as hashedpass FROM sys.sql_logins where name='"+$loginname+"'"
      $hashedpass = ($smosource.databases['tempdb'].ExecuteWithResults($sql)).Tables.hashedpass
      $passtring = ConvertTo-SQLHashString $hashedpass
      $rndpw = $lscript.Substring($lscript.IndexOf('PASSWORD'),$lscript.IndexOf(', SID')-$lscript.IndexOf('PASSWORD'))
      
      $comment = $lscript.Substring($lscript.IndexOf('/*'),$lscript.IndexOf('*/')-$lscript.IndexOf('/*')+2)
      $lscript = $lscript.Replace($comment,'')
      $lscript = $lscript.Replace($rndpw,"PASSWORD = $passtring HASHED")
    }

    #script login to out file
    $lscript | Out-File -Append -FilePath $outfile

    #if ApplyTo is specified, execute the login creation on the ApplyTo instance
    If($ApplyTo){
        $smotarget = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ApplyTo

        if(!($smotarget.logins.name -contains $loginname)){
            $smotarget.Databases['tempdb'].ExecuteNonQuery($lscript)
            $outmsg='Login ' + $login.name + ' created.'
            }
        else{            
            $outmsg='Login ' + $login.name + ' skipped, already exists on target.'
            }
        Write-Verbose $outmsg
        }
    }
}

function ConvertTo-SQLHashString{
  param([parameter(Mandatory=$true)] $binhash)
  
  $outstring = '0x'
  $binhash | ForEach-Object {$outstring += ('{0:X}' -f $_).PadLeft(2, '0')}
  
  return $outstring
}#Convert-SQLHashToString

Copy-SQLLogins -source 'localhost' -logins @('SHION\mike','test','pcuser') -ApplyTo 'SHION\ALBEDO' -Verbose