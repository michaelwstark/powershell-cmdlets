<#
.Synopsis
   This is a set of PowerShell cmdlets for common functions when developing source code on the UST Payments team.
.DESCRIPTION
   Some interesting or otherwise helpful cmdlets for issuing tasks.  Feel free to take parts or the whole.

   You can add the following lines into your Microsoft.PowerShell_profile.ps1 file to load these cmdlets whenever
   you open a PowerShell Environment.  In addition, you can add it to NuGet_profile.ps1 to get the cmdlets to load
   in the Visual Studio Package Manager console.  Both of these files should be created under your
   'Documents\WindowsPowershell' folder.  Samples of these two files can be found next to this file in source control.

   $ProfileScriptPath = Join-Path 'E:\Repos\ThirdPartyPayments.Library\Product\Scripts' ProfileCmdlets.ps1
   . $ProfileScriptPath

   This file assumes that you have the posh-git repo locally under your 'Repos' folder.  You can clone it by
   running the following command from the Repos folder:

   git clone https://github.com/dahlbyk/posh-git.git

   Author: Michael Stark (mstark) - Universal Store - Store Core - Payments
#>

#########################################################
## Helper Cmdlets
#########################################################

Class PullRequest
{
    [string] $sourceRefName
    [string] $targetRefName
    [string] $title
    [string] $description
}

Class IdentityLookupOptions
{
    [int] $MinResults
    [int] $MaxResults
}

Class IdentityLookupRequest
{
    [string]                $query
    [string[]]              $identityTypes
    [string[]]              $operationScopes
    [string[]]              $properties
    [IdentityLookupOptions] $options
}

Class AddReviewerRequest
{
    [int] $vote
}

Function Test-AbsolutePath
{
    Param
    (
        [Parameter(Mandatory=$True)]
        [String]$Path
    )

    [System.IO.Path]::IsPathRooted($Path)
}

Function Build-Project
{
    Param
    (
        [switch]$Full,

        [ValidateSet('', 'x86','ARM','x64', 'AnyCPU')]
        [string]$Platform = '',

        [ValidateSet('', 'Release', 'Debug')]
        [string]$Configuration = '',

        [ValidateSet('', 'Quiet', 'Minimal', 'Normal', 'Detailed', 'Diagnostic')]
        [string]$Verbosity = '',

        [string]$Project = '',

        [string]$Target = ''
    )

    [string[]] $MsBuildArgumentList = @()

    If (-not [string]::IsNullOrEmpty($Project))
    {
        # We could check to see if the project exists, but we'll let that flow to msbuild
        $MsBuildArgumentList += @("$Project")
    }

    $MsBuildArgumentList += @("/m")

    If (-not [string]::IsNullOrWhiteSpace($Configuration))
    {
        $MsBuildArgumentList += @("/p:Configuration=$Configuration")
    }

    If (-not [string]::IsNullOrWhiteSpace($Platform))
    {
        $MsBuildArgumentList += @("/p:Platform=$Platform")
    }

    If (-not [string]::IsNullOrWhiteSpace($Verbosity))
    {
        $MsBuildArgumentList += @("/v:$($Verbosity.ToLower())")
    }

    If ($Full)
    {
        Build-Project -Target Restore -Platform $Platform -Configuration $Configuration -Verbosity $Verbosity -Project $Project
    }

    If (-not [string]::IsNullOrEmpty($Target))
    {
        $MsBuildArgumentList += @("/target:$Target")
    }

    & msbuild.exe @MsBuildArgumentList
    $MsBuildExitCode = $LastExitCode
    If ($MsBuildExitCode -ne 0)
    {
        Throw "MSBuild Failed.  Exit Code: $MsBuildExitCode"
    }

    If ($Full)
    {
        Build-Project -Target Package -Platform $Platform -Configuration $Configuration -Verbosity $Verbosity -Project $Project
    }
}

Function Package-Project
{
    Param
    (
        [ValidateSet('', 'x86','ARM','x64', 'AnyCPU')]
        [string]$Platform = '',

        [ValidateSet('', 'Release', 'Debug')]
        [string]$Configuration = '',

        [ValidateSet('', 'Quiet', 'Minimal', 'Normal', 'Detailed', 'Diagnostic')]
        [string]$Verbosity = '',

        [string]$Project = ''
    )

    Build-Project -Target 'Package' -Platform $Platform -Configuration $Configuration -Verbosity $Verbosity -Project $Project
}

