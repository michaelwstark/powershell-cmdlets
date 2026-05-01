# Get the Drives on the Computer
$Drives = Get-PSDrive | Where-Object { $_.Provider.Name -eq 'FileSystem' } | Sort-Object -Property Root

# Iterate Over the Drives To See Where the 'Repos' Folder is.  Select first one found.
ForEach ($Drive in $Drives)
{
    $TestReposRoot = Join-Path $Drive.Root 'Repos'
    If (Test-Path -LiteralPath $TestReposRoot)
    {
        $ReposRoot = $TestReposRoot
        Break
    }
}

# Variables honored by ProfileCmdlets.ps1 if set before dot-sourcing:
#   $PoshGitRepoFolderName  - override the posh-git folder name (default 'posh-git')
#   $DefaultRepo            - alias of the repo to Set-Location into on startup

# Default repo to navigate to on shell startup (alias name from ProfileCmdlets.ps1).
# $DefaultRepo = 'devcenter'

# Set to $True to print per-section profile-load timings on shell start.
# $ShowProfileTimings = $True

$ProfileScriptPath = Join-Path $ReposRoot 'powershell-cmdlets\Scripts\ProfileCmdlets.ps1'
. $ProfileScriptPath