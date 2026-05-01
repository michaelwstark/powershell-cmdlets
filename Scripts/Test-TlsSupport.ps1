<#
.Synopsis
   This script can be used to automate testing of TLS version support.
.DESCRIPTION
   This script takes a line-delimited file of hostnames and tests each one for which TLS versions the server accepts.

   Author: Michael Stark (mstark)
.PARAMETER DependencyManifest
    A file which lists the set of hosts to test, one per line.
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
    [ProtocolStatus]   $Tls10 = [ProtocolStatus]::HostDidNotRespond
    [ProtocolStatus]   $Tls11 = [ProtocolStatus]::HostDidNotRespond
    [ProtocolStatus]   $Tls12 = [ProtocolStatus]::HostDidNotRespond
    [ProtocolStatus]   $Tls13 = [ProtocolStatus]::HostDidNotRespond
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
            Return 'Yellow'
        }
        HostDidNotRespond
        {
            Return 'Yellow'
        }
        Supported
        {
            Return 'Green'
        }
        NotSupported
        {
            Return 'Red'
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
        $Result.Tls10 = [ProtocolStatus]::DnsLookupFailed
        $Result.Tls11 = [ProtocolStatus]::DnsLookupFailed
        $Result.Tls12 = [ProtocolStatus]::DnsLookupFailed
        $Result.Tls13 = [ProtocolStatus]::DnsLookupFailed

        Return $Result
    }

    Try
    {
        # This will test if the server will allow us to open a connect
        $TcpClient = New-Object Net.Sockets.TcpClient
        $TcpClient.SendTimeout = 1000
        $TcpClient.ReceiveTimeout = 1000
        $TcpClient.Connect($HostName, $Port)

        $TlsVersions = @( 'tls', 'tls11', 'tls12', 'tls13' )

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
                $SslStream.AuthenticateAsClient($HostName, $Null, $TlsVersion, $False)
                $Status = [ProtocolStatus]::Supported
            }
            Catch
            {
                $Status = [ProtocolStatus]::NotSupported
            }
            Finally
            {
                If ($TcpClient -ne $Null) { $TcpClient.Dispose() }
                If ($SslStream -ne $Null) { $SslStream.Dispose() }
            }

            Switch ($TlsVersion)
            {
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
                'tls13'
                {
                    $Result.Tls13 = $Status
                }
            }
        }
    }
    Catch
    {
        $Result.Tls10 = [ProtocolStatus]::HostDidNotRespond
        $Result.Tls11 = [ProtocolStatus]::HostDidNotRespond
        $Result.Tls12 = [ProtocolStatus]::HostDidNotRespond
        $Result.Tls13 = [ProtocolStatus]::HostDidNotRespond
    }
    Finally
    {
        If ($TcpClient -ne $Null) { $TcpClient.Dispose() }
        If ($SslStream -ne $Null) { $SslStream.Dispose() }
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

    Write-Host -NoNewLine -Object 'TLS 1.0: '
    Write-Host $TlsSupport.Tls10 -ForegroundColor $(Get-Color -Status $TlsSupport.Tls10)

    Write-Host -NoNewLine -Object 'TLS 1.1: '
    Write-Host $TlsSupport.Tls11 -ForegroundColor $(Get-Color -Status $TlsSupport.Tls11)

    Write-Host -NoNewLine -Object 'TLS 1.2: '
    Write-Host $TlsSupport.Tls12 -ForegroundColor $(Get-Color -Status $TlsSupport.Tls12)

    Write-Host -NoNewLine -Object 'TLS 1.3: '
    Write-Host $TlsSupport.Tls13 -ForegroundColor $(Get-Color -Status $TlsSupport.Tls13)
}