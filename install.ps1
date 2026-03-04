$ErrorActionPreference = "Stop"

$repo     = "codebycruz/lpm"
$lpmDir   = "$env:USERPROFILE\.lpm"
$artifact = "lpm-windows-x86-64.exe"

$tag = (Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest").tag_name
if (-not $tag) { Write-Error "Could not fetch latest release" }

New-Item -ItemType Directory -Path $lpmDir -Force | Out-Null
$installPath = Join-Path $lpmDir "lpm.exe"
Invoke-WebRequest "https://github.com/$repo/releases/download/$tag/$artifact" -OutFile $installPath

& $installPath --setup
