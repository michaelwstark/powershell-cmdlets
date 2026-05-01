# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal collection of PowerShell helpers used by `mstark` to navigate and operate on multiple Microsoft-internal git repos checked out side-by-side. There is no build, no test suite, and no package — code is consumed by dot-sourcing `Scripts/profile.ps1` from the user's `Microsoft.PowerShell_profile.ps1` (and optionally `NuGet_profile.ps1` for the Visual Studio Package Manager Console).

## How it loads

1. The user's PowerShell profile dot-sources `Scripts/profile.ps1`.
2. `profile.ps1` walks every filesystem PSDrive looking for a folder literally named `Repos`. The first match wins and becomes `$ReposRoot`.
3. The user can optionally set `$DefaultRepo` (Scripts/profile.ps1:19-20) to one of the per-repo aliases — on shell startup the script `Set-Location`s into that repo, or into `$ReposRoot` (with a warning) if the variable is unset or doesn't match a known alias.
4. It then dot-sources `$ReposRoot\powershell-cmdlets\Scripts\ProfileCmdlets.ps1`, which defines all cmdlets, dynamically registers per-repo navigation aliases, and clones `posh-git` into `$ReposRoot` if missing.

If `$ReposRoot` cannot be located, navigation cmdlets are skipped with a warning but the file still loads.

## Repo discovery and per-repo aliases

`ProfileCmdlets.ps1` does **not** hardcode its known repos. The init block at the bottom of the file enumerates every directory under `$ReposRoot` (excluding `posh-git`) and, for each one, dynamically:

- Creates a `Navigate-<Alias>` function that `pushd`s to that path.
- Registers a `Set-Alias <Alias> Navigate-<Alias>` so the alias can be typed bare.
- Records the repo in `$Global:RepoRoots` so `Navigate-Root` and `Find-Repo` can iterate.

By default the alias **is the folder name**. Repos that need a different alias — or a different value for `Find-Repo` to return (the latter is the ADO/GitHub repo name used in URL construction) — are listed in `$RepoAliasOverrides` (Scripts/ProfileCmdlets.ps1:468):

```powershell
$RepoAliasOverrides = @{
  'powershell-cmdlets'  = @{ Alias = 'Scripts';   RepoName = 'powershell-cmdlets' }
  'azure-devcenter'     = @{ Alias = 'devcenter'; RepoName = 'azure-devcenter' }
  'mxc'                 = @{ Alias = 'mxc';       RepoName = 'mxc' }
  'W365A-Sandbox'       = @{ Alias = 'lithium';   RepoName = 'W365A-Sandbox' }
}
```

- **Add a repo with no special alias** — just clone it into `$ReposRoot`. Nothing in this file needs to change.
- **Add a repo with a custom alias / RepoName** — add a single entry to `$RepoAliasOverrides`.
- **Remove a repo** — delete the on-disk folder and (if it had one) its override entry.

`Navigate-Root` and `Find-Repo` (Scripts/ProfileCmdlets.ps1:101-123) loop over `$Global:RepoRoots` to find the entry whose `Path` is a prefix of the cwd. Both throw if the cwd is not under any known repo.

## Pull requests, NuGet, and remote-host helpers

**There is no custom auth code anywhere.** Anything that talks to a remote shells out to `gh` (GitHub CLI) or `az` (Azure CLI with the `azure-devops` extension). Three small helpers wrap `git` to inspect the current origin (Scripts/ProfileCmdlets.ps1:153-200):

- **`Get-DefaultBranch`** — reads `origin/HEAD` and returns the short branch name; falls back to `'main'`.
- **`Get-GitRemoteHost`** — returns `'github'`, `'azuredevops'`, or `$Null`.
- **`Get-AzureDevOpsOrg`** — parses the org out of an ADO origin (handles `dev.azure.com/{org}`, `{org}.visualstudio.com`, and SSH `ssh.dev.azure.com:v3/{org}`). Returns `$Null` for non-ADO remotes.

**`New-PullRequest`** (alias `PR`, Scripts/ProfileCmdlets.ps1:202) dispatches on `Get-GitRemoteHost`:
- GitHub → `gh pr create --title --body --base --reviewer --web`
- ADO → `az repos pr create --title --description --target-branch --reviewers --open`

Each branch errors out cleanly if its CLI is missing. Target branch defaults to `Get-DefaultBranch`. Posh-git is **not** required.

**`NuGet-Push`** (alias `NuGetPush`, Scripts/ProfileCmdlets.ps1:267) is ADO-only. It builds `https://pkgs.dev.azure.com/{org}/_packaging/{Feed}/nuget/v3/index.json` dynamically using `Get-AzureDevOpsOrg`; `-Feed` defaults to `'DevTestLab'`. Errors out if the cwd is not in an ADO repo.

**`Prune-Branches`** (Scripts/ProfileCmdlets.ps1:83) uses `Get-DefaultBranch` to check out the right branch, so both `master`- and `main`-default repos work.

## Aliases

