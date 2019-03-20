# Get the Drives on the Computer
$Drives = Get-PSDrive | Where-Object { $_.Provider.Name -eq "FileSystem" } | Sort-Object -Property Root

# Iterate Over the Drives To See Where the 'Repos' Folder is.  Select first one found.
ForEach ($Drive in $Drives)
{
    $TestReposRoot = Join-Path $Drive.Root 'Repos'
    If(Test-Path -LiteralPath $TestReposRoot)
    {
        $ReposRoot = $TestReposRoot
        Break
    }
}

# Add any variable overrides here.  Not all are honored.  If what you want to specify isn't ... add it.  :-)
# Example
# $WebPaymentsFrontEndRepoFolderName = WebPaymentsFrontEnd

$ProfileScriptPath = Join-Path  $ReposRoot 'powershell-cmdlets\Scripts\ProfileCmdlets.ps1'
. $ProfileScriptPath