Function Clean-Project
{
    Param
    (
        [ValidateSet('', 'x86','ARM','x64', 'AnyCPU')]
        [string]$Platform = '',

        [ValidateSet('', 'Release', 'Debug')]
        [string]$Configuration = '',

        [ValidateSet('', 'Quiet', 'Minimal', 'Normal', 'Detailed', 'Diagnostic')]
        [string]$Verbosity = '',

        [string]$Project = ''
    )

    Build-Project -Target 'Clean' -Platform $Platform -Configuration $Configuration -Verbosity $Verbosity -Project $Project
}

Function Rebuild-Project
{
    Param
    (
        [ValidateSet('', 'x86','ARM','x64', 'AnyCPU')]
        [string]$Platform = '',

        [ValidateSet('', 'Release', 'Debug')]
        [string]$Configuration = '',

        [ValidateSet('', 'Quiet', 'Minimal', 'Normal', 'Detailed', 'Diagnostic')]
        [string]$Verbosity = '',

        [string]$Project = ''
    )

    Build-Project -Target 'Clean' -Platform $Platform -Configuration $Configuration -Verbosity $Verbosity -Project $Project
    Build-Project -Target 'Build' -Platform $Platform -Configuration $Configuration -Verbosity $Verbosity -Project $Project
}

Function Purge-Repository
{
    git.exe clean -xfd -e node_modules -e */.vs/ -e **/db.lock -e **/storage.ide*
}

Function Checkout-Branch
{
    Param
    (
        [string]$Branch = ''
    )

    If ([string]::IsNullOrWhiteSpace($Branch))
    {
        $Branch = Read-Host 'Branch: '
    }

    git.exe checkout $Branch
    git.exe submodule update --recursive
}

Function Merge-Branch
{
    Param
    (
        [string]$SourceBranch = ''
    )

    If ([string]::IsNullOrWhiteSpace($SourceBranch))
    {
        git.exe mergetool
    }
    Else
    {
        git.exe merge $SourceBranch
    }
}

Function Prune-Branches
{
    Param
    (
        [ValidateSet($false, $true)]
        [switch]$Destructive = $false
    )

    git.exe checkout master
    git.exe fetch -p

    If ($Destructive -eq $true)
    {
        git.exe branch --list --format "%(if:equals=[gone])%(upstream:track)%(then)%(refname:short)%(end)" | where { $_ -ne "" } | foreach { git.exe branch -D $_ }
    }
    Else
    {
        git.exe branch --list --format "%(if:equals=[gone])%(upstream:track)%(then)%(refname:short)%(end)" | where { $_ -ne "" } | foreach { git.exe branch -d $_ }
    }
}

Function Navigate-Wallet
{
    pushd $WalletRoot
}

Function Navigate-WebPaymentFrontEnd
{
    pushd $WebPaymentsFrontEnd
}

Function Navigate-PaymentFrontDoor
{
    pushd $PaymentFrontDoorRoot
}

Function Navigate-MerchantManagementService
{
    pushd $MerchantManagementServiceRoot
}

Function Navigate-PowershellCmdlets
{
    pushd $PowerShellCmdletsRoot
}

Function Navigate-DevTest
{
    pushd $DevTestRoot
}

Function Navigate-Labs
{
    pushd $LabsRoot
}

Function Navigate-ThirdPartyPaymentsLibrary
{
    pushd $ThirdPartyPaymentsLibraryRoot
}

Function Navigate-WebPaymentsApp
{
    pushd $WebPaymentsAppRoot
}

Function Navigate-TokensDataService
{
    pushd $TokensDataServiceRoot
}

