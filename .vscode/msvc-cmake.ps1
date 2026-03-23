# msvc-cmake.ps1
# Locates the latest MSVC installation via vswhere, initialises the x64 build
# environment from vcvarsall.bat, then forwards every argument to cmake unchanged.
#
# Usage (from tasks.json):
#   powershell -ExecutionPolicy Bypass -File msvc-cmake.ps1 [cmake args...]

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    # Some VS layouts put vswhere under Program Files instead of (x86)
    $vswhere = "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
}
if (-not (Test-Path $vswhere)) {
    Write-Error "vswhere.exe not found. Please install Visual Studio (any edition)."
    exit 1
}

$vsPath = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath

if (-not $vsPath) {
    Write-Error "No Visual Studio with C++ tools (VC.Tools.x86.x64) found."
    exit 1
}

$vcvarsall = Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
if (-not (Test-Path $vcvarsall)) {
    Write-Error "vcvarsall.bat not found at: $vcvarsall"
    exit 1
}

Write-Host "Using MSVC from: $vsPath"

# Run vcvarsall, capture every env var it produces, apply them to this process.
$envOutput = cmd /c "`"$vcvarsall`" x64 >nul 2>&1 && set"
foreach ($line in $envOutput) {
    if ($line -match '^([^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
}

& cmake @args
exit $LASTEXITCODE
