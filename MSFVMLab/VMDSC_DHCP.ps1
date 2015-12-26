configuration LabDC_DHCP{
    param(
        [string[]] $ComputerName = 'localhost'
        ,[string] $DomainName
    )

    Import-DscResource -Module xDHCPServer
    
    xDhcpServerScope DHCPScope
        {         
             Ensure = 'Present'
             IPStartRange = '10.10.10.10'
             IPEndRange = '10.10.10.250'
             Name = 'LabDomainScope'
             SubnetMask = '255.255.255.0'
             LeaseDuration = '00:24:00'
             State = 'Active'
             AddressFamily = 'IPv4'
        }

    xDhcpServerOption DHCPOption
        {
            Ensure = 'Present'
            ScopeID = '10.10.10.0'
            DnsDomain = $DomainName
            DnsServerIPAddress = '10.10.10.1'
            AddressFamily = 'IPv4'
            DependsOn = '[xDhcpServerScope]DHCPScope'
        }

}

$config = @{AllNodes = @(@{NodeName = 'localhost';PSDscAllowPlainTextPassword = $true})}

LabDC_DHCP -DomainName 'deathstar.local' -ConfigurationData $config

Start-DscConfiguration -Path .\LabDC_DHCP -Verbose -Force -Wait -debug