Function Navigate-Root
{
    $Location = Get-Location

    If ($Location.Path.StartsWith($WalletRoot, "CurrentCultureIgnoreCase"))
    {
        Navigate-Wallet
    }
    ElseIf ($Location.Path.StartsWith($WebPaymentsFrontEnd, "CurrentCultureIgnoreCase"))
    {
        Navigate-WebPaymentFrontEnd
    }
    ElseIf ($Location.Path.StartsWith($PaymentFrontDoorRoot, "CurrentCultureIgnoreCase"))
    {
        Navigate-PaymentFrontDoor
    }
    ElseIf ($Location.Path.StartsWith($MerchantManagementServiceRoot, "CurrentCultureIgnoreCase"))
    {
        Navigate-MerchantManagementService
    }
    ElseIf ($Location.Path.StartsWith($PowerShellCmdletsRoot, "CurrentCultureIgnoreCase"))
    {
        Navigate-PowerShellCmdlets
    }
    ElseIf ($Location.Path.StartsWith($DevTestRoot, "CurrentCultureIgnoreCase"))
    {
        Navigate-DevTest
    }
    ElseIf ($Location.Path.StartsWith($LabsRoot, "CurrentCultureIgnoreCase"))
    {
        Navigate-Labs
    }
    ElseIf ($Location.Path.StartsWith($ThirdPartyPaymentsLibraryRoot, "CurrentCultureIgnoreCase"))
    {
        Navigate-ThirdPartyPaymentsLibrary
    }
    ElseIf ($Location.Path.StartsWith($WebPaymentsAppRoot, "CurrentCultureIgnoreCase"))
    {
        Navigate-WebPaymentsApp
    }
    ElseIf ($Location.Path.StartsWith($TokensDataServiceRoot, "CurrentCultureIgnoreCase"))
    {
        Navigate-TokensDataService
    }
    Else
    {
        Throw "Current Location is Not Under a Known Repo."
    }
}

Function Find-Repo
{
    $Location = Get-Location

    If ($Location.Path.StartsWith($WalletRoot, "CurrentCultureIgnoreCase"))
    {
        Return 'Wallet'
    }
    ElseIf ($Location.Path.StartsWith($WebPaymentsFrontEnd, "CurrentCultureIgnoreCase"))
    {
        Return 'WebPayments.FrontEnd'
    }
    ElseIf ($Location.Path.StartsWith($PaymentFrontDoorRoot, "CurrentCultureIgnoreCase"))
    {
        Return 'Payment.FrontDoor'
    }
    ElseIf ($Location.Path.StartsWith($MerchantManagementServiceRoot, "CurrentCultureIgnoreCase"))
    {
        Return 'Merchant.ManagementService'
    }
    ElseIf ($Location.Path.StartsWith($PowerShellCmdletsRoot, "CurrentCultureIgnoreCase"))
    {
        Return 'powershell-cmdlets'
    }
    ElseIf ($Location.Path.StartsWith($DevTestRoot, "CurrentCultureIgnoreCase"))
    {
        Return 'DevTest'
    }
    ElseIf ($Location.Path.StartsWith($LabsRoot, "CurrentCultureIgnoreCase"))
    {
        Return 'Labs'
    }
    ElseIf ($Location.Path.StartsWith($ThirdPartyPaymentsLibraryRoot, "CurrentCultureIgnoreCase"))
    {
        Return 'ThirdPartyPayments.Library'
    }
    ElseIf ($Location.Path.StartsWith($WebPaymentsAppRoot, "CurrentCultureIgnoreCase"))
    {
        Return 'Microsoft.Pay'
    }
    ElseIf ($Location.Path.StartsWith($TokensDataService, "CurrentCultureIgnoreCase"))
    {
        Return 'Tokens.DataService'
    }
    Else
    {
        Throw "Current Location is Not Under a Known Repo."
    }
}

Function Navigate-Product
{
    Navigate-Root
    pushd 'Product'
}

Function Commit-Change
{
    Param
    (
        [string]$Message = ''
    )

    If ([string]::IsNullOrWhiteSpace($Message))
    {
        git.exe commit
    }
    Else
    {
        git.exe commit -m "$Message"
    }
}

Function Push-Repository
{
    git.exe push
}

Function Pull-Repository
{
    git.exe pull
}

Function Login-VstsAccount
{
    # TODO: We should probably find a better place to load these from -- no?
    Load-Assembly -AssemblyPath "$Env:ProgramFiles\Git\mingw64\libexec\git-core\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    Load-Assembly -AssemblyPath "$Env:ProgramFiles\Git\mingw64\libexec\git-core\Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext] $Context = New-Object -TypeName Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext('https://login.microsoftonline.com/common') -ErrorAction Stop

    [string] $ResourceId = '499b84ac-1321-427f-aa17-267ca6975798'
    [string] $ClientId = '872cd9fa-d31f-45e0-9eab-6e460a02d1f1'
    [System.Uri] $ReplyUri = New-Object -TypeName System.Uri('urn:ietf:wg:oauth:2.0:oob')
    [Microsoft.IdentityModel.Clients.ActiveDirectory.IPlatformParameters] $PlatformParameters = New-Object -TypeName Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters([Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto)
    $Action = $Context.AcquireTokenAsync($ResourceId, $ClientId, $ReplyUri, $PlatformParameters)
    $Global:VstsAccessToken = $Action.Result
}

