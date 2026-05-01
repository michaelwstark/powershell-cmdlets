<#
.Synopsis
   A set of PowerShell cmdlets for common day-to-day source-control and dev tasks.
.DESCRIPTION
   Helper cmdlets and aliases for working across multiple repos.  Feel free to take parts or the whole.

   Load via your PowerShell profile, e.g.:

     $ProfileScriptPath = Join-Path $ReposRoot 'powershell-cmdlets\Scripts\ProfileCmdlets.ps1'
     . $ProfileScriptPath

   Optional dependencies:
     - posh-git (auto-cloned under your 'Repos' folder if missing)
     - GitHub CLI (gh) for New-PullRequest against GitHub repos
     - Azure CLI with the azure-devops extension for New-PullRequest against Azure DevOps repos

   Author: Michael Stark (mstark)
#>

#########################################################
## Helper Cmdlets
#########################################################

Function Test-AbsolutePath {
  Param
  (
    [Parameter(Mandatory = $True)]
    [String]$Path
  )

  [System.IO.Path]::IsPathRooted($Path)
}

Function Restore-Project {
  dotnet restore
}

Function Build-Project {
  dotnet build
}

Function Clean-Project {
  dotnet clean
}

Function Rebuild-Project {
  Clean-Project
  Build-Project
}

Function Purge-Repository {
  git.exe clean -xfd -e node_modules -e */.vs/ -e **/db.lock -e **/storage.ide*
}

Function Checkout-Branch {
  Param
  (
    [string]$Branch = ''
  )

  If ([string]::IsNullOrWhiteSpace($Branch)) {
    $Branch = Read-Host 'Branch: '
  }

  git.exe checkout $Branch
  git.exe submodule update --recursive
}

Function Merge-Branch {
  Param
  (
    [string]$SourceBranch = ''
  )

  If ([string]::IsNullOrWhiteSpace($SourceBranch)) {
    git.exe mergetool
  }
  Else {
    git.exe merge $SourceBranch
  }
}

Function Prune-Branches {
  Param
  (
    [switch] $Destructive
  )

  git.exe checkout (Get-DefaultBranch)
  git.exe fetch -p

  $GoneBranches = git.exe branch --list --format '%(if:equals=[gone])%(upstream:track)%(then)%(refname:short)%(end)' | Where-Object { $_ -ne '' }

  If ($Destructive) {
    $GoneBranches | ForEach-Object { git.exe branch -D $_ }
  }
  Else {
    $GoneBranches | ForEach-Object { git.exe branch -d $_ }
  }
}

Function Navigate-Root {
  $Location = Get-Location

  ForEach ($Entry in $Global:RepoRoots.GetEnumerator()) {
    If ($Location.Path.StartsWith($Entry.Value.Path, 'CurrentCultureIgnoreCase')) {
      pushd $Entry.Value.Path
      Return
    }
  }

  Throw 'Current Location is Not Under a Known Repo.'
}

Function Find-Repo {
  $Location = Get-Location

  ForEach ($Entry in $Global:RepoRoots.GetEnumerator()) {
    If ($Location.Path.StartsWith($Entry.Value.Path, 'CurrentCultureIgnoreCase')) {
      Return $Entry.Value.RepoName
    }
  }

  Throw 'Current Location is Not Under a Known Repo.'
}

Function Navigate-Product {
  Navigate-Root
  pushd 'Product'
}

Function Commit-Change {
  Param
  (
    [string]$Message = ''
  )

  If ([string]::IsNullOrWhiteSpace($Message)) {
    git.exe commit
  }
  Else {
    git.exe commit -m "$Message"
  }
}

Function Push-Repository {
  git.exe push
}

Function Pull-Repository {
  git.exe pull
}

Function Get-DefaultBranch {
  $DefaultRef = git.exe symbolic-ref refs/remotes/origin/HEAD 2>$Null
  If ($DefaultRef) {
    Return ($DefaultRef -replace '^refs/remotes/origin/', '')
  }
  Return 'main'
}

Function Get-GitRemoteHost {
  $RemoteUrl = git.exe remote get-url origin 2>$Null
  If ([string]::IsNullOrWhiteSpace($RemoteUrl)) {
    Return $Null
  }

  If ($RemoteUrl -match 'github\.com') {
    Return 'github'
  }

  If ($RemoteUrl -match 'dev\.azure\.com|visualstudio\.com') {
    Return 'azuredevops'
  }

  Return $Null
}

