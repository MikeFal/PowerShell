#This is a comment
function Get-FileVolume{
    param([string]$PathName)

    $check = $PathName.Substring(0,$PathName.LastIndexOf('\')+1)

    $volumes = (gwmi win32_volume| where {$_.drivetype -eq 3}|select name|out-string -stream).Trim()
    if($volumes -contains $check){
        
        return gwmi win32_volume| where {$_.name -eq $check}
    }
    else{
        return Get-FileVolume $check.Substring(0,$check.Length-1)

    }
}

Get-FileVolume 'U:\ag07\RaiseTicket\RaiseTicket.mdf'