Function Find-VstsUserByAlias
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string] $Alias
    )

    Login-VstsAccount

    $UserQuery = [IdentityLookupRequest]::new()
    $UserQuery.query = "$Alias@"
    $UserQuery.identityTypes = @( 'user' )
    $UserQuery.operationScopes = @( 'ims' )
    $UserQuery.properties = @( 'SamAccountName', 'SamAccountName' )

    # We should never get back more than one with the above query, but allow two so we can error if there is an edge case somewhere
    $UserQuery.options = [IdentityLookupOptions]::new()
    $UserQuery.options.MinResults = 2
    $UserQuery.options.MaxResults = 2


    $IdentityLookupUrl = 'https://microsoft.visualstudio.com/_apis/IdentityPicker/Identities?api-version=3.0-preview.1'
    $Authorization = "$($Global:VstsAccessToken.AccessTokenType) $($Global:VstsAccessToken.AccessToken)"
    $Headers = @{ Authorization = $Authorization }
    $Payload = ConvertTo-Json $UserQuery

    $Response = Invoke-WebRequest -Uri $IdentityLookupUrl -Headers $Headers -Method Post -ContentType 'application/json' -Body $Payload

    If ($Response.StatusCode -ne 200)
    {
        Write-Host
        Write-Host "StatusCode: $($Response.StatusCode)"
        Write-Host 'Something happened.  Figure it out.  I can''t be bothered.'
        Write-Host
        Write-Host 'Sad Times.'
        Return $Null
    }

    $IdentityContent = ConvertFrom-Json $Response.Content

    If ($IdentityContent.results.identities.Count -eq 0)
    {
        Return $Null
    }

    If ($IdentityContent.results.identities.Count -gt 1)
    {
        Write-Host
        Write-Host 'Multiple users returned.  This shouldn''t happen.  The end times are near.'
        Write-Host
        Write-Host 'Sad Times.'
        Return $Null
    }

    Return $IdentityContent.results.identities[0]
}

Function New-PullRequest
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]   $Title,

        [string]   $Description,

        [ValidateNotNullOrEmpty()]
        [string]   $TargetBranch = 'master',

        [string[]] $AdditionalReviewers = @()
    )

    Login-VstsAccount

    $Repo = Find-Repo
    Write-Host "Repo: $Repo"
    $Branch = $Global:GitStatus.Branch
    Write-Host "Branch: $Branch"

    If ([string]::IsNullOrWhiteSpace($Description))
    {
        $Description = $Title
    }

    $PullRequest = [PullRequest]::new()
    $PullRequest.sourceRefName = "refs/heads/$Branch"
    $PullRequest.targetRefName = "refs/heads/$TargetBranch"
    $PullRequest.title = $Title
    $PullRequest.description = $Description

    $Url = "https://microsoft.visualstudio.com/DefaultCollection/Universal%20Store/_apis/git/repositories/$Repo/pullRequests?api-version=3.0"
    Write-Host "Url: $Url"

    $Authorization = "$($Global:VstsAccessToken.AccessTokenType) $($Global:VstsAccessToken.AccessToken)"
    $Headers = @{ Authorization = $Authorization }
    $Payload = ConvertTo-Json $PullRequest

    Write-Host "Creating Pull Request..."
    $Response = Invoke-WebRequest -Uri $Url -Headers $Headers -Method Post -ContentType 'application/json' -Body $Payload
    $Response

    If ($Response.StatusCode -ne 201)
    {
        Write-Host
        Write-Host 'Something happened.  Figure it out.  I can''t be bothered.'
        Write-Host
        Write-Host 'Sad Times.'
        Return
    }

    $PullRequestResponse = ConvertFrom-Json $Response.Content
    $PullRequestId = $PullRequestResponse.pullRequestId

    # Add some additional reviewers
    If ($AdditionalReviewers.Count -gt 0)
    {
        Write-Host "Adding additional reviewers..."
        ForEach ($Reviewer in $AdditionalReviewers)
        {
            Add-PullRequestReviewer -PullRequestId $PullRequestId -Alias $Reviewer
        }
    }

    Write-Host
    Write-Host "Id: $PullRequestId"
    $PullRequestUrl = "https://microsoft.visualstudio.com/Universal%20Store/_git/$Repo/pullrequest/$PullRequestId#_a=overview"
    Write-Host "Url: $PullRequestUrl"
    Write-Host "Opening url ..."
    [System.Diagnostics.Process]::Start($PullRequestUrl)
}

