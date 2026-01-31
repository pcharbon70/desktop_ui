# macOS Setup Guide

This guide covers setting up the DesktopUI build environment on macOS.

## Supported Versions

DesktopUI is tested on and supports:
- macOS 12 (Monterey)
- macOS 13 (Ventura)
- macOS 14 (Sonoma)
- macOS 15 (Sequoia)

Both Intel (x86_64) and Apple Silicon (aarch64/M1/M2/M3) Macs are supported.

## Prerequisites

### Base Requirements

- **Elixir** >= 1.18 with OTP 27
- **Erlang/OTP** 27
- **Xcode Command Line Tools**
- **SDL2** framework or library
- **Zig** >= 0.11.0 (recommended)

## Installing Xcode Command Line Tools

Required for system compiler and headers:

```bash
xcode-select --install
```

Accept the license agreement when prompted.

## Installing Elixir/Erlang

### Option 1: Homebrew (Recommended)

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Erlang and Elixir
brew install erlang elixir

# Verify installation
erl -version
elixir --version
```

### Option 2: asdf (Version Manager)

```bash
# Install asdf
brew install asdf

# Add to shell
echo -e "\n. \"$(brew --prefix asdf)/libexec/asdf.sh\"" >> ~/.zshrc
source ~/.zshrc

# Install Erlang and Elixir
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 27.0
asdf install elixir 1.18.0
asdf global erlang 27.0
asdf global elixir 1.18.0
```

### Option 3: Kerl/HexPM

```bash
# Install kerl (Erlang version manager)
brew install kerl

# Install Erlang 27
kerl build 27.0 27.0
kerl install 27.0
. kerl setup 27.0

# Install Elixir
mix local.hex --force
```

## Installing SDL2

SDL2 is required for graphics and input handling.

### Option 1: Homebrew (Recommended)

```bash
brew install sdl2
```

This installs SDL2 as a framework compatible library.

### Option 2: Manual Installation

```bash
# Download SDL2 framework
curl -O https://www.libsdl.org/release/SDL2-2.30.0.dmg

# Open and install to /Library/Frameworks
hdiutil attach SDL2-2.30.0.dmg
sudo cp -R /Volumes/SDL2/SDL2.framework /Library/Frameworks/
hdiutil detach /Volumes/SDL2
```

## Installing Zig

Zig is highly recommended for macOS builds, especially for cross-compilation.

```bash
brew install zig

# Verify installation
zig version
```

### Manual Installation

```bash
# Download latest Zig
curl -O https://ziglang.org/download/0.11.0/zig-macos-aarch64-0.11.0.tar.xz
# Or for Intel Macs:
curl -O https://ziglang.org/download/0.11.0/zig-macos-x86_64-0.11.0.tar.xz

# Extract
tar xf zig-macos-*.tar.xz
sudo mv zig-macos-* /opt/zig
echo 'export PATH=$PATH:/opt/zig' >> ~/.zshrc
source ~/.zshrc
```

## Rosetta 2 (Apple Silicon Macs)

If you're on an Apple Silicon Mac and need to build/run x86_64 binaries:

```bash
# Install Rosetta 2
softwareupdate --install-rosetta
```

## Building DesktopUI

```bash
# Clone repository
git clone https://github.com/yourusername/desktop_ui.git
cd desktop_ui

# Fetch dependencies
mix deps.get

# Build (uses Zig by default if installed)
mix compile

# Run tests
mix test
```

## Architecture-Specific Builds

### Apple Silicon (aarch64)

Default build on M1/M2/M3 Macs:

```bash
# No target needed - builds native ARM64
mix compile
```

### Intel (x86_64)

Default build on Intel Macs:

```bash
# No target needed - builds native x86_64
mix compile
```

### Cross-Compilation (Universal Binaries)

Build for both architectures:

```bash
# Build ARM64 version
export DESKTOPUI_TARGET=aarch64-macos-none
mix compile
mv priv/desktop_ui_nif.so priv/desktop_ui_nif.arm64.so

# Build x86_64 version
export DESKTOPUI_TARGET=x86_64-macos-none
mix compile
mv priv/desktop_ui_nif.so priv/desktop_ui_nif.x86_64.so

# Create universal binary
lipo -create -output priv/desktop_ui_nif.so \
  priv/desktop_ui_nif.arm64.so \
  priv/desktop_ui_nif.x86_64.so

# Verify
lipo -info priv/desktop_ui_nif.so
# Should show: Architectures in the fat file: desktop_ui_nif.so are: x86_64 arm64
```

## Code Signing (Optional)

For distribution outside of development:

```bash
# Ad-hoc signing (for local use)
codesign --force --deep -s - priv/desktop_ui_nif.so

# With developer certificate (for distribution)
codesign --force --deep --sign "Developer ID Application: Your Name" priv/desktop_ui_nif.so
```

## Verifying Installation

```bash
# Check Erlang/Elixir
erl -version
elixir --version

# Check Xcode tools
xcode-select -p

# Check Zig
zig version

# Check SDL2
brew list sdl2  # Homebrew installation
ls /Library/Frameworks/SDL2.framework  # Manual installation

# Verify NIF
file priv/desktop_ui_nif.so
# Should show: Mach-O 64-bit dynamically linked shared library arm64 or x86_64
```

## Common Issues

### "command not found: mix"

Add Elixir to your PATH or restart your terminal:

```bash
# Homebrew installation
export PATH=$PATH:/opt/homebrew/opt/elixir/bin

# Or restart terminal to apply shell changes
```

### "SDL2 not found"

```bash
# Check SDL2 installation
brew list sdl2

# Reinstall if needed
brew reinstall sdl2
```

### "Cannot allocate memory" during compilation

This can happen on systems with limited RAM. Close other applications or increase swap:

```bash
# Check available memory
vm_stat

# Consider using Makefile compiler instead of Zig
export DESKTOPUI_PREFER_COMPILER=makefile
mix compile
```

### "Apple Silicon" compatibility issues

Some tools may run under Rosetta. Check:

```bash
# Check architecture
uname -m

# Force arm64 for terminal
arch -arm64 zsh

# Then rebuild
mix clean
mix compile
```

## Performance Tips

### Use Zig for Native Performance

```bash
export DESKTOPUI_PREFER_COMPILER=zig
mix compile
```

### Optimized Builds

For release builds:

```bash
export MIX_ENV=prod
mix compile
```

### Parallel Compilation

Mix automatically parallelizes. For more control:

```bash
# Limit parallel jobs
export MIX_BUILDembed=1
mix compile
```

## Cross-Compilation from macOS

You can cross-compile from macOS to other platforms:

```bash
# Build for Linux
export DESKTOPUI_TARGET=x86_64-linux-gnu
mix compile

# Build for Windows
export DESKTOPUI_TARGET=x86_64-windows-gnu
mix compile
```

Note: You cannot code sign cross-compiled binaries. Use GitHub Actions or similar for distribution builds.

## Getting Help

- [Troubleshooting Guide](../troubleshooting.md)
- [Cross-Compilation Guide](../cross-compilation.md)
- Report issues on GitHub
