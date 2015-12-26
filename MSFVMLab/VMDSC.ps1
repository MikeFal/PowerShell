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


    Node $ComputerName{
        xIPAddress SetIP
        {
            IPAddress      = '10.10.10.1'
            InterfaceAlias = $NIC
            SubnetMask     = 24
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