Function Add-PullRequestReviewer
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [int] $PullRequestId,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string] $Alias
    )

    Login-VstsAccount

    Write-Host "Adding User $Alias to Pull Request $PullRequestId..."

    $VstsUser = Find-VstsUserByAlias -Alias $Alias

    If ($VstsUser -eq $Null)
    {
        Write-Warning "Could not locate a single user using alias '$Alias'"
        Return
    }

    [AddReviewerRequest] $AddReviewerRequest = [AddReviewerRequest]::new()
    $AddReviewerRequest.vote = 0

    $AddReviewerUrl = "https://microsoft.visualstudio.com/DefaultCollection/Universal%20Store/_apis/git/repositories/$Repo/pullRequests/$PullRequestId/reviewers/$($VstsUser.localId)?api-version=3.0"
    $Authorization = "$($Global:VstsAccessToken.AccessTokenType) $($Global:VstsAccessToken.AccessToken)"
    $Headers = @{ Authorization = $Authorization }
    $Payload = ConvertTo-Json $AddReviewerRequest

    $Response = Invoke-WebRequest -Uri $AddReviewerUrl -Headers $Headers -Method Put -ContentType 'application/json' -Body $Payload

    If ($Response.StatusCode -lt 200 -or $Response.StatusCode -ge 300)
    {
        Write-Warning "Adding Reviewer Failed '$Alias'"
        Write-Host $Response
    }
}

Function Deploy-Service
{
    Param
    (
        [ValidateSet('x86','ARM','x64', 'AnyCPU')]
        [string]$Platform = 'AnyCPU',

        [ValidateSet('Release', 'Debug')]
        [string]$Configuration = 'Debug',

        [switch]$SkipBuild = $False
    )

    Navigate-Root -ErrorAction Stop

    Try
    {
        If (-not $SkipBuild)
        {
            Build-Project -Platform $Platform -Configuration $Configuration
        }

        $DeploymentPath = ".\bin\$Platform\$Configuration\Deployment"

        If (Test-Path -LiteralPath $DeploymentPath)
        {
            pushd $DeploymentPath
            & .\Deploy-AzureService.ps1 -ErrorAction SilentlyContinue
            popd
        }
        Else
        {
            Write-Warning "Repo does not contain a deployment folder for the platform '$Platform' and configuration '$Configuration'."
            If ($SkipBuild)
            {
                Write-Warning "No Build was requested.  Please verify it exists, or run again omitting the '-SkipBuild' parameter."
            }
        }
    }
    Catch
    {
        Write-Error "Something happened.  Figure it out -- I can't be bothered.`n$_.Exception.ToString()"
    }

    # Return the user to the previous location if Navigate-Root succeeded.
    popd
}

Function NuGet-Push
{
    Param
    (
        [ValidateNotNullOrEmpty()]
        [string]$Package,

        [ValidateSet('UniversalStore','Payments','PaymentsPrivate','LabServices','MSENG')]
        [string]$Feed = 'LabServices'
    )

    $CurrentLocation = Get-Location
    $PackageLocation = $Package

    If(-not (Test-AbsolutePath -Path $PackageLocation))
    {
        $PackageLocation = Join-Path $CurrentLocation $PackageLocation
    }

    If (-not (Test-Path -LiteralPath $PackageLocation))
    {
        Write-Error 'Package specified does not exist.'
        Return
    }

    Switch ($Feed)
    {
        'UniversalStore'
        {
            $Url = 'https://microsoft.pkgs.visualstudio.com/_packaging/Universal.Store/nuget/v3/index.json'
        }
        'Payments'
        {
            $Url = 'https://microsoft.pkgs.visualstudio.com/_packaging/Payments/nuget/v3/index.json'
        }
        'PaymentsPrivate'
        {
            $Url = 'https://microsoft.pkgs.visualstudio.com/_packaging/Payments.Private/nuget/v3/index.json'
        }
        'LabServices'
        {
            $Url = 'https://devdiv.pkgs.visualstudio.com/_packaging/azure-lab-services/nuget/v3/index.json'
        }
        'MSENG'
        {
            $Url = 'https://mseng.pkgs.visualstudio.com/_packaging/DevTestLab/nuget/v3/index.json'
        }
        Default
        {
            Write-Error 'Unrecognized feed specified.  Shouldn''t be here.'
            Return
        }
    }

    # Prompt if you are trying to publish to a public feed.
    If ($Feed -eq 'Payments')
    {
        $Choice = ""
        While ($Choice -notmatch "[y|n]")
        {
            $Choice = read-host "Public Feed.  Do you want to continue? (Y/N)"
        }

        If ($Choice -eq 'N')
        {
            Write-Host 'Be more careful next time. Idiot.'
            Return
        }
    }

    Navigate-Root

    & .\NuGet\NuGet.exe push "$PackageLocation" -Source "$Url" -ApiKey  VSTS

    popd
}

