param([ValidateSet('Dev','Stage','QA','Prod')][string] $Environment)

# Load the IntegrationServices Assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices") | Out-Null;


#Set ISPAC path based on envinronment
$IspacPath = switch($Environment){
    'Dev'{'C:\TFS2013\Dev\SSIS\TestDev.ispac'}
    'Stage'{'C:\TFS2013\Dev\SSIS\TestStage.ispac'}
    'QA'{'C:\TFS2013\Dev\SSIS\TestQA.ispac'}
    'Prod'{'C:\TFS2013\Dev\SSIS\TestProd.ispac'}
}

#Set Server and Report Server Name based on envinronment
$Server = switch($Environment){
    'Dev'{'TestDev'}
    'Stage'{'TestStage'}
    'QA'{'TestQA'}
    'Prod'{'TestProd'}
}

#------------------------Project Information BEGIN------------------------------
Write-Host "Connecting to server ..."
# Create a connection to the server
# Server name variable
$sqlConnectionString = "Data Source=$Server ;Initial Catalog=master;Integrated Security=SSPI;"
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection $sqlConnectionString

# Create the Integration Services object
$integrationServices = New-Object Microsoft.SqlServer.Management.IntegrationServices.IntegrationServices $sqlConnection
$catalog = $integrationServices.Catalogs["SSISDB"]

#------------------------Project Information END---------------------------
Write-Host "SSIS folder $FolderName already exists; skipping create"
Write-Host "Deploying " $ProjectName " project ..."
$folder = $catalog.Folders[$FolderName]
$project = $folder.Projects[$ProjectName]

# Removes Read Only on .ispac
#---------------------------------------------------------------------------------
Set-ItemProperty $IspacPath -IsReadOnly $false
#---------------------------------------------------------------------------------
# Read the project file, and deploy it to the folder
#------------------------ Ispac Path ------------------------------------------
# Ispac Variable - #.ispac file path must change for each branch
#---------------------------------------------------------------------------------
[byte[]] $projectFile = [System.IO.File]::ReadAllBytes($IspacPath_TestDev )
#---------------------------------------------------------------------------------
$folder.DeployProject($ProjectName, $projectFile)
Write-Host $project.Name "was deployed with"
Write-Host "Description: " $project.Description
Write-Host "ProjectID: " $project.ProjectID
Write-Host "All done."