Function Get-AzureDevOpsOrg {
  $RemoteUrl = git.exe remote get-url origin 2>$Null
  If ([string]::IsNullOrWhiteSpace($RemoteUrl)) {
    Return $Null
  }

  # https://[user@]dev.azure.com/{org}/...
  If ($RemoteUrl -match 'https://(?:[^/@]+@)?dev\.azure\.com/([^/]+)/') {
    Return $Matches[1]
  }

  # https://[user@]{org}.visualstudio.com/...
  If ($RemoteUrl -match 'https://(?:[^/@]+@)?([^.]+)\.visualstudio\.com/') {
    Return $Matches[1]
  }

  # git@ssh.dev.azure.com:v3/{org}/...
  If ($RemoteUrl -match 'ssh\.dev\.azure\.com[:/]v3/([^/]+)/') {
    Return $Matches[1]
  }

  Return $Null
}

Function New-PullRequest {
  Param
  (
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [string]   $Title,

    [string]   $Description,

    [string]   $TargetBranch,

    [string[]] $Reviewers = @()
  )

  If ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = $Title
  }

  If ([string]::IsNullOrWhiteSpace($TargetBranch)) {
    $TargetBranch = Get-DefaultBranch
  }

  Switch (Get-GitRemoteHost) {
    'github' {
      If (-not (Get-Command 'gh' -ErrorAction SilentlyContinue)) {
        Write-Error 'GitHub CLI (gh) not found.  Install from https://cli.github.com.'
        Return
      }
      $GhArgs = @(
        'pr', 'create',
        '--title', $Title,
        '--body', $Description,
        '--base', $TargetBranch,
        '--web'
      )
      If ($Reviewers.Count -gt 0) {
        $GhArgs += '--reviewer'
        $GhArgs += ($Reviewers -join ',')
      }
      & gh @GhArgs
    }
    'azuredevops' {
      If (-not (Get-Command 'az' -ErrorAction SilentlyContinue)) {
        Write-Error 'Azure CLI (az) not found.  Install from https://aka.ms/azcli and add the azure-devops extension: az extension add --name azure-devops'
        Return
      }
      $AzArgs = @(
        'repos', 'pr', 'create',
        '--title', $Title,
        '--description', $Description,
        '--target-branch', $TargetBranch,
        '--open'
      )
      If ($Reviewers.Count -gt 0) {
        $AzArgs += '--reviewers'
        $AzArgs += $Reviewers
      }
      & az @AzArgs
    }
    Default {
      Write-Error 'Could not determine remote host (expected GitHub or Azure DevOps).  Run from inside a repo with a recognized origin remote.'
    }
  }
}

Function NuGet-Push {
  Param
  (
    [ValidateNotNullOrEmpty()]
    [string]$Package,

    [ValidateNotNullOrEmpty()]
    [string]$Feed = 'DevTestLab'
  )

  $Org = Get-AzureDevOpsOrg
  If ([string]::IsNullOrWhiteSpace($Org)) {
    Write-Error 'Could not determine Azure DevOps organization from git remote.  Run from inside a repo with an ADO origin remote.'
    Return
  }

  $CurrentLocation = Get-Location
  $PackageLocation = $Package

  If (-not (Test-AbsolutePath -Path $PackageLocation)) {
    $PackageLocation = Join-Path $CurrentLocation $PackageLocation
  }

  If (-not (Test-Path -LiteralPath $PackageLocation)) {
    Write-Error 'Package specified does not exist.'
    Return
  }

  $Url = "https://pkgs.dev.azure.com/$Org/_packaging/$Feed/nuget/v3/index.json"

  Navigate-Root

  & .\NuGet\NuGet.exe push "$PackageLocation" -Source "$Url" -ApiKey VSTS

  popd
}

Function Reformat-Json {
  $JsonFiles = Get-ChildItem -Recurse '*.json'

  ForEach ($JsonFile in $JsonFiles) {
    Write-Host "Reformatting: $($JsonFile.FullName)"

    $Json = Get-Content -Raw -LiteralPath $JsonFile.FullName
    $Object = ConvertFrom-Json $Json
    $Json = ConvertTo-Json $Object -Depth 100
    [System.IO.File]::WriteAllText($JsonFile.FullName, $Json, [System.Text.Encoding]::UTF8)
  }
}

Function Kill-Edge {
  Param
  (
    [ValidateSet('', 'Fire')]
    [String] $With = ''
  )

  Kill-Process -Name msedge -With $With
  Kill-Process -Name msedgewebview2 -With $With
}

