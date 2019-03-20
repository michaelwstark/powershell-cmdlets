<#
.Synopsis
   The following script encrypts a blob of text with the public key of a certificate.
.DESCRIPTION
   This script encrypts the specified text with the specified certificate.  It is assumed that the certificate is installed in the local machine's store.
.PARAMETER CertificateThumbprint
    The thumbprint of the certificate.
.PARAMETER TextToEncrypt
    The text to encrypt with the specified certificate.
.EXAMPLE
   ./Encrypt-Text.ps1 -Thumbprint '77f44649324189f915e249f235168df48578510d' -Text 'jBtPTcKFWvrO0fWKkKRHAlPBPmev/9HbacS7FxrBVxE='
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$CertificateThumbprint,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$TextToEncrypt
)

Write-Host
Write-Host '####################################################################################################################'
Write-Host '## Encrypt-Text'
Write-Host "## CertificateThumbprint: $CertificateThumbprint"
Write-Host "## TextToEncrypt:         $TextToEncrypt"
Write-Host '####################################################################################################################'
Write-Host

################################
## Find the Certificate
################################

Write-Host 'Searching LocalMachine Personal Certs...'
$Certificate = Get-Item "cert:\LocalMachine\My\$CertificateThumbprint" -ErrorAction Stop

Write-Host 'Encrypting Text...'
$TextBytes = [System.Text.Encoding]::UTF8.GetBytes($TextToEncrypt)
$EncryptedBlob = $Certificate.PublicKey.Key.Encrypt($TextBytes, $True)
$EncryptedText = [System.Convert]::ToBase64String($EncryptedBlob)

Write-Host
Write-Host 'Encrypted Text:'
Write-Output $EncryptedText

Write-Host
Write-Host 'Happy Day.'

Exit 0