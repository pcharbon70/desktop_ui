#!/usr/bin/env pwsh
# SDL2 Setup Script for DesktopUI (Windows)
#
# This script copies SDL2.dll from your SDL2 installation to the project
# for development purposes.

$ErrorActionPreference = "Stop"

# Configuration
$SDL2Path = if ($env:SDL2_PATH) { $env:SDL2_PATH } else { "C:\SDL2-2.30.11" }
$TargetDir = "priv/sdl2"

Write-Host "=== DesktopUI SDL2 Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check SDL2 installation
if (-not (Test-Path $SDL2Path)) {
    Write-Host "SDL2 not found at: $SDL2Path" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "1. Download SDL2 from: https://github.com/libsdl-org/SDL/releases/tag/release-2.30.11"
    Write-Host "2. Extract to: C:\SDL2-2.30.11"
    Write-Host "3. Or set SDL2_PATH environment variable"
    Write-Host ""
    exit 1
}

Write-Host "SDL2 found at: $SDL2Path" -ForegroundColor Green
Write-Host ""

# Create target directory
Write-Host "Creating directory: $TargetDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

# Copy SDL2.dll
$SourceDll = "$SDL2Path/lib/x64/SDL2.dll"
if (Test-Path $SourceDll) {
    Write-Host "Copying SDL2.dll..." -ForegroundColor Yellow
    Copy-Item $SourceDll $TargetDir -Force
    Write-Host "✓ SDL2.dll copied to: $TargetDir" -ForegroundColor Green
} else {
    Write-Host "Error: SDL2.dll not found at: $SourceDll" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "SDL2 is now ready for DesktopUI development!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run the counter app with:" -ForegroundColor Yellow
Write-Host "  mix run run_counter.exs"
Write-Host ""
