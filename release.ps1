#!/usr/bin/env pwsh
# DesktopUI Release Builder for Windows
#
# Builds distributable releases with bundled SDL2 dependencies

$ErrorActionPreference = "Stop"

# ============================================================================
# Configuration
# ============================================================================

$AppName = "desktop_ui"
$SDL2Path = if ($env:SDL2_PATH) { $env:SDL2_PATH } else { "C:\SDL2-2.30.11" }
$ReleaseDir = "release"
$DistDir = "releases"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Get-AppVersion {
    $content = Get-Content "mix.exs" -Raw
    if ($content -match 'version:\s*"([^"]+)"') {
        return $matches[1]
    }
    return "0.1.0"
}

# ============================================================================
# Main Script
# ============================================================================

Write-ColorOutput "=== DesktopUI Release Builder for Windows ===" "Cyan"
Write-Host ""

# Check SDL2 path
if (-not (Test-Path $SDL2Path)) {
    Write-ColorOutput "Error: SDL2 not found at: $SDL2Path" "Red"
    Write-ColorOutput "Please set SDL2_PATH environment variable or install SDL2 to: C:\SDL2-2.30.11" "Yellow"
    Write-Host ""
    Write-ColorOutput "Download SDL2 from: https://github.com/libsdl-org/SDL/releases" "Cyan"
    exit 1
}

Write-ColorOutput "SDL2 found at: $SDL2Path" "Green"
Write-Host ""

# Detect platform architecture
$Arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
Write-ColorOutput "Platform: Windows $Arch" "Green"
Write-Host ""

# Get version
$Version = Get-AppVersion
Write-ColorOutput "Version: $Version" "Green"
Write-Host ""

# Clean previous release
Write-ColorOutput "Cleaning previous release..." "Yellow"
Remove-Item -Recurse -Force $ReleaseDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$ReleaseDir/bin" | Out-Null
New-Item -ItemType Directory -Force -Path "$ReleaseDir/priv" | Out-Null
New-Item -ItemType Directory -Force -Path "$ReleaseDir/lib" | Out-Null

# Build NIF
Write-ColorOutput "Building NIF..." "Yellow"
mix compile.desktop_ui_nif
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "Error: NIF compilation failed" "Red"
    exit 1
}

# Copy NIF
Write-ColorOutput "Copying NIF..." "Yellow
$NifSource = "_build/dev/lib/desktop_ui/priv/desktop_ui_nif.dll"
if (-not (Test-Path $NifSource)) {
    Write-ColorOutput "Error: NIF not found at: $NifSource" "Red"
    exit 1
}
Copy-Item $NifSource "$ReleaseDir/priv/"
Write-ColorOutput "  ✓ NIF copied" "Green"

# Copy SDL2
Write-ColorOutput "Copying SDL2..." "Yellow"
$SDL2Dll = if ($Arch -eq "x64") {
    "$SDL2Path/lib/x64/SDL2.dll"
} else {
    "$SDL2Path/lib/x86/SDL2.dll"
}

if (-not (Test-Path $SDL2Dll)) {
    Write-ColorOutput "Error: SDL2.dll not found at: $SDL2Dll" "Red"
    exit 1
}
Copy-Item $SDL2Dll "$ReleaseDir/lib/"
Write-ColorOutput "  ✓ SDL2.dll copied" "Green"

# Create PowerShell launcher
Write-ColorOutput "Creating launcher scripts..." "Yellow"
$PsLauncher = @"
# DesktopUI $AppName Launcher
# This script sets up the environment and starts the application

`$ScriptPath = Split-Path -Parent `$MyInvocation.MyCommand.Path
`$env:PATH = Join-Path `$ScriptPath "..\lib" + ";" + `$env:PATH
Set-Location (Join-Path `$ScriptPath "..")

Write-Host "Starting DesktopUI $AppName..." -ForegroundColor Cyan
mix run run_counter.exs
"@
$PsLauncher | Out-File -Encoding UTF8 "$ReleaseDir/bin/$AppName.ps1"
Write-ColorOutput "  ✓ PowerShell launcher created" "Green"

# Create batch launcher
$BatLauncher = @"
@echo off
setlocal
set PATH=%~dp0..\lib;%PATH%
cd /d %~dp0..
mix run run_counter.exs
"@
$BatLauncher | Out-File -Encoding ASCII "$ReleaseDir/bin/$AppName.bat"
Write-ColorOutput "  ✓ Batch launcher created" "Green"

# Create README
Write-ColorOutput "Creating README..." "Yellow"
$Readme = @"
# DesktopUI $AppName v$Version

## Quick Start

### Windows (PowerShell)
```powershell
.\bin\$AppName.ps1
```

### Windows (Command Prompt)
```cmd
.\bin\$AppName.bat
```

## Directory Structure

```
$AppName/
├── bin/
│   ├── $AppName.ps1    # PowerShell launcher
│   └── $AppName.bat     # Batch launcher
├── priv/
│   └── desktop_ui_nif.dll  # NIF library
├── lib/
│   └── SDL2.dll        # SDL2 library
└── run_counter.exs     # Application script
```

## Requirements

- Windows 10 or later
- Elixir 1.18+ (for running from source)
- SDL2 libraries (included)

## Troubleshooting

If you see "SDL2.dll not found":
1. Make sure you're using the launcher scripts
2. Verify SDL2.dll exists in the `lib/` directory
3. Check Windows Defender isn't blocking the DLL

## Credits

This application uses SDL2 (Simple DirectMedia Layer)
Copyright (C) 1997-2024 Sam Lantinga <slouken@libsdl.org>
https://www.libsdl.org/
"@
$Readme | Out-File -Encoding UTF8 "$ReleaseDir/README.md"
Write-ColorOutput "  ✓ README created" "Green"

# Create distribution package
Write-ColorOutput "Creating distribution package..." "Yellow
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
$ZipFile = "$DistDir/${AppName}_v${Version}_windows-${Arch}.zip"

if (Test-Path $ZipFile) {
    Remove-Item $ZipFile
}

Compress-Archive -Path "$ReleaseDir/*" -DestinationPath $ZipFile
Write-ColorOutput "  ✓ Package created: $ZipFile" "Green"

# Summary
Write-Host ""
Write-ColorOutput "=== Release Complete ===" "Green"
Write-Host ""
Write-ColorOutput "Release created successfully!" "Green"
Write-Host ""
Write-ColorOutput "Location: $ReleaseDir" "Cyan"
Write-ColorOutput "Package:  $ZipFile" "Cyan"
Write-Host ""
Write-ColorOutput "To test the release:" "Yellow"
Write-Host "  1. Extract the ZIP file"
Write-Host "  2. Run: .\bin\$AppName.ps1"
Write-Host ""
