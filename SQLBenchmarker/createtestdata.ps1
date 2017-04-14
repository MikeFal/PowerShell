$json = (Get-Content .\dss_test1.js) -join "`n" | ConvertFrom-Json

for($i=2;$i -le 10;$i++){
    $jsonout = $json
    $jsonout.entries.patient.dssID = "T$i"
    $jsonout.entries.patient.firstName = "DSS $i"
    $jsonout.entries.patient.lastName = 'Test'
    $jsonout.entries.patient.email = "dsstest$i@gmail.com"
    $jsonout.entries.plans.primary.dssID = "T$i"
    $jsonout.entries.orders.dssID = "T$i"
    $jsonout.entries.recalls.dssID = Get-Random -Minimum 100000 -Maximum 999999

    $jsonout | ConvertTo-Json -depth 10 | Out-File "dss_test$i.js"

}