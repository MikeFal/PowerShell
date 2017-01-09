<#
Borrowed and modified from Russell Young (https://russellyoung.net/2016/06/18/managing-documentdb-with-powershell/)

#>

Add-Type -AssemblyName System.Web

#Helper function, internal
function New-Header{
    param([string]$action = "get"
         ,[string]$resType
         ,[string]$resourceId
         ,[string]$connectionKey)
    
    $apiDate = (Get-Date).ToUniversalTime().ToString('R')

    #Build Authorization
    $keyBytes = [System.Convert]::FromBase64String($connectionKey) 
    $text = @($action.ToLowerInvariant() + `
                "`n" + $resType.ToLowerInvariant() + `
                "`n" + $resourceId + `
                "`n" + $apiDate.ToLowerInvariant() + "`n" + "`n")

    $body  =[Text.Encoding]::UTF8.GetBytes($text)
    $hmacsha = new-object -TypeName System.Security.Cryptography.HMACSHA256 -ArgumentList (,$keyBytes) 
    $hash = $hmacsha.ComputeHash($body)
    $signature = [System.Convert]::ToBase64String($hash)
    $authz = [System.Web.HttpUtility]::UrlEncode($('type=master&ver=1.0&sig=' + $signature))

    #construct header
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $authz)
    $headers.Add("x-ms-version", '2015-12-16')
    $headers.Add("x-ms-date", $apiDate) 
    return $headers
}

#DocDB Database Functions (Get/New/Remove)
function Get-DocDBDatabase {
    param([string] $rooturi
          ,[string] $key
          ,[string ]$dbname 
          )
     
    if($dbname){
        $resourceid = "dbs/$dbname"
        $uri = $rootUri + '/' + $resourceid
        $headers = New-Header -resType dbs -resourceId $resourceid -action Get -connectionKey $key 
    } else {
        $resourceid = "dbs"
        $uri = $rootUri + '/' + $resourceid
        $headers = New-Header -resType dbs -action Get -connectionKey $key 
    }   

    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

    return $response
}

function New-DocDBDatabase{
    param([string] $rooturi
          ,[string] $key
          ,[string ]$dbname)

    $uri = $rootUri + '/dbs'
    $headers = New-Header -resType dbs -action Post -connectionKey $key
    $body = "{
        `"id`": `"$dbname`"
    }"
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    return $response
}

function Remove-DocDBDatabase {
    param([string] $rooturi
          ,[string] $key
          ,[string]$dbname 
          )

    $resourceid = "dbs/$dbname"
    $uri =   $rootUri + '/' + $resourceid
    $headers = New-Header -resType dbs -resourceId $resourceid -action Delete -connectionKey $key 

    $response = Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers
    return $response
}

#DocDB Collection Functions (Get/New/Remove)
function Get-DocDBCollection{
    param([string] $rooturi
            ,[string] $key
            ,[string ]$dbname
            ,[string] $collection
    )

    if($collection){
        $resourceid = "dbs/$dbname/colls/$collection"
        $uri = $rootUri + '/' + $resourceid
    } else {
        $resourceid = "dbs/$dbname"
        $uri = $rootUri + '/' + $resourceid + '/colls'
    }
    $headers = New-Header -resType colls -resourceId $resourceid -action Get -connectionKey $key
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -Body $body 
    return $response
}

function New-DocDBCollection{
    param([string] $rooturi
          ,[string] $key
          ,[string ]$dbname
          ,[string] $collection
          #,[ValidateSet('S1','S2','S3')][string]$offer
    )

    $uri = $rootUri + "/dbs/$dbname/colls"
    $headers = New-Header -resType colls -resourceId "dbs/$dbname" -action Post -connectionKey $key

    $body = "{
        `"id`": `"$collection`"
    }"
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    return $response
}

function Remove-DocDBCollection{
    param([string] $rooturi
            ,[string] $key
            ,[string ]$dbname
            ,[string] $collection
    )

    $resourceid = "dbs/$dbname/colls/$collection"
    $uri = $rootUri + '/' + $resourceid

    $headers = New-Header -resType colls -resourceId $resourceid -action Delete -connectionKey $key
    $response = Invoke-RestMethod -Uri $uri -Method Delete -Headers $headers -Body $body 
    return $response
}