Function NuGet-Restore
{
    Build-Project -Target Restore
}

Function Load-Assembly
{
    Param
    (
        [string] $AssemblyPath
    )

    If (-not (Test-Path -LiteralPath $AssemblyPath))
    {
        Throw "Could not load assembly $AssemblyPath."
    }

    [System.Reflection.Assembly]::LoadFrom($AssemblyPath) | Out-Null
}

Function Reformat-Json
{
    $Location = Get-Location

    $JsonFiles = Get-ChildItem -Recurse '*.json'

    # Load Newtonsoft Into Memory
    If ($JsonFiles.Length -ge 1)
    {
        $NewtonsoftJsonAssembly = Join-Path $PSScriptRoot 'bin\Newtonsoft.Json.dll'
        Load-Assembly -AssemblyPath $NewtonsoftJsonAssembly
    }

    ForEach ($JsonFile in $JsonFiles)
    {
        Write-Host "Reformatting: $JsonFile"

        $Json = Get-Content $JsonFile

        $Object = [Newtonsoft.Json.JsonConvert]::DeserializeObject($Json)
        $Json = [Newtonsoft.Json.JsonConvert]::SerializeObject($Object, [Newtonsoft.Json.Formatting]::Indented)
        [System.IO.File]::WriteAllText($JsonFile, $Json, [System.Text.Encoding]::UTF8)
    }
}

Function Kill-Edge
{
    Param
    (
        [ValidateSet('', 'Fire')]
        [String] $With = ''
    )

    Kill-Process -Name MicrosoftEdge -With $With
    Kill-Process -Name MicrosoftEdgeCP -With $With
}

Function Kill-Process
{
    Param
    (
        [ValidateNotNullOrEmpty()]
        [String] $Name,

        [ValidateSet('', 'Fire')]
        [String] $With = ''
    )

    $Processes = Get-Process -Name $Name -ErrorAction SilentlyContinue
    If ($Processes -ne $Null)
    {
        If ($With -eq 'Fire')
        {
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
        Else
        {
            Stop-Process -ProcessName $Name
        }
    }
}

Function New-CodeReview
{
    Try
    {
        Navigate-Root
        $CurrentRepoRoot = Get-Location
        Pop-Location
    }
    Catch
    {
        $CurrentRepoRoot = $Null
    }

    If ($CurrentRepoRoot -eq $Null)
    {
        Write-Warning 'Could not determine repo root location.  Opening CodeFlow without Customization.'
    }
    Else
    {
        $CodeFlowSettingsPath = Join-Path $Env:LOCALAPPDATA 'CodeFlow\ClientSettings.xml'

        If (Test-Path -LiteralPath $CodeFlowSettingsPath)
        {
            [Xml]$CodeFlowSettings = Get-Content $CodeFlowSettingsPath

            ForEach ($KeyValue in $CodeFlowSettings.ClientSettings.Preferences.KeyValueOfstringstring)
            {
                If (($KeyValue.Key -eq 'Project[Universal Store].SourceControl[Git].LastPath') -or (($KeyValue.Key -eq 'Project[Universal Store].SourceControl[Git].LastServerUri')))
                {
                    $KeyValue.Value = $CurrentRepoRoot.Path
                }
            }

            $CodeFlowSettings.Save($CodeFlowSettingsPath)
        }
        Else
        {
            Write-Warning 'Could not find CodeFlow settings file.  It has either moved, or you haven''t used CodeFlow before.'
        }
    }

    $CodeFlowLauncerPath = Join-Path $Env:LOCALAPPDATA 'cfLauncher\BootCodeFlow.exe'

    If (Test-Path -LiteralPath $CodeFlowLauncerPath)
    {
        & $CodeFlowLauncerPath 'codeflow://open/?server=https%3A%2F%2Fmicrosoft.visualstudio.com%2F&host=vso'
    }
    Else
    {
        Write-Warning 'Could not find CodeFlow launcher.  It has either moved, or you haven''t used CodeFlow before.'
    }
}

Function  Print-Object
{
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
    $Json = $JsonLines -join  "`r`n"

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
    ) | % {
        If (Test-Path $_){
            Write-Verbose "Running $_"
            . $_
        }
    }
}

