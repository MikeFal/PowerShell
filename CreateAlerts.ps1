$alerts = (Get-Content C:\Users\Mike\Documents\UpSearch\Alerts.json) -join "`n" | ConvertFrom-Json
$sql = @()
foreach($alert in $alerts){
$sql += @"
EXEC msdb.dbo.sp_add_alert @name=N'$($alert.Name)', 
		@message_id=$($alert.MessageID), 
		@severity=$($alert.Severity), 
		@enabled=1, 
		@delay_between_responses=60, 
		@include_event_description_in=1, 
		@category_name=N'[Uncategorized]';
"@
}

Invoke-Sqlcmd -ServerInstance localhost -Database msdb -Query ($sql -join "`n")

$txt = @"
Name|MessageID|Severity
Error Number 823 Read/Write Failure|823|0
Error Number 824 Page Error|824|0
Error Number 825 Read-Retry Required|825|0
Severity 019|0|19
Severity 020|0|20
Severity 021|0|21
Severity 022|0|22
Severity 023|0|23
Severity 024|0|24
Severity 025|0|25
"@

$txt | ConvertFrom-Csv -Delimiter '|' | ConvertTo-Json | Out-File C:\Users\Mike\Documents\UpSearch\Alerts.json