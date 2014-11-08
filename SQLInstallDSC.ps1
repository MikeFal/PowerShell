Configuration SQLServer{
    param([string[]] $ComputerName)

    Import-DscResource -Module cSQLResources

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
        
        cSQLInstall SQLInstall{
            InstanceName = 'MSSQLSERVER'
            InstallPath = '\\HIKARU\InstallFiles\SQL2014'
            ConfigPath = '\\HIKARU\InstallFiles\SQL2014\SQL2014_Core_DSC.ini'
            UpdateEnabled = $true
            UpdatePath = '\\HIKARU\InstallFiles\SQL2014\Updates'
            DependsOn = @("[File]DataDir","[File]LogDir","[File]TempDBDir","[WindowsFeature]NETCore")
        }
    }
}

SQLServer -ComputerName MISA