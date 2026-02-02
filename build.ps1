# DesktopUI Build Script for Windows
# Handles the chicken-and-egg bootstrapping issue with the NIF compiler.

$ErrorActionPreference = "Stop"

# Helper function for colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "DesktopUI Build Script" "Cyan"
Write-Host ""

# Default compiler preference
$compiler = if ($env:DESKTOPUI_PREFER_COMPILER) { $env:DESKTOPUI_PREFER_COMPILER } else { "makefile" }

# Detect Zig
$zigFound = $false
try {
    $zigVersion = zig version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "  Zig found: $zigVersion" "Green"
        $zigFound = $true

        # Check for problematic Zig 0.15.2
        if ($zigVersion -match "0\.15\.2") {
            Write-ColorOutput "! Zig 0.15.2 has CacheCheckFailed issues, using Makefile" "Yellow"
            $compiler = "makefile"
        } else {
            $compiler = "zig"
        }
    }
} catch {
    Write-ColorOutput "! Zig not found or not working" "Yellow"
}

# Detect Make (could be mingw32-make, make, or gmake)
$makeFound = $false
$makeCmd = $null
foreach ($cmd in @("make", "mingw32-make", "gmake")) {
    try {
        $null = & $cmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  Make found: $cmd" "Green"
            $makeFound = $true
            $makeCmd = $cmd
            break
        }
    } catch {}
}

if (-not $makeFound) {
    Write-ColorOutput "  Make not found. Please install MSYS2/MinGW or Zig." "Yellow"
}

if (-not $zigFound -and -not $makeFound) {
    Write-ColorOutput "Error: Neither Zig nor Make found. Please install one." "Red"
    exit 1
}

Write-Host ""
Write-ColorOutput "Step 1: Compiling Elixir code (bootstrapping)..." "White"

# Step 1: Compile Elixir code without NIF
$env:DESKTOPUI_SKIP_NIF = "1"
mix compile

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "  Elixir compilation failed" "Red"
    exit 1
}

Write-ColorOutput "  Elixir code compiled" "Green"
Write-Host ""

# Determine NIF extension
$nifExt = ".dll"
if ($IsMacOS) { $nifExt = ".dylib" }
if ($IsLinux) { $nifExt = ".so" }

Write-ColorOutput "Step 2: Compiling NIF with $compiler..." "White"

# Step 2: Compile the NIF
$env:DESKTOPUI_SKIP_NIF = $null
$env:DESKTOPUI_PREFER_COMPILER = $compiler

# Check if we should use zig directly or via mix
if ($compiler -eq "zig" -and $zigFound) {
    # Try zig first
    mix compile.desktop_ui_nif
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "  Zig compilation failed, trying Makefile fallback..." "Yellow"
        $env:DESKTOPUI_PREFER_COMPILER = "makefile"
        if ($makeCmd) {
            # Direct make invocation as fallback
            $ertsInclude = erl -noshell -s init stop -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)])."
            $env:ERTS_INCLUDE_DIR = $ertsInclude
            & $makeCmd -f Makefile all
        } else {
            mix compile.desktop_ui_nif
        }
    }
} else {
    # Use makefile
    if ($makeCmd) {
        # Get ERTS include directory
        $ertsInclude = erl -noshell -s init stop -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)])."

        # Set environment variables for make
        $env:ERTS_INCLUDE_DIR = $ertsInclude
        $env:DESKTOPUI_TARGET = $null

        # Run make
        & $makeCmd -f Makefile all
    } else {
        mix compile.desktop_ui_nif
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "  NIF compilation failed" "Red"
    exit 1
}

Write-ColorOutput "  NIF compiled" "Green"
Write-Host ""

# Verify NIF exists
$nifFile = "priv/desktop_ui_nif$nifExt"
if (Test-Path $nifFile) {
    $size = (Get-Item $nifFile).Length
    $sizeKB = [math]::Round($size / 1KB, 2)
    Write-ColorOutput "  NIF created: $nifFile ($sizeKB KB)" "Green"
} else {
    Write-ColorOutput "  Warning: NIF file not found at $nifFile" "Yellow"
}

Write-Host ""
Write-ColorOutput "=== Build Complete ===" "Green"
Write-Host ""
Write-Host "You can now run:"
Write-Host "  mix test           # Run tests"
Write-Host "  mix run            # Start IEx"
Write-Host "  elixir run.exs     # Run the application"
