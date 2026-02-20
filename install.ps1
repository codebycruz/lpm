$ErrorActionPreference = "Stop"

$repo = "codebycruz/lpm"
$lpmDir = "$env:USERPROFILE\.lpm"
$binaryName = "lpm.exe"
$artifact = "lpm-windows-x86-64.exe"

Write-Host "Installing lpm..." -ForegroundColor Green

# Create .lpm directory if it doesn't exist
if (-not (Test-Path $lpmDir)) {
    Write-Host "Creating directory: $lpmDir"
    New-Item -ItemType Directory -Path $lpmDir | Out-Null
}

# Get latest release
Write-Host "Fetching latest release..."
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
    $tag = $release.tag_name
} catch {
    Write-Error "Error fetching latest release: $($_.Exception.Message)"
    exit 1
}

if (-not $tag) {
    Write-Error "Could not fetch latest release"
    exit 1
}

Write-Host "Latest version: $tag"

# Download binary
$downloadUrl = "https://github.com/$repo/releases/download/$tag/$artifact"
Write-Host "Downloading $artifact..."
$tmpFile = "$env:TEMP\$artifact"

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpFile
} catch {
    Write-Error "Error downloading binary: $($_.Exception.Message)"
    exit 1
}

# Install binary
$installPath = Join-Path $lpmDir $binaryName
Write-Host "Installing to $installPath..."

try {
    Move-Item -Path $tmpFile -Destination $installPath -Force
} catch {
    Write-Error "Error installing binary: $($_.Exception.Message)"
    exit 1
}

# Add to PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$lpmToolsDir = "$lpmDir\tools"
$pathAdded = $false

$needsLpmDir = $userPath -notlike "*$lpmDir*"
$needsToolsDir = $userPath -notlike "*$lpmToolsDir*"

if ($needsLpmDir -or $needsToolsDir) {
    Write-Host "Adding lpm directories to PATH..."
    try {
        $dirsToAdd = @()
        if ($needsLpmDir) { $dirsToAdd += $lpmDir }
        if ($needsToolsDir) { $dirsToAdd += $lpmToolsDir }

        $suffix = $dirsToAdd -join ";"
        if ($userPath -and -not $userPath.EndsWith(";")) {
            $newPath = "$userPath;$suffix"
        } else {
            $newPath = "$userPath$suffix"
        }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $pathAdded = $true
        Write-Host "PATH has been updated." -ForegroundColor Yellow
    } catch {
        Write-Warning "Could not automatically add to PATH: $($_.Exception.Message)"
    }
} else {
    Write-Host "$lpmDir already in PATH" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "lpm has been installed to: $installPath"

if ($pathAdded) {
    Write-Host ""
    Write-Host "PATH has been updated. Please:" -ForegroundColor Yellow
    Write-Host "  1. Restart your terminal/PowerShell session" -ForegroundColor Yellow
    Write-Host "  2. Run 'lpm' to get started" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "You can now run lpm by either:" -ForegroundColor Yellow
    Write-Host "  1. Restarting your terminal and running 'lpm'" -ForegroundColor Yellow
    Write-Host "  2. Running directly: $installPath" -ForegroundColor Yellow
}