Function Kill-Process {
  Param
  (
    [ValidateNotNullOrEmpty()]
    [String] $Name,

    [ValidateSet('', 'Fire')]
    [String] $With = ''
  )

  $Processes = Get-Process -Name $Name -ErrorAction SilentlyContinue
  If ($Processes -ne $Null) {
    If ($With -eq 'Fire') {
      $BottomEdges = "^" * ((42 - $Name.Length) / 2)
      $BottomLine = "  $BottomEdges -$Name- $BottomEdges"
      Write-Host
      Write-Host "
               (  .      )
           )           (              )
                 .  '   .   '  .  '  .
        (    , )       (.   )  (   ',    )
         .' ) ( . )    ,  ( ,     )   ( .
      ). , ( .   (  ) ( , ')  .' (  ,    )
     (_,) . ), ) _) _,')  (, ) '. )  ,. (' )
$BottomLine" -ForegroundColor DarkRed
      Stop-Process -ProcessName $Name -Force
    }
    Else {
      Stop-Process -ProcessName $Name
    }
  }
}

Function Print-Object {
  Param
  (
    [ValidateNotNull()]
    [object] $Object
  )

  # PowerShell ConvertTo-Json adds a "value" tag with the entire serialized content
  # of the object.  Remove it -- it is hard on the eyes and redundant.
  $Json = ConvertTo-Json $Object -Depth 100
  $Json = $Json -replace "`"value`":  `"@{.*}`",", ""

  # Remove blank lines
  $JsonLines = $Json -split '[\r\n]' | Where-Object { -not ( [string]::IsNullOrWhiteSpace($_) ) }
  $Json = $JsonLines -join "`r`n"

  # Best Effort Whitespace compresson.
  # Convert tabs to spaces, then sub two-for-one
  $Json = $Json -replace "    ", " "
  $Json = $Json -replace "  ", " "

  Write-Host $Json
}

Function Reload-Profile {
  @(
    $Profile.AllUsersAllHosts,
    $Profile.AllUsersCurrentHost,
    $Profile.CurrentUserAllHosts,
    $Profile.CurrentUserCurrentHost
  ) | ForEach-Object {
    If (Test-Path -LiteralPath $_) {
      Write-Verbose "Running $_"
      . $_
    }
  }
}

#########################################################
## Aliases
#########################################################

Set-Alias Restore Restore-Project
Set-Alias Build Build-Project
Set-Alias Clean Clean-Project
Set-Alias Rebuild Rebuild-Project
Set-Alias Purge Purge-Repository
Set-Alias Merge Merge-Branch
Set-Alias Checkout Checkout-Branch
Set-Alias Commit Commit-Change
Set-Alias Push Push-Repository
Set-Alias Pull Pull-Repository
Set-Alias Root Navigate-Root
Set-Alias NuGetPush NuGet-Push
Set-Alias Reload Reload-Profile
Set-Alias Print Print-Object
Set-Alias PR New-PullRequest

#########################################################
## Environment Initialization
#########################################################

#########################################################
## Profile-load timing instrumentation (temporary).
## Set $ShowProfileTimings = $True in profile.ps1 (before
## dot-sourcing this file) to print per-section timings.
#########################################################
$ProfileSw = If ($ShowProfileTimings) { [System.Diagnostics.Stopwatch]::StartNew() }
$ProfileTotalSw = If ($ShowProfileTimings) { [System.Diagnostics.Stopwatch]::StartNew() }

Function Write-ProfileTiming {
  Param([string] $Section)

  If ($ProfileSw) {
    Write-Host ('  [{0,5:F0} ms] {1}' -f $ProfileSw.Elapsed.TotalMilliseconds, $Section) -ForegroundColor DarkGray
    $ProfileSw.Restart()
  }
}

#########################################################
## Test that git.exe is in the PATH.
#########################################################
$GitAvailable = $False
If ((Get-Command 'git.exe' -ErrorAction SilentlyContinue) -eq $Null) {
  Write-Warning 'Could not locate git.exe.  Please resolve or ensure git.exe is in your PATH.'
}
Else {
  $GitAvailable = $True
}
Write-ProfileTiming 'git.exe PATH check'

#########################################################
## Test that dotnet.exe is in the PATH.
#########################################################
If ((Get-Command 'dotnet.exe' -ErrorAction SilentlyContinue) -eq $Null) {
  Write-Warning 'Could not locate dotnet.exe.  Please resolve or ensure dotnet.exe is in your PATH.'
}
Write-ProfileTiming 'dotnet.exe PATH check'

#########################################################
## Initialize Repos Path and Import Posh-Git
#########################################################
If ($ReposRoot -eq $Null) {
  # Get the Drives on the Computer
  $Drives = Get-PSDrive | Where-Object { $_.Provider.Name -eq 'FileSystem' } | Sort-Object -Property Root

  # Iterate Over the Drives To See Where the 'Repos' Folder is
  ForEach ($Drive in $Drives) {
    $TestReposRoot = Join-Path $Drive.Root 'Repos'
    If (Test-Path -LiteralPath $TestReposRoot) {
      $ReposRoot = $TestReposRoot
      Break
    }
  }
  Write-ProfileTiming '$ReposRoot drive scan'
}

