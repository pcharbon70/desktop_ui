# Windows Setup Guide

This guide covers setting up the DesktopUI build environment on Windows.

## Recommendation: Use WSL2

**For the best development experience on Windows, we recommend using WSL2 (Windows Subsystem for Linux).** WSL2 provides a native Linux environment on Windows with full compatibility with the DesktopUI build system.

See the [WSL2 Setup](#wsl2-setup) section below.

## Native Windows Support

Native Windows builds are supported but may require additional setup. See [Native Windows Setup](#native-windows-setup) below.

## WSL2 Setup (Recommended)

### Prerequisites

- Windows 11 or Windows 10 (version 2004+)
- Administrator access

### Installation

```powershell
# Open PowerShell as Administrator

# Enable WSL
wsl --install

# Restart your computer when prompted

# After restart, WSL will install Ubuntu by default
```

### Post-Installation

Once in WSL2 Ubuntu:

```bash
# Update packages
sudo apt-get update && sudo apt-get upgrade -y

# Follow Linux setup guide
# See: [Linux Setup Guide](linux.md)
```

### Recommended WSL2 Configuration

```bash
# Set WSL version to 2
wsl --set-default-version 2

# Install additional build tools
sudo apt-get install -y build-essential libsdl2-dev

# Install Elixir/Erlang via asdf
. <(curl -s https://raw.githubusercontent.com/asdf-vm/asdf/master/asdf.sh)
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 27.0
asdf install elixir 1.18.0
asdf global erlang 27.0
asdf global elixir 1.18.0
```

### Accessing Windows Files from WSL2

Windows files are accessible under `/mnt/c/`:

```bash
cd /mnt/c/Users/YourName/Projects/desktop_ui
```

### Performance Tips

- Store project files in WSL2 filesystem (`~/`) for better performance
- Access Windows files via `/mnt/c/` when needed (slower)
- Use WSL2 GPU drivers for graphics acceleration

## Native Windows Setup

Native Windows builds are supported using MinGW or Visual Studio.

### Prerequisites

- Windows 10 or 11
- Elixir >= 1.18 with OTP 27
- Build tools (MSYS2/MinGW or Visual Studio)
- SDL2 libraries
- Zig >= 0.11.0 (recommended for cross-compilation)

### Installing Elixir/Erlang

#### Option 1: Chocolatey

```powershell
# Install Chocolatey if not already installed
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Erlang and Elixir
choco install erlang elixir
```

#### Option 2: Manual Installation

1. Download Erlang/OTP from https://erlang.org/download.html
2. Download Elixir from https://elixir-lang.org/install.html
3. Install both to default locations
4. Add to PATH:
   - `C:\Program Files\erl-27.0\bin`
   - `C:\Program Files\Elixir\bin`

### Installing Build Tools

#### Option 1: MSYS2 (Recommended)

```powershell
# Download MSYS2 installer from https://www.msys2.org/

# During installation, choose "Run MSYS2 from terminal"

# After installation, open MSYS2 MinGW 64-bit terminal

# Update packages
pacman -Syu

# Install build tools
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-x86_64-pkg-config

# Install SDL2
pacman -S mingw-w64-x86_64-SDL2

# Add to PATH (replace with your paths)
# C:\msys64\mingw64\bin
```

#### Option 2: Visual Studio

```powershell
# Install Visual Studio 2019 or later with C++ tools
# Download from https://visualstudio.microsoft.com/

# During installation, select:
# - Desktop development with C++
# - C++ CMake tools for Visual Studio
```

### Installing Zig

Zig is highly recommended for Windows:

```powershell
# Download from https://ziglang.org/download/
# Choose zig-windows-x86_64 version

# Extract to C:\zig
# Add C:\zig to PATH
```

Or using Chocolatey:

```powershell
choco install zig
```

### Installing SDL2 (Native)

#### Automated Method (Recommended for build.ps1)

The `build.ps1` script expects SDL2 at `C:\SDL2-2.30.11`. To install:

1. Download SDL2 development libraries from https://github.com/libsdl-org/SDL/releases/download/release-2.30.11/SDL2-devel-2.30.11-VC.zip
2. Extract to `C:\SDL2-2.30.11`
3. The build script will automatically detect and use this location

**Or use the provided installation script:**
```powershell
# From the project root
.\install_sdl2.ps1
```

#### MSYS2 Method

```bash
# In MSYS2 MinGW 64-bit terminal
pacman -S mingw-w64-x86_64-SDL2
```

Then create a symlink or copy to the expected location:
```powershell
# If using MSYS2 SDL2, create a junction/link
mklink /D C:\SDL2-2.30.11 C:\msys64\mingw64\include\SDL2
```

#### Manual Method

1. Download SDL2 development libraries from https://github.com/libsdl-org/SDL/releases
2. Extract to a known location (e.g., `C:\SDL2`)
3. Set environment variables:

```powershell
# Add to System Environment Variables
$env:SDL2_DIR = "C:\SDL2"
$env:PATH += ";C:\SDL2\lib\x64"
```

## Building DesktopUI on Windows

### Using WSL2 (Recommended)

```bash
# In WSL2 terminal
cd ~/desktop_ui
mix deps.get
mix compile
mix test
```

### Native Windows Build with build.ps1 (Recommended)

The `build.ps1` script provides automated build support for Windows, handling MSYS2/MinGW detection, SDL2 configuration, and NIF compilation.

```powershell
# Navigate to project
cd C:\path\to\desktop_ui

# Run the build script (automated)
.\build.ps1
```

**What the build script does:**
1. Detects MSYS2/MinGW at `C:\msys64\mingw64\bin` (adds to PATH automatically)
2. Detects SDL2 at `C:\SDL2-2.30.11` (or other standard locations)
3. Sets `DESKTOPUI_TARGET=x86_64-windows-gnu` for Windows
4. Passes SDL2_CFLAGS and SDL2_LDFLAGS to the Makefile
5. Compiles the NIF using mingw32-make
6. Outputs NIF to `priv/desktop_ui_nif.dll`

### Native Windows Build (Manual)

```powershell
# In Command Prompt or PowerShell

# Navigate to project
cd C:\path\to\desktop_ui

# Add MSYS2/MinGW to PATH
$env:PATH = "C:\msys64\mingw64\bin;$env:PATH"

# Fetch dependencies
mix deps.get

# Set target and SDL2 flags
$env:DESKTOPUI_TARGET = "x86_64-windows-gnu"
$env:SDL2_CFLAGS = "-I\C:\SDL2-2.30.11\include"
$env:SDL2_LDFLAGS = "-L\C:\SDL2-2.30.11\lib\x64 -lSDL2main -lSDL2"

# Build
mix compile

# Run tests (skip NIF recompilation)
$env:DESKTOPUI_SKIP_NIF = "1"
mix test
```

### Running Tests on Windows

After building with `build.ps1`, run tests with:

```powershell
# Skip NIF recompilation (uses already-built DLL)
DESKTOPUI_SKIP_NIF=1 mix test
```

### Cross-Compilation from WSL2 to Windows

From WSL2, you can build Windows binaries:

```bash
# In WSL2
export DESKTOPUI_TARGET=x86_64-windows-gnu
mix compile
```

## Environment Variables on Windows

### PowerShell

```powershell
# Set environment variables for current session
$env:DESKTOPUI_TARGET="x86_64-windows-gnu"
$env:DESKTOPUI_PREFER_COMPILER="zig"

# Permanent: set in System Properties
```

### Command Prompt

```cmd
REM Set for current session
set DESKTOPUI_TARGET=x86_64-windows-gnu
set DESKTOPUI_PREFER_COMPILER=zig

REM Permanent: use setx
setx DESKTOPUI_TARGET "x86_64-windows-gnu"
```

## Common Issues

### "mix: command not found"

Add Elixir to PATH and restart terminal:

```powershell
# Add to PATH (adjust paths as needed)
$env:Path += ";C:\Program Files\Elixir\bin"
```

### "SDL2 not found"

Install SDL2 via MSYS2 or manual installation (see above).

### "Cannot open shared object"

Make sure SDL2 DLL is in PATH:

```powershell
# Add SDL2 bin directory to PATH
$env:Path += ";C:\SDL2\lib\x64"
```

### "zig: command not found"

Add Zig to PATH or install via Chocolatey:

```powershell
choco install zig
```

### WSL2 File System Issues

For best performance, work within WSL2 filesystem:

```bash
# Good: WSL2 filesystem
cd ~/desktop_ui

# Slower: Windows filesystem via /mnt
cd /mnt/c/Users/YourName/desktop_ui
```

## Windows Terminal (Recommended)

For the best terminal experience on Windows:

1. Install Windows Terminal from Microsoft Store
2. Configure WSL2 profile
3. Set as default terminal

```json
// Example settings.json profile
{
    "guid": "{...}",
    "name": "Ubuntu",
    "source": "Windows.Terminal.Wsl",
    "startingDirectory": "//wsl$/Ubuntu/home/yourusername"
}
```

## Git Configuration

Recommended Git configuration for Windows:

```bash
# In WSL2 or Git Bash

# Handle line endings
git config --global core.autocrlf input

# Use SSH for GitHub
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

## Performance Tips

### Use WSL2 for Development

WSL2 provides near-native Linux performance:

```bash
# All commands in WSL2
mix deps.get
mix compile
mix test
```

### Parallel Builds

Mix automatically parallelizes builds.

### Antivirus Exclusions

Add project directories to Windows Defender exclusions for faster builds:

```
C:\Users\YourName\source\desktop_ui
C:\msys64
C:\zig
```

## Getting Help

- [Troubleshooting Guide](../troubleshooting.md)
- [Linux Setup Guide](linux.md) - For WSL2 setup
- [Cross-Compilation Guide](../cross-compilation.md)
- Report issues on GitHub

## Summary

**For most users:**
1. Install WSL2
2. Follow Linux setup guide in WSL2
3. Enjoy native Linux development experience on Windows

**For native Windows builds:**
1. Install MSYS2 or Visual Studio
2. Install Elixir/Erlang
3. Install SDL2 libraries
4. Optionally install Zig for cross-compilation