#########################################################
## Aliases
#########################################################

Set-Alias Build Build-Project
Set-Alias Clean Clean-Project
Set-Alias Rebuild Rebuild-Project
Set-Alias Purge Purge-Repository
Set-Alias Merge Merge-Branch
Set-Alias Checkout Checkout-Branch
Set-Alias Commit Commit-Change
Set-Alias Push Push-Repository
Set-Alias Pull Pull-Repository
Set-Alias Wallet Navigate-Wallet
Set-Alias WebPay Navigate-WebPaymentFrontEnd
Set-Alias WebPayApp Navigate-WebPaymentsApp
Set-Alias HWA Navigate-WebPaymentsApp
Set-Alias TDS Navigate-TokensDataService
Set-Alias PayFD Navigate-PaymentFrontDoor
Set-Alias MMS Navigate-MerchantManagementService
Set-Alias Scripts Navigate-PowerShellCmdlets
Set-Alias DevTest Navigate-DevTest
Set-Alias Labs Navigate-Labs
Set-Alias TPP Navigate-ThirdPartyPaymentsLibrary
Set-Alias Root Navigate-Root
Set-Alias Product Navigate-Product
Set-Alias NuGetPush NuGet-Push
Set-Alias Deploy Deploy-Service
Set-Alias Restore NuGet-Restore
Set-Alias Reload Reload-Profile
Set-Alias Print Print-Object
Set-Alias CR New-CodeReview
Set-Alias PR New-PullRequest
Set-Alias Package Package-Project

#########################################################
## Environment Initialization
#########################################################

#########################################################
## Add git to the PATH
#########################################################
If ($GitRoot -eq $Null)
{
    # Get the Drives on the Computer
    $Drives = Get-PSDrive | Where-Object { $_.Provider.Name -eq "FileSystem" } | Sort-Object -Property Root

    # Iterate Over the Drives To See Where the 'Repos' Folder is
    ForEach ($Drive in $Drives)
    {
        $TestGitRoot = Join-Path $Drive.Root 'Git'
        If (Test-Path -LiteralPath $TestGitRoot)
        {
            $GitRoot = $TestGitRoot
            Break
        }
    }
}

If ($GitRoot -ne $Null)
{
    $GitPath = Join-Path $GitRoot 'cmd'
    $env:Path = "$GitPath;$Env:Path"
}
Else
{
    Write-Warning 'Could not locate the root of the git binaries.  Please resolve or ensure git.exe is in your PATH.'
}

#########################################################
## Initialize Repos Path and Import Posh-Git
#########################################################
If ($ReposRoot -eq $Null)
{
    # Get the Drives on the Computer
    $Drives = Get-PSDrive | Where-Object { $_.Provider.Name -eq "FileSystem" } | Sort-Object -Property Root

    # Iterate Over the Drives To See Where the 'Repos' Folder is
    ForEach ($Drive in $Drives)
    {
        $TestReposRoot = Join-Path $Drive.Root 'Repos'
        If (Test-Path -LiteralPath $TestReposRoot)
        {
            $ReposRoot = $TestReposRoot
            Break
        }
    }
}