# If we found a root set our repo locations
If ($ReposRoot -ne $Null) {
  If ([string]::IsNullOrWhiteSpace($PoshGitRepoFolderName)) {
    $PoshGitRepoFolderName = 'posh-git'
  }

  $PoshGitRoot = Join-Path $ReposRoot $PoshGitRepoFolderName

  # Folder name -> alias/repo-name overrides for repos with custom navigation aliases.
  # RepoName is what Find-Repo returns; treat it as the canonical repo identifier
  # (typically the GitHub or Azure DevOps repo name, which may differ from the folder name).
  $RepoAliasOverrides = @{
    'powershell-cmdlets'  = @{ Alias = 'Scripts';   RepoName = 'powershell-cmdlets' }
    'azure-devcenter'     = @{ Alias = 'devcenter'; RepoName = 'azure-devcenter' }
    'mxc'                 = @{ Alias = 'mxc';       RepoName = 'mxc' }
    'W365A-Sandbox'       = @{ Alias = 'lithium';   RepoName = 'W365A-Sandbox' }
  }

  $Global:RepoRoots = @{}

  Get-ChildItem -Path $ReposRoot -Directory |
    Where-Object { $_.Name -ne $PoshGitRepoFolderName } |
    ForEach-Object {
      $FolderName = $_.Name
      $RepoPath   = $_.FullName

      If ($RepoAliasOverrides.ContainsKey($FolderName)) {
        $Override  = $RepoAliasOverrides[$FolderName]
        $Alias     = $Override.Alias
        $RepoName  = $Override.RepoName
      } Else {
        $Alias    = $FolderName
        $RepoName = $FolderName
      }

      $Global:RepoRoots[$Alias] = @{ Path = $RepoPath; RepoName = $RepoName }

      $ScriptBlock = { pushd $RepoPath }.GetNewClosure()
      Set-Item -Path "function:global:Navigate-$Alias" -Value $ScriptBlock
      Set-Alias -Name $Alias -Value "Navigate-$Alias" -Scope Global
    }

  Write-ProfileTiming 'Repo enumeration / dynamic alias creation'

  $AvailableAliases = ($Global:RepoRoots.Keys | Sort-Object) -join ', '

  If ([string]::IsNullOrWhiteSpace($DefaultRepo)) {
    Write-Warning "No `$DefaultRepo set.  Set `$DefaultRepo in your profile.ps1 for a better experience.  Available repos: $AvailableAliases"
    Set-Location $ReposRoot
  }
  ElseIf ($Global:RepoRoots.ContainsKey($DefaultRepo)) {
    Set-Location $Global:RepoRoots[$DefaultRepo].Path
  }
  Else {
    Write-Warning "`$DefaultRepo '$DefaultRepo' is not a known repo alias.  Available repos: $AvailableAliases"
    Set-Location $ReposRoot
  }

  Write-ProfileTiming '$DefaultRepo Set-Location'

  #Load PoshGit
  $PoshGitModule = Join-Path $PoshGitRoot src
  $PoshGitModule = Join-Path $PoshGitModule 'posh-git.psd1'

  # Clone the posh-git repo if it isn't already local.
  $IsPoshGitCloned = Test-Path -LiteralPath $PoshGitModule
  If (-not ($IsPoshGitCloned) -and $GitAvailable) {
    pushd $ReposRoot
    git.exe clone 'https://github.com/dahlbyk/posh-git.git'
    $IsPoshGitCloned = $True
    popd
    Write-ProfileTiming 'posh-git clone'
  }

  If ($IsPoshGitCloned) {
    Import-Module $PoshGitModule

    # This is a personal preference.  I can remove and put in my profile file if desired.
    # Try it out first though.
    If ($Env:USERNAME -eq 'mstark') {
      $GitPromptSettings.DefaultPromptSuffix = '`n$(''>'' * ($nestedPromptLevel + 1)) '
    }
    Write-ProfileTiming 'posh-git Import-Module + prompt setup'
  }
  Else {
    Write-Warning 'Could not find posh-git repo location.  Clone https://github.com/dahlbyk/posh-git.git into your Repos folder.'
  }
}
Else {
  Write-Warning 'Could not locate the root of the git repos.  Repo navigation related functions will not work.'
}

If ($ProfileTotalSw) {
  Write-Host ('  [{0,5:F0} ms] TOTAL (ProfileCmdlets.ps1)' -f $ProfileTotalSw.Elapsed.TotalMilliseconds) -ForegroundColor Cyan
}