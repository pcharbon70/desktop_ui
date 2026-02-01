# Getting Started Guide

This guide will help you build DesktopUI on your local machine.

## Prerequisites

### Required for All Platforms

- **Elixir** >= 1.18 with OTP 27
- **Erlang/OTP** 27
- **Git** for cloning the repository

### Platform-Specific Requirements

#### Linux

- **GCC** or **Clang** for system libraries
- **SDL2** development libraries: `libsdl2-dev`
- **Zig** (recommended) >= 0.11.0 (optional, see [Compiler Options](#compiler-options))

```bash
# Ubuntu/Debian
sudo apt-get install build-essential libsdl2-dev

# Fedora
sudo dnf install gcc SDL2-devel

# Arch Linux
sudo pacman -S base-devel sdl2
```

#### macOS

- **Xcode Command Line Tools**
- **Zig** (recommended) >= 0.11.0 (optional)

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install SDL2 via Homebrew
brew install sdl2
```

#### Windows (WSL2)

**Note**: Native Windows builds are supported, but WSL2 is recommended for development.

- **Windows 11** with WSL2
- **Ubuntu** or other Linux distribution in WSL2
- Same prerequisites as Linux (see above)

For native Windows builds:
- **Visual Studio** 2019 or newer with C++ tools
- **MSYS2** for SDL2 libraries

### Optional: Install Zig

Zig is the recommended compiler for DesktopUI. It provides superior cross-compilation support.

```bash
# Linux/macOS
# Download from https://ziglang.org/download/
# Or use a package manager

# macOS (Homebrew)
brew install zig

# Arch Linux
pacman -S zig

# Verify installation
zig version
```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/desktop_ui.git
cd desktop_ui
```

### 2. Fetch Dependencies

```bash
mix deps.get
```

### 3. Build the NIF

```bash
# Standard build (auto-detects Zig or Makefile)
mix compile

# Or explicitly specify Zig
DESKTOPUI_PREFER_COMPILER=zig mix compile
```

### 4. Run Tests

```bash
# Run all tests
mix test

# Run only unit tests
mix test test/lib/

# Run only integration tests
mix test test/mix/tasks/compile/
```

## Compiler Options

The DesktopUI build system supports multiple compilation strategies:

### Option 1: Zig (Recommended)

```bash
# Set Zig as preferred compiler
export DESKTOPUI_PREFER_COMPILER=zig
mix compile
```

**Advantages:**
- Superior cross-compilation support
- Faster compilation times
- Better error messages
- Built-in C library integration

### Option 2: Makefile (Fallback)

```bash
# Use traditional Makefile
export DESKTOPUI_PREFER_COMPILER=makefile
mix compile
```

**Advantages:**
- Uses system compiler (gcc/clang)
- No additional dependencies
- Familiar build process

### Option 3: Auto-Detect (Default)

```bash
# No environment variables needed
mix compile
```

The build system will automatically:
1. Check for Zig installation
2. Fall back to Makefile if Zig unavailable
3. Use native platform settings

## Environment Variables

### `DESKTOPUI_SKIP_NIF`

Skip NIF compilation (useful for quick development without C compilation):

```bash
DESKTOPUI_SKIP_NIF=1 mix compile
```

### `DESKTOPUI_PREFER_COMPILER`

Force a specific compiler:

```bash
export DESKTOPUI_PREFER_COMPILER=zig    # Use Zig
export DESKTOPUI_PREFER_COMPILER=makefile  # Use Makefile
export DESKTOPUI_PREFER_COMPILER=none    # Skip compilation
```

### `DESKTOPUI_TARGET`

Cross-compile to a different target:

```bash
# Build for Windows from Linux
export DESKTOPUI_TARGET=x86_64-windows-gnu
mix compile

# Build for macOS ARM64 from Linux
export DESKTOPUI_TARGET=aarch64-macos-none
mix compile
```

See [Cross-Compilation Guide](cross-compilation.md) for details.

## Verifying Your Build

After a successful build, verify the NIF is loaded:

```bash
# Start IEx
iex -S mix

# In IEx, check if NIF is loaded
iex> DesktopUI.Nif.info()
# Should return NIF information if loaded
```

## Next Steps

- [Cross-Compilation Guide](cross-compilation.md) - Build for other platforms
- [Platform Setup](platform-setup/) - Detailed platform-specific instructions
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Compiler Reference](compiler-reference.md) - Advanced configuration

## Common Issues

### "zig: command not found"

Either install Zig or use the Makefile compiler:

```bash
export DESKTOPUI_PREFER_COMPILER=makefile
mix compile
```

### "SDL2 not found"

Install SDL2 development libraries for your platform. See [Platform Setup](platform-setup/).

### "unsupported Erlang/OTP version"

Ensure you have Erlang/OTP 27 installed:

```bash
erl -version
```

## Development Workflow

For active development:

```bash
# 1. Make changes to C/NIF code
# 2. Clean and rebuild
mix clean
mix compile

# 3. Run tests
mix test

# 4. Or use IEx for interactive testing
iex -S mix
```

For faster development iteration, consider using `DESKTOPUI_SKIP_NIF=1` while working on pure Elixir code, then compile the NIF when ready.
