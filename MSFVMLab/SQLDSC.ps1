#Script Parameters
param([string[]]$SqlNodes)

Configuration SQLServer{
    param([string[]] $ComputerName)

    #Part of the Microsoft DSC Resource Kit
    Import-DscResource -Module xNetworking
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

SqlServer -ComputerName $SqlNodes 
Set-DscLocalConfigurationManager -Path .\SQLServer -Verbose
Start-DscConfiguration -Path .\SQLServer -Verbose -Force -Wait