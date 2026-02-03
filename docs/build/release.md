# DesktopUI Release Guide

This guide explains how to create distributable releases of DesktopUI applications with bundled SDL2 dependencies.

## Overview

DesktopUI applications require SDL2 libraries to be available at runtime. This guide shows how to bundle SDL2 with your application for distribution.

## Platform-Specific Requirements

| Platform | SDL2 File Required | Location |
|----------|-------------------|----------|
| Windows | `SDL2.dll` | `lib/x64/` or `lib/x86/` |
| Linux | `libSDL2-2.0.so.0` | `lib/x86_64-linux-gnu/` or similar |
| macOS | `libSDL2-2.0.dylib` | `lib/` |

## Directory Structure

A properly structured DesktopUI release looks like:

```
your_app/
├── bin/
│   └── your_app           # Main executable/script
├── priv/
│   └── desktop_ui_nif.dll # NIF library
├── lib/
│   └── SDL2.dll           # SDL2 library (Windows)
│   └── libSDL2-2.0.so.0   # SDL2 library (Linux)
│   └── libSDL2-2.0.dylib  # SDL2 library (macOS)
├── releases/
│   └── your_app.tar.gz    # Distribution package
└── README.md
```

## Building Releases

### Windows

#### 1. Build the NIF

```powershell
# Ensure MSYS2/MinGW is in PATH
$env:PATH = "C:\msys64\mingw64\bin;$env:PATH"

# Build the NIF
mix compile.desktop_ui_nif
```

#### 2. Create Release Directory

```powershell
# Create release structure
New-Item -ItemType Directory -Force -Path "release/bin"
New-Item -ItemType Directory -Force -Path "release/priv"
New-Item -ItemType Directory -Force -Path "release/lib"

# Copy NIF
Copy-Item "_build/dev/lib/desktop_ui/priv/desktop_ui_nif.dll" "release/priv/"

# Copy SDL2 DLL
Copy-Item "C:\SDL2-2.30.11\lib\x64\SDL2.dll" "release/lib/"

# Create startup script that sets PATH
@"
@echo off
setlocal
set PATH=%~dp0lib;%PATH%
elixir -e "System.halt(0)" -e "File.cd!('" + (Resolve-Path .).Path + "')" -e "Mix.start()" -e "Mix.Task.run('run', ['run_counter.exs'])"
"@ | Out-File -Encoding ASCII "release/bin/your_app.bat"

# Or use a launcher script
@"
`$env:PATH = Join-Path `$PSScriptRoot "lib" + ";" + `$env:PATH
Set-Location `$PSScriptRoot
mix run run_counter.exs
"@ | Out-File -Encoding UTF8 "release/bin/your_app.ps1"
```

#### 3. Create Distribution Package

```powershell
# Create ZIP archive
Compress-Archive -Path "release/*" -DestinationPath "releases/your_app-windows-x64.zip"
```

### Linux

#### 1. Build the NIF

```bash
# Ensure SDL2 dev libraries are installed
sudo apt-get install libsdl2-dev

# Build the NIF
mix compile.desktop_ui_nif
```

#### 2. Create Release Directory

```bash
# Create release structure
mkdir -p release/{bin,priv,lib}

# Copy NIF
cp _build/dev/lib/desktop_ui/priv/desktop_ui_nif.so release/priv/

# Copy SDL2 library
cp /usr/lib/x86_64-linux-gnu/libSDL2-2.0.so.0 release/lib/

# Create startup script
cat > release/bin/your_app <<'EOF'
#!/bin/bash
# Set library path
export LD_LIBRARY_PATH="$(dirname "$0")/../lib:$LD_LIBRARY_PATH"
cd "$(dirname "$0")/.."
mix run run_counter.exs
EOF

chmod +x release/bin/your_app
```

#### 3. Create Distribution Package

```bash
# Create tar.gz archive
tar czf releases/your_app-linux-x64.tar.gz -C release .
```

### macOS

#### 1. Build the NIF

```bash
# Ensure SDL2 is installed via Homebrew
brew install sdl2

# Build the NIF
mix compile.desktop_ui_nif
```

#### 2. Create Release Directory

```bash
# Create release structure
mkdir -p release/{bin,priv,lib}

# Copy NIF
cp _build/dev/lib/desktop_ui/priv/desktop_ui_nif.dylib release/priv/

# Copy SDL2 library
cp $(brew --prefix sdl2)/lib/libSDL2-2.0.dylib release/lib/

# Update SDL2 library install name to use @rpath
install_name_tool -id @rpath/libSDL2-2.0.dylib release/lib/libSDL2-2.0.dylib

# Create startup script
cat > release/bin/your_app <<'EOF'
#!/bin/bash
# Set library path
export DYLD_LIBRARY_PATH="$(dirname "$0")/../lib:$DYLD_LIBRARY_PATH"
cd "$(dirname "$0")/.."
mix run run_counter.exs
EOF

chmod +x release/bin/your_app
```

