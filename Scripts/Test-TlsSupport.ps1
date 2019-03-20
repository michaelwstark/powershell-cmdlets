
<#
.Synopsis
   This script can be used to automate testing of TLS version support
.DESCRIPTION
   This script will take in a list of servers line delimited file and test each one for TLS support.

   Author: Michael Stark (mstark) - Universal Store - Store Core - Payments
.PARAMETER DependencyManifest
    A file which lists the set of origins to test
.EXAMPLE
   ./Test-TlsSupport.ps1 -DependencyManifest MyDependencies.txt
#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [string] $DependencyManifest
)

Enum ProtocolStatus
{
    DnsLookupFailed
    HostDidNotRespond
    Supported
    NotSupported
}

Class HostTlsSupportResult
{
    [string]           $HostName
    [UInt16]           $Port
    [ProtocolStatus]   $Ssl2  = [ProtocolStatus]::HostDidNotRespond
    [ProtocolStatus]   $Ssl3  = [ProtocolStatus]::HostDidNotRespond
    [ProtocolStatus]   $Tls10 = [ProtocolStatus]::HostDidNotRespond
    [ProtocolStatus]   $Tls11 = [ProtocolStatus]::HostDidNotRespond
    [ProtocolStatus]   $Tls12 = [ProtocolStatus]::HostDidNotRespond
}

Function Get-Color
{
    Param
    (
        [ProtocolStatus] $Status
    )

    Switch ($Status)
    {
        DnsLookupFailed
        {
            Return "Yellow"
        }
        HostDidNotRespond
        {
            Return "Yellow"
        }
        Supported
        {
            Return "Green"
        }
        NotSupported
        {
            Return "Red"
        }
    }
}

Function Test-ServerTlsSupport
{
    Param
    (
        [string] $HostName,
        [UInt16] $Port = 443
    )

    [HostTlsSupportResult] $Result = New-Object HostTlsSupportResult
    $Result.HostName = $HostName
    $Result.Port = $Port

    # Check to make sure that the hostname resolves correctly
    $DnsRecords = @( Resolve-DnsName -Name $HostName -ErrorAction SilentlyContinue )
    If (($DnsRecords -eq $Null) -or $DnsRecords.Count -eq 0)
    {
        $Result.Ssl2 = [ProtocolStatus]::DnsLookupFailed
        $Result.Ssl3 = [ProtocolStatus]::DnsLookupFailed
        $Result.Tls10 = [ProtocolStatus]::DnsLookupFailed
        $Result.Tls11 = [ProtocolStatus]::DnsLookupFailed
        $Result.Tls12 = [ProtocolStatus]::DnsLookupFailed

        Return $Result
    }

    Try
    {
        # This will test if the server will allow us to open a connect
        $TcpClient = New-Object Net.Sockets.TcpClient
        $TcpClient.SendTimeout = 1000
        $TcpClient.ReceiveTimeout = 1000
        $TcpClient.Connect($HostName, $Port)

        $TlsVersions = @( 'ssl2', 'ssl3', 'tls', 'tls11', 'tls12' )
        
        ForEach ($TlsVersion in $TlsVersions)
        {
            Try
            {
                $TcpClient = New-Object Net.Sockets.TcpClient
                $TcpClient.SendTimeout = 1000
                $TcpClient.ReceiveTimeout = 1000
                $TcpClient.Connect($HostName, $Port)
                $SslStream = New-Object Net.Security.SslStream $TcpClient.GetStream()
                $SslStream.ReadTimeout = 1000
                $SslStream.WriteTimeout = 1000

                # (Host, ClientCertificates, SslProtocols, CheckCertificateRevocation)
                $SslStream.AuthenticateAsClient($HostName, $null, $TlsVersion, $False)
                $Status = [ProtocolStatus]::Supported
            }
            Catch
            {
                $Status = [ProtocolStatus]::NotSupported
            }
            Finally
            {
                If($TcpClient -ne $Null) { $TcpClient.Dispose() }
                If($SslStream -ne $Null) { $SslStream.Dispose() }
            }

            Switch ($TlsVersion)
            {
                'ssl2'
                {
                    $Result.Ssl2 = $Status
                }
                'ssl3'
                {
                    $Result.Ssl3 = $Status
                }
                'tls'
                {
                    $Result.Tls10 = $Status
                }
                'tls11'
                {
                    $Result.Tls11 = $Status
                }
                'tls12'
                {
                    $Result.Tls12 = $Status
                }
            }
        }
    }
    Catch
    {
        $Result.Ssl2 = [ProtocolStatus]::HostDidNotRespond
        $Result.Ssl3 = [ProtocolStatus]::HostDidNotRespond
        $Result.Tls10 = [ProtocolStatus]::HostDidNotRespond
        $Result.Tls11 = [ProtocolStatus]::HostDidNotRespond
        $Result.Tls12 = [ProtocolStatus]::HostDidNotRespond
    }
    Finally
    {
        If($TcpClient -ne $Null) { $TcpClient.Dispose() }
        If($SslStream -ne $Null) { $SslStream.Dispose() }
    }

    Return $Result
}

If (-not (Test-Path -LiteralPath $DependencyManifest))
{
    Write-Warning "Could not locate manifest: $DependencyManifest"
    Write-Host
    Write-Host
    Write-Host 'Sad Times.'
    Exit 1
}

$ServiceHosts = @(Get-Content -LiteralPath $DependencyManifest)

ForEach ($ServiceHost in $ServiceHosts)
{
    If ([string]::IsNullOrWhiteSpace($ServiceHost))
    {
        Continue
    }

    [HostTlsSupportResult] $TlsSupport = Test-ServerTlsSupport -HostName $ServiceHost -Port 443

    Write-Host
    Write-Host
    Write-Host '*****************************************************************************'
    Write-Host "** $($TlsSupport.HostName)"
    Write-Host '*****************************************************************************'

    Write-Host -NoNewLine -Object 'SSL 2:   '
    Write-Host $TlsSupport.Ssl2 -ForegroundColor $(Get-Color -Status $TlsSupport.Ssl2)

    Write-Host -NoNewLine -Object 'SSL 3:   '
    Write-Host $TlsSupport.Ssl3 -ForegroundColor $(Get-Color -Status $TlsSupport.Ssl3)

    Write-Host -NoNewLine -Object 'TLS 1.0: '
    Write-Host $TlsSupport.Tls10 -ForegroundColor $(Get-Color -Status $TlsSupport.Tls10)

    Write-Host -NoNewLine -Object 'TLS 1.1: '
    Write-Host $TlsSupport.Tls11 -ForegroundColor $(Get-Color -Status $TlsSupport.Tls11)

    Write-Host -NoNewLine -Object 'TLS 1.2: '
    Write-Host $TlsSupport.Tls12 -ForegroundColor $(Get-Color -Status $TlsSupport.Tls12)
}