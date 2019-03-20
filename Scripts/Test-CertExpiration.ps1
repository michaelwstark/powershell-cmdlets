
<#
.Synopsis
   This script will scan for any *.cer files and check their expiration in a file system.
.DESCRIPTION
   This script will take in a literal path and use it to scan and verify the exiration of *.cer files under it.

   Author: Michael Stark (mstark) - Universal Store - Store Core - Payments
.PARAMETER DependencyManifest
    A file which lists the set of origins to test
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

    [switch] $ReportAll = $false
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
            Return "Yellow"
        }
        NotNearExpiration
        {
            Return "Green"
        }
        Expired
        {
            Return "Red"
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

$CertificateFiles = Get-ChildItem -LiteralPath $LiteralPath -Filter *.cer -Recurse
$CertificateFiles = $CertificateFiles | Where-Object { -not ($_.FullName.Contains('\bin\') -or $_.FullName.Contains('\obj\')) }

ForEach ($CertificateFile in $CertificateFiles)
{
    $DaysUntilExpiration = Get-DaysUntilExpiration -CertificatePath $CertificateFile.FullName

    $Status = [ExpirationStatus]::NotNearExpiration
    If (0 -ge $DaysUntilExpiration)
    {
        $Status = [ExpirationStatus]::Expired
    }
    ElseIf ($NearExpirationLimitInDays -ge $DaysUntilExpiration)
    {
        $Status = [ExpirationStatus]::NearExpiration
    }

    If((-not $ReportAll) -and $Status -eq [ExpirationStatus]::NotNearExpiration)
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