#### 3. Create Distribution Package

```bash
# Create tar.gz archive
tar czf releases/your_app-macos-universal.tar.gz -C release .
```

## Release Build Script

### Windows (`release.ps1`)

```powershell
#!/usr/bin/env pwsh
# DesktopUI Release Builder for Windows

$ErrorActionPreference = "Stop"

# Configuration
$AppName = "desktop_ui_app"
$SDL2Path = "C:\SDL2-2.30.11"
$ReleaseDir = "release"
$DistDir = "releases"

Write-Host "=== DesktopUI Release Builder ===" -ForegroundColor Cyan

# Clean previous release
Remove-Item -Recurse -Force $ReleaseDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "$ReleaseDir/bin"
New-Item -ItemType Directory -Force -Path "$ReleaseDir/priv"
New-Item -ItemType Directory -Force -Path "$ReleaseDir/lib"

# Build NIF
Write-Host "Building NIF..." -ForegroundColor Yellow
mix compile.desktop_ui_nif

# Copy NIF
Write-Host "Copying NIF..." -ForegroundColor Yellow
Copy-Item "_build/dev/lib/desktop_ui/priv/desktop_ui_nif.dll" "$ReleaseDir/priv/"

# Copy SDL2
Write-Host "Copying SDL2..." -ForegroundColor Yellow
Copy-Item "$SDL2Path/lib/x64/SDL2.dll" "$ReleaseDir/lib/"

# Create launcher script
Write-Host "Creating launcher..." -ForegroundColor Yellow
$LauncherScript = @"
# DesktopUI Application Launcher
`$env:PATH = Join-Path `$PSScriptRoot "lib" + ";" + `$env:PATH
Set-Location `$PSScriptRoot
mix run run_counter.exs
"@
$LauncherScript | Out-File -Encoding UTF8 "$ReleaseDir/bin/$AppName.ps1"

# Create distribution package
Write-Host "Creating distribution package..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $DistDir
$Version = (Select-String -Path "mix.exs" -Pattern "version:").ToString() -replace '.*version: "(.*?)".*', '$1'
$ZipFile = "$DistDir/${AppName}_${Version}_windows-x64.zip"
Compress-Archive -Path "$ReleaseDir/*" -DestinationPath $ZipFile

Write-Host "Release created: $ZipFile" -ForegroundColor Green
```

### Unix (`release.sh`)

```bash
#!/usr/bin/env bash
# DesktopUI Release Builder for Unix (Linux/macOS)

set -euo pipefail

# Configuration
APP_NAME="desktop_ui_app"
RELEASE_DIR="release"
DIST_DIR="releases"

echo "=== DesktopUI Release Builder ==="

# Clean previous release
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"/{bin,priv,lib}

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    SDL2_PATH="$(brew --prefix sdl2)"
    LIB_EXT="dylib"
else
    PLATFORM="linux"
    SDL2_PATH="/usr/local"
    LIB_EXT="so.0"
fi

# Build NIF
echo "Building NIF..."
mix compile.desktop_ui_nif

# Copy NIF
echo "Copying NIF..."
cp "_build/dev/lib/desktop_ui/priv/desktop_ui_nif.$LIB_EXT" "$RELEASE_DIR/priv/"

# Copy SDL2
echo "Copying SDL2..."
cp "$SDL2_PATH/lib/libSDL2-2.0.$LIB_EXT" "$RELEASE_DIR/lib/"

# Create launcher script
echo "Creating launcher..."
cat > "$RELEASE_DIR/bin/$APP_NAME" <<'EOF'
#!/bin/bash
# DesktopUI Application Launcher

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Set library path
if [[ "$OSTYPE" == "darwin"* ]]; then
    export DYLD_LIBRARY_PATH="$SCRIPT_DIR/../lib:$DYLD_LIBRARY_PATH"
else
    export LD_LIBRARY_PATH="$SCRIPT_DIR/../lib:$LD_LIBRARY_PATH"
fi

cd "$SCRIPT_DIR/.."
exec mix run run_counter.exs
EOF

chmod +x "$RELEASE_DIR/bin/$APP_NAME"

# Create distribution package
echo "Creating distribution package..."
mkdir -p "$DIST_DIR"
VERSION=$(grep "version:" mix.exs | sed 's/.*version: "\(.*\)".*/\1/')
ARCHIVE_FILE="$DIST_DIR/${APP_NAME}_${VERSION}_${PLATFORM}-$(uname -m).tar.gz"
tar czf "$ARCHIVE_FILE" -C "$RELEASE_DIR" .

echo "Release created: $ARCHIVE_FILE"
```