#DocDB Document Functions (Get/New/Remove)
function Get-DocDBDocument{
    param([string] $rooturi
          ,[string] $key
          ,[string ]$dbname
          ,[string] $collection
          ,[string] $id)
    
    $resourceid = "dbs/$dbname/colls/$collection"

    if($id){
        $headers = New-Header -action Get -resType docs -resourceId "$resourceid/docs/$id" -connectionKey $key
        $uri = $rootUri + "/$resourceid/docs/$id"
    } else {        
        $headers = New-Header -action Get -resType docs -resourceId $resourceid -connectionKey $key
        $uri = $rootUri + "/$resourceid/docs"
    }
    $response = Invoke-RestMethod $uri -Method Get -ContentType 'application/json' -Headers $headers
    return $response
}


function New-DocDBDocument{
    param([string]$document
          ,[string] $rooturi
          ,[string] $key
          ,[string ]$dbname
          ,[string] $collection)
    $collName = "dbs/"+$dbname+"/colls/" + $collection
    $headers = New-Header -action Post -resType docs -resourceId $collName -connectionKey $key
    $headers.Add("x-ms-documentdb-is-upsert", "true")

    $uri = $rootUri + "/" + $collName + "/docs"
    
    $response = Invoke-RestMethod $uri -Method Post -Body $document -ContentType 'application/json' -Headers $headers
    return $response
}

function Remove-DocDBDocuments{
    param([string] $rooturi
          ,[string] $key
          ,[string ]$dbname
          ,[string] $collection
          ,[string] $id )

    if($id){
        $docs = Get-DocDBDocument -rooturi $rooturi -key $key -dbname $dbname -collection $collection -id $id        
    } else {
        $docs = Get-DocDBDocument -rooturi $rooturi -key $key -dbname $dbname -collection $collection 
    }
    $response = @()
    foreach($doc in $docs.documents){
        $resourceid = "dbs/$dbname/colls/$collection/docs/$($doc.id)"
        $headers = New-Header -action Delete -resType docs -resourceId $resourceid -connectionKey $key
        $uri = $rootUri + "/$resourceid"
        $response += Invoke-RestMethod $uri -Method Delete -Headers $headers
    }

    return $response
}

#WIP for adding stored procedure. Currently not working
function Add-DocDBStoredProcedure{
    param([string] $rooturi
          ,[string] $key
          ,[string ]$dbname
          ,[string] $collection
          ,[string] $storedprocedure
          )
    $collName = "dbs/"+$dbname+"/colls/" + $collection
    $headers = New-Header -action Post -resType sprocs -resourceId $collName -connectionKey $key

    $uri = $rootUri + "/" + $collName + "/sprocs"
    
    $response = Invoke-RestMethod $uri -Method Post -Body $storedprocedure -ContentType 'application/json' -Headers $headers
    return $response
}

#Invoke functions
function Invoke-DocDbQuery{
    param([string]$query
          ,[string] $rooturi
          ,[string] $key
          ,[string ]$dbname
          ,[string] $collection)
    $collName = "dbs/"+$dbname+"/colls/" + $collection
    $headers = New-Header -action Post -resType docs -resourceId $collName -connectionKey $key
    $headers.Add("x-ms-documentdb-isquery", "true")
    $headers.Add("Content-Type", "application/query+json")
    $queryjson = "{
        `"query`": `"$query`"
    }"
    $uri = $rootUri + "/" + $collName + "/docs"
    
    $response = Invoke-RestMethod $uri -Method Post -Body $queryjson -Headers $headers
    return $response
}

function Invoke-DocDbStoredProcedure{
    param([string] $rooturi
          ,[string] $key
          ,[string ]$dbname
          ,[string] $collection
          ,[string]$sproc
          ,[string]$params)
    $resourceid = "dbs/$dbname/colls/$collection/sprocs/$sproc"
    $headers = New-Header -action Post -resType sprocs -resourceId $resourceid -connectionKey $key

    $uri = $rooturi + "/$resourceid"
    if($params){
        $response = Invoke-RestMethod $uri -Method Post -Body $params -Headers $headers
    } else {
         $response = Invoke-RestMethod $uri -Method Post -Headers $headers
    }

    return $response
}
