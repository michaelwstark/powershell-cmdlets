<#
.Synopsis
   This script will scan for any *.cer files and check their expiration in a file system.
.DESCRIPTION
   This script will take in a literal path and use it to scan and verify the expiration of *.cer files under it.

   Author: Michael Stark (mstark)
.PARAMETER LiteralPath
    The root path to scan recursively for *.cer files.  Files under \bin\ or \obj\ are skipped.
.PARAMETER NearExpirationLimitInDays
    Threshold in days under which a certificate is reported as near-expiration (default 45).
.PARAMETER ReportAll
    When set, also report certificates that are not near expiration.
.EXAMPLE
   ./Test-CertExpiration.ps1 -LiteralPath E:\Repos
#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [string] $LiteralPath,

    [ValidateRange(1, 365)]
    [int] $NearExpirationLimitInDays = 45,

    [switch] $ReportAll
)

Enum ExpirationStatus
{
    NotNearExpiration
    NearExpiration
    Expired
}

Function Get-Color
{
    Param
    (
        [ExpirationStatus] $Status
    )

    Switch ($Status)
    {
        NearExpiration
        {
            Return 'Yellow'
        }
        NotNearExpiration
        {
            Return 'Green'
        }
        Expired
        {
            Return 'Red'
        }
    }
}

Function Get-DaysUntilExpiration
{
    Param
    (
        [string] $CertificatePath
    )

    $Certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2 $CertificatePath
    $TimeUntilExpire = New-TimeSpan -Start (Get-Date) -End $Certificate.NotAfter
    Return [Math]::Round($TimeUntilExpire.TotalDays)
}

If (-not (Test-Path -LiteralPath $LiteralPath))
{
    Write-Warning "Could not locate path: $LiteralPath"
    Write-Host
    Write-Host
    Write-Host 'Sad Times.'
    Exit 1
}

$CertificateFiles = Get-ChildItem -LiteralPath $LiteralPath -Filter '*.cer' -Recurse
$CertificateFiles = $CertificateFiles | Where-Object { -not ($_.FullName.Contains('\bin\') -or $_.FullName.Contains('\obj\')) }

ForEach ($CertificateFile in $CertificateFiles)
{
    $DaysUntilExpiration = Get-DaysUntilExpiration -CertificatePath $CertificateFile.FullName

    $Status = [ExpirationStatus]::NotNearExpiration
    If ($DaysUntilExpiration -le 0)
    {
        $Status = [ExpirationStatus]::Expired
    }
    ElseIf ($DaysUntilExpiration -le $NearExpirationLimitInDays)
    {
        $Status = [ExpirationStatus]::NearExpiration
    }

    If ((-not $ReportAll) -and $Status -eq [ExpirationStatus]::NotNearExpiration)
    {
        Continue
    }

    Write-Host "Certificate: $($CertificateFile.FullName)"
    Write-Host "Days Until Expire: $DaysUntilExpiration" -ForegroundColor (Get-Color -Status $Status)
    Write-Host
}

Write-Host
Write-Host 'Done.'
Write-Host 'Happy Day.'