## Using Releases

### End User Instructions

**Windows:**
```powershell
# Extract ZIP
Expand-Archive -Path your_app-windows-x64.zip -DestinationPath .

# Run application
.\bin\your_app.ps1
```

**Linux/macOS:**
```bash
# Extract archive
tar xzf your_app-linux-x64.tar.gz
cd release

# Run application
./bin/your_app
```

## Automation

### GitHub Actions Example

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [windows-latest, ubuntu-latest, macos-latest]
        include:
          - os: windows-latest
            platform: windows
            ext: zip
          - os: ubuntu-latest
            platform: linux
            ext: tar.gz
          - os: macos-latest
            platform: macos
            ext: tar.gz

    steps:
      - uses: actions/checkout@v3

      - name: Install Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18'
          otp-version: '27'

      - name: Install SDL2 (Ubuntu)
        if: matrix.os == 'ubuntu-latest'
        run: sudo apt-get install -y libsdl2-dev

      - name: Install SDL2 (macOS)
        if: matrix.os == 'macos-latest'
        run: brew install sdl2

      - name: Install SDL2 (Windows)
        if: matrix.os == 'windows-latest'
        run: |
          Invoke-WebRequest -Uri "https://github.com/libsdl-org/SDL/releases/download/release-2.30.11/SDL2-devel-2.30.11-VC.zip" -OutFile "SDL2.zip"
          Expand-Archive -Path "SDL2.zip" -DestinationPath "C:\"
          $env:SDL2_PATH = "C:\SDL2-2.30.11"

      - name: Build Release
        run: mix release

      - name: Create Archive
        run: |
          if [ "${{ matrix.os }}" = "windows-latest" ]; then
            Compress-Archive -Path "release/*" -DestinationPath "dist.${{ matrix.ext }}"
          else
            tar czf "dist.${{ matrix.ext }}" -C release .
          fi

      - name: Upload Release
        uses: actions/upload-artifact@v3
        with:
          name: ${{ matrix.platform }}-release
          path: dist.${{ matrix.ext }}
```

## Advanced: Static Linking (Optional)

For a single standalone DLL without external SDL2 dependencies, you can statically link SDL2:

### Modify `c_src/Makefile`:

```makefile
# Add static linking flag
LDFLAGS += -static-libgcc -static-libstdc++
# Link against static SDL2
SDL2_LDFLAGS = -lSDL2main -lSDL2 -mwindows
```

### Important Notes

- **Licensing**: SDL2 uses the zlib license, which allows static linking but requires attribution
- **File Size**: Statically linked NIF will be larger (~2-3MB vs ~100KB)
- **Updates**: Must recompile NIF to update SDL2 version

Add this to your app's `README.md` or `ABOUT` dialog:

```
This application uses SDL2 (Simple DirectMedia Layer)
Copyright (C) 1997-2024 Sam Lantinga <slouken@libsdl.org>
https://www.libsdl.org/
```

## Troubleshooting

### Windows: "SDL2.dll not found"

**Cause:** SDL2.dll not in PATH

**Solution:**
1. Ensure SDL2.dll is in the `lib/` directory
2. Run via the provided launcher script
3. Or manually add to PATH:
   ```powershell
   $env:PATH = "C:\path\to\your\app\lib;$env:PATH"
   ```

### Linux: "libSDL2-2.0.so.0: cannot open shared object file"

**Cause:** Library not in LD_LIBRARY_PATH

**Solution:**
1. Use the provided launcher script
2. Or set manually:
   ```bash
   export LD_LIBRARY_PATH=/path/to/your/app/lib:$LD_LIBRARY_PATH
   ```

### macOS: "Library not loaded: @rpath/libSDL2-2.0.dylib"

**Cause:** Dylib not in DYLD_LIBRARY_PATH

**Solution:**
1. Use the provided launcher script
2. Or set manually:
   ```bash
   export DYLD_LIBRARY_PATH=/path/to/your/app/lib:$DYLD_LIBRARY_PATH
   ```

## Best Practices

1. **Version Your Releases**: Include version in archive filename
2. **Include README**: Add instructions for running the app
3. **Test on Clean System**: Verify release works on target system
4. **Check Dependencies**: Use `ldd` (Linux) or `Dependency Walker` (Windows) to verify
5. **Sign Your Code** (Optional): Code signing for Windows/macOS distribution
