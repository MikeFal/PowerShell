#Script Parameters
param([string]$DName
      ,[System.Management.Automation.PSCredential]$DCred
     )

configuration LabDC{
    param(
        [string[]] $ComputerName = 'localhost'
        ,[string] $NIC = 'Ethernet 2'
        ,[string] $DomainName
        ,[System.Management.Automation.PSCredential] $DomainCred

    )

    Import-DscResource –Module PSDesiredStateConfiguration
    Import-DscResource -Module xComputerManagement 
    Import-DscResource -Module xActiveDirectory 
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xDHCPServer

    $SafePassword = $DomainCred.GetNetworkCredential().Password

    Node $ComputerName{
        xIPAddress SetIP
        {
            IPAddress      = '10.10.10.1'
            InterfaceAlias = $NIC
            PrefixLength     = 24
            AddressFamily  = 'IPV4'
 
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
            IncludeAllSubFeature = $true
        }

        WindowsFeature DHCPInstall
        { 
            Ensure = 'Present'
            Name = 'DHCP'
            IncludeAllSubFeature = $true
        }

        WindowsFeature RSATADInstall
        { 
            Ensure = 'Present'
            Name = 'RSAT-AD-Tools'
            IncludeAllSubFeature = $true
        }

        WindowsFeature RSATDHCPInstall
        { 
            Ensure = 'Present'
            Name = 'RSAT-DHCP'
            IncludeAllSubFeature = $true
        }

        WindowsFeature RSATDNSInstall
        { 
            Ensure = 'Present'
            Name = 'RSAT-DNS-Server'
            IncludeAllSubFeature = $true
        }

        xADDomain SetupDomain {
            DomainAdministratorCredential= $DomainCred
            DomainName= $DomainName
            SafemodeAdministratorPassword= $DomainCred
            DomainNetbiosName = $DomainName.Split('.')[0]
            DependsOn='[WindowsFeature]ADDSInstall'
            DatabasePath = 'C:\NTDS'
            LogPath = 'C:\NTDS'
        }
    }
}

If(!(Test-Path 'C:\Temp')){New-Item -ItemType Directory 'C:\Temp'}
Set-Location 'C:\Temp'

$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
            RebootNodeIfNeeded = $true
        }
    )
}

$NICInterface = (Get-netadapter -interfaceindex (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.DNSdomain -ne 'mshome.net' -and $_.description -like '*Hyper-V*'}).Interfaceindex).Name
if(Test-Path .\LabDC){Remove-Item -Recurse .\LabDC}
labdc -ComputerName 'localhost' -DomainName $DName -DomainCred $DCred -NIC $NICInterface -ConfigurationData $config

Set-DscLocalConfigurationManager -Path .\LabDC -Verbose
Start-DscConfiguration -Path .\LabDC -Verbose -Force -Wait