# If we found a root set our repo locations
If ($ReposRoot -ne $Null)
{
    If ([string]::IsNullOrWhiteSpace($WalletRepoFolderName))
    {
        $WalletRepoFolderName = 'Wallet'
    }
    If ([string]::IsNullOrWhiteSpace($WebPaymentsFrontEndRepoFolderName))
    {
        $WebPaymentsFrontEndRepoFolderName = 'WebPayments.FrontEnd'
    }
    If ([string]::IsNullOrWhiteSpace($MicrosoftPayRepoFolderName))
    {
        $MicrosoftPayRepoFolderName = 'Microsoft.Pay'
    }
    If ([string]::IsNullOrWhiteSpace($TokensDataServiceRepoFolderName))
    {
        $TokensDataServiceRepoFolderName = 'Tokens.DataService'
    }
    If ([string]::IsNullOrWhiteSpace($PaymentFrontDoorRepoFolderName))
    {
        $PaymentFrontDoorRepoFolderName = 'Payment.FrontDoor'
    }
    If ([string]::IsNullOrWhiteSpace($MerchantManagementServiceRepoFolderName))
    {
        $MerchantManagementServiceRepoFolderName = 'Merchant.ManagementService'
    }
    If ([string]::IsNullOrWhiteSpace($PowerShellCmdletsRepoFolderName))
    {
        $PowerShellCmdletsRepoFolderName = 'powershell-cmdlets'
    }
    If ([string]::IsNullOrWhiteSpace($DevTestRepoFolderName))
    {
        $DevTestRepoFolderName = 'DevTest'
    }
    If ([string]::IsNullOrWhiteSpace($LabsRepoFolderName))
    {
        $LabsRepoFolderName = 'azure-lab-services'
    }
    If ([string]::IsNullOrWhiteSpace($ThirdPartyPaymentsRepoFolderName))
    {
        $ThirdPartyPaymentsRepoFolderName = 'ThirdPartyPayments.Library'
    }
    If ([string]::IsNullOrWhiteSpace($PostGitRepoFolderName))
    {
        $PostGitRepoFolderName = 'posh-git'
    }

    $WalletRoot = Join-Path $ReposRoot $WalletRepoFolderName
    $WebPaymentsFrontEnd = Join-Path $ReposRoot $WebPaymentsFrontEndRepoFolderName
    $WebPaymentsAppRoot = Join-Path $ReposRoot $MicrosoftPayRepoFolderName
    $TokensDataServiceRoot = Join-Path $ReposRoot $TokensDataServiceRepoFolderName
    $PaymentFrontDoorRoot = Join-Path $ReposRoot $PaymentFrontDoorRepoFolderName
    $MerchantManagementServiceRoot = Join-Path $ReposRoot $MerchantManagementServiceRepoFolderName
    $PowerShellCmdletsRoot = Join-Path $ReposRoot $PowerShellCmdletsRepoFolderName
    $DevTestRoot = Join-Path $ReposRoot $DevTestRepoFolderName
    $LabsRoot = Join-Path $ReposRoot $LabsRepoFolderName
    $ThirdPartyPaymentsLibraryRoot = Join-Path $ReposRoot $ThirdPartyPaymentsRepoFolderName
    $PoshGitRoot = Join-Path $ReposRoot $PostGitRepoFolderName

    #Load PoshGit
    $PoshGitModule = Join-Path $PoshGitRoot src
    $PoshGitModule = Join-Path $PoshGitModule 'posh-git.psd1'

    # Clone the posh-git repo if it isn't already local.
    $IsPoshGitCloned = Test-Path -LiteralPath $PoshGitModule
    If (-not ($IsPoshGitCloned) -and $GitPath -ne $Null)
    {
        pushd $ReposRoot
        git.exe clone 'https://github.com/dahlbyk/posh-git.git'
        $IsPoshGitCloned = $True
        popd
    }

    If ($IsPoshGitCloned)
    {
        Import-Module $PoshGitModule

        # This is a personal preference.  I can remove and put in my profile file if desired.
        # Try it out first though.
        If ($Env:USERNAME -eq 'mstark')
        {
            $GitPromptSettings.DefaultPromptSuffix = '`n$(''>'' * ($nestedPromptLevel + 1)) '
        }
    }
    Else
    {
        Write-Warning 'Could not find posh-git repo location.  Please resolve or ensure msbuild.exe is in your PATH.'
    }
}
Else
{
    Write-Warning 'Could not locate the root of the git repos.  Repo navigation related functions will not work.'
}

#########################################################
## Add MSBuild to the PATH
#########################################################
$MSBuildPath = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin"

If (-not (Test-Path -LiteralPath $MSBuildPath))
{
    $MSBuildPath = "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Preview\MSBuild\Current\Bin"
}

If (Test-Path -LiteralPath $MSBuildPath)
{
    # Add msbuild to the local console PATH variable
    $Env:Path = "$msbuildPath;$env:Path"
}
Else
{
    Write-Warning 'Could not find MSBuild binary location.  Please resolve or ensure msbuild.exe is in your PATH.'
}
