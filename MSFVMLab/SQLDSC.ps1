#Script Parameters
param([string[]]$SqlNodes
     ,[PSCredential]$SetupCredential
     ,[PSCredential]$SqlSvcAccount
     ,[PSCredential]$AgtSvcAccount
     ,[string[]]$SqlAdmins)


Configuration SQLServer{
    param([string[]] $ComputerName
         ,[PSCredential]$SqlSetupCred
         ,[PSCredential]$SqlSvc
         ,[PSCredential]$AgtSvc
         ,[string[]]$SqlAdmins)

    #Part of the Microsoft DSC Resource Kit
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xSqlServer
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'

    Node $ComputerName {

        File DataDir{
            DestinationPath = 'C:\DBFiles\Data'
            Type = 'Directory'
            Ensure = 'Present'
        }

        File LogDir{
            DestinationPath = 'C:\DBFiles\Log'
            Type = 'Directory'
            Ensure = 'Present'
        }

        File TempDBDir{
            DestinationPath = 'C:\DBFiles\TempDB'
            Type = 'Directory'
            Ensure = 'Present'
        }

        WindowsFeature NETCore{
            Name = 'NET-Framework-Core'
            Ensure = 'Present'
            IncludeAllSubFeature = $true
            Source = 'D:\sources\sxs'
        }

        WindowsFeature FC{
           Name = 'Failover-Clustering'
            Ensure = 'Present'
            Source = 'D:\source\sxs'
        }

        xFirewall SQLFW{
            Name = 'SQLServer'
            DisplayName = 'SQL Server'
            Ensure = 'Present'
            Profile = 'Domain'
            Direction = 'Inbound'
            LocalPort = '1433'
            Protocol = 'TCP'
        }

        xFirewall AGFW{
            Name = 'AGEndpoint'
            DisplayName = 'Availability Group Endpoint'
            Ensure = 'Present'
            Profile = 'Domain'
            Direction = 'Inbound'
            LocalPort = '5022'
            Protocol = 'TCP'
        }
        
        xSQLServerSetup SQLInstall{
            SourcePath = 'E:\'
            SourceFolder = ''
            SetupCredential = $SqlSetupCred
            Features = 'SQLEngine,FullText'
            InstanceName = 'MSSQLSERVER'
            UpdateEnabled = '0'
            UpdateSource = 'MU'
            SqlSvcAccount = $Node.SqlSvcAccount
            AgtSvcAccount = $Node.AgtSvcAccount
            SqlSysAdminAccounts = $Node.SqlAdminAccounts
            SQLUserDBDir = 'C:\DBFiles\Data'
            SQLUserDBLogDir = 'C:\DBFiles\Log'
            SQLTempDBDir = 'C:\DBFiles\TempDB'
            SQLTempDBLogDir = 'C:\DBFiles\TempDB'
            DependsOn = @("[File]DataDir","[File]LogDir","[File]TempDBDir","[WindowsFeature]NETCore")
        }
      }
}

$config = @{
    AllNodes = @(
        foreach ($sqlNode in $SqlNodes)
        {
            @{ 
                NodeName = $sqlNode;
                PsDscAllowPlainTextPassword = $true;
                PSDscAllowDomainUser = $true;
               }
        }
    )
}

If(!(Test-Path 'C:\Temp')){New-Item -ItemType Directory 'C:\Temp'}
Set-Location 'C:\Temp'
if(Test-Path .\SQLServer){Remove-Item -Recurse .\SQLServer}

SqlServer -ComputerName $SqlNodes -SqlSetupCred $SetupCredential -SqlSvc $SqlSvcAccount -AgtSvc $AgtSvcAccount -SqlAdmins $SqlAdmins -ConfigurationData $config

Set-DscLocalConfigurationManager -Path .\SQLServer -Verbose
Start-DscConfiguration -Path .\SQLServer -Verbose -Force -Wait