Static aliases (Scripts/ProfileCmdlets.ps1:403-417): `Restore`, `Build`, `Clean`, `Rebuild`, `Purge`, `Merge`, `Checkout`, `Commit`, `Push`, `Pull`, `Root`, `NuGetPush`, `Reload`, `Print`, `PR`.

Per-repo navigation aliases are **registered dynamically at load time**, one per directory found under `$ReposRoot`. Use `$RepoAliasOverrides` to control the alias name; otherwise the alias is the folder name. There are no static `Set-Alias` lines for individual repos.

## Standalone scripts

These are run directly, not loaded by the profile:

- `Scripts/Encrypt-Text.ps1` — RSA-encrypts a string with a cert from `cert:\LocalMachine\My\<thumbprint>`.
- `Scripts/Test-CertExpiration.ps1` — recursive `*.cer` scan with color-coded near-expiry / expired output (skips `\bin\` and `\obj\`).
- `Scripts/Test-TlsSupport.ps1` — connects each host in a line-delimited manifest on :443 and reports which of SSL2/SSL3/TLS1.0/1.1/1.2 the server accepts.

## NotepadRedirect

`Scripts/NotepadRedirect.cmd` + `.reg` install an Image File Execution Options Debugger on `notepad.exe` so any invocation re-launches in VS Code. The `.reg` hardcodes the path `E:\Repos\powershell-cmdlets\Scripts\NotepadRedirect.cmd` — if applying it on a machine where the repo lives on a different drive, the path must be edited first.

## Conventions worth matching

When editing PowerShell or CMD in this repo, mirror the observed style — these are the rules a quick read of the files surfaces.

### PowerShell — applies to every file

- **Keywords are PascalCase**: `If`, `Else`, `ElseIf`, `Function`, `Param`, `Return`, `Throw`, `ForEach`, `Switch`, `Default`, `Continue`, `Try`, `Catch`, `Finally`, `Class`, `Enum`. Booleans/null too: `$True`, `$False`, `$Null`. Idiomatic lowercase (`if`, `$true`) is **not** used.
- **Variables and parameters are PascalCase** (`$RepoPath`, `$CertificateThumbprint`). Globals carry the explicit `$Global:` prefix.
- **Param blocks** put `Param` on its own line, `(` on the next, one typed parameter per stanza:
  ```
  Param
  (
      [Parameter(Mandatory = $True)]
      [ValidateNotNullOrEmpty()]
      [string] $Name
  )
  ```
- **Validation attributes are used liberally**: `[Parameter(Mandatory = $True)]`, `[ValidateNotNullOrEmpty()]`, `[ValidateSet(...)]`, `[ValidateRange(...)]`.
- **Function naming is Verb-Noun, PascalCase, with non-approved verbs accepted** (`Purge-Repository`, `Reformat-Json`, `Kill-Edge`, `Navigate-*`). Do **not** "fix" these to approved verbs unless asked — aliases and muscle memory depend on the current names.
- **Strings**: single quotes for literals, double quotes only when interpolating.
- **Comparisons** are left-variable / right-literal (`$Var -eq $Null`), not Yoda style.
- **External commands include the `.exe`**: `git.exe`, not bare `git`. The `pushd`/`popd` aliases for `Push-Location`/`Pop-Location` are accepted and used pervasively (including in dynamically-created navigation functions).
- **File-existence checks use `-LiteralPath`** to avoid glob expansion.
- **Splatting** for external command arguments (`& az @AzArgs`).
- **Output channels**: `Write-Host` for user-facing flow, `Write-Warning` for soft warnings, `Write-Error` for errors. `Write-Output` is reserved for actual return-to-pipeline values.
- **Section headers** are `#####...####` banner comments at file scope.

### PowerShell — file-specific styles

There are two distinct styles in this repo. Match whichever file you are editing.

- **`ProfileCmdlets.ps1`** uses **2-space indent and K&R-ish braces** (opening brace at end of keyword line). `Else` placement is mixed — both `} Else {` (cuddled) and `Else` on its own line appear; match the surrounding function rather than reformatting:
  ```
  If (...) {
    ...
  }
  Else {
    ...
  }
  ```
- **Standalone scripts** (`Test-CertExpiration.ps1`, `Test-TlsSupport.ps1`, `Encrypt-Text.ps1`) use **4-space indent and Allman braces** (brace on its own line):
  ```
  If (...)
  {
      ...
  }
  ```
- Standalone scripts begin with `[CmdletBinding()]` and a `<# .Synopsis / .DESCRIPTION / .PARAMETER / .EXAMPLE #>` comment-based help block. Profile-loaded files (`profile.ps1`, `ProfileCmdlets.ps1`) do not.
- Script-level error reporting in standalone scripts prints `'Sad Times.'` and `Exit 1`s; success ends with `'Happy Day.'`. This is intentional flavor — keep it when editing existing standalone scripts.

### CMD (`*.cmd`)

- `@ECHO OFF` at the top.
- Built-in keywords are ALL CAPS: `SET`, `SHIFT`, `IF`, `GOTO`, `CALL`. External commands (`start`) keep their natural casing.
- Labels are PascalCase (`:Loop`, `:Continue`).
- Comments use `::`, not `REM`.
- Variables are `%PascalCase%`.
