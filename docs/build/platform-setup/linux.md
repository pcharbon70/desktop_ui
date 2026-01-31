# Linux Setup Guide

This guide covers setting up the DesktopUI build environment on Linux.

## Supported Distributions

DesktopUI is tested on and supports:
- Ubuntu 20.04, 22.04, 24.04
- Debian 11, 12
- Fedora 38, 39, 40
- Arch Linux
- Other major distributions with glibc 2.17+

## Prerequisites

### Base Requirements

- **Elixir** >= 1.18 with OTP 27
- **Erlang/OTP** 27
- **Build tools** (gcc or clang)
- **SDL2** development libraries

### Installing Elixir/Erlang

#### Ubuntu/Debian

```bash
# Add Erlang Solutions repository
wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc
sudo apt-key add erlang_solutions.asc
sudo apt install -y esl-erlang elixir

# Or use asdf for version management
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 27.0
asdf install elixir 1.18.0
asdf global erlang 27.0
asdf global elixir 1.18.0
```

#### Fedora

```bash
sudo dnf install erlang elixir
```

#### Arch Linux

```bash
sudo pacman -S erlang elixir
```

### Installing Build Tools

#### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y build-essential
```

#### Fedora

```bash
sudo dnf install gcc make
```

#### Arch Linux

```bash
sudo pacman -S base-devel
```

### Installing SDL2

SDL2 is required for graphics and input handling.

#### Ubuntu/Debian

```bash
sudo apt-get install -y libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev
```

#### Fedora

```bash
sudo dnf install SDL2-devel SDL2_image-devel SDL2_ttf-devel
```

#### Arch Linux

```bash
sudo pacman -S sdl2 sdl2_image sdl2_ttf
```

### Optional: Installing Zig

Zig is recommended for cross-compilation and faster builds.

#### Ubuntu/Debian

```bash
# Download from https://ziglang.org/download/
# Or use snap (may not be latest version)
sudo snap install zig --classic

# Or install via apt (if available in your repository)
sudo apt install zig
```

#### Fedora

```bash
sudo dnf install zig
```

#### Arch Linux

```bash
sudo pacman -S zig
```

#### Manual Installation

```bash
# Download latest Zig
wget https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz
tar xf zig-linux-x86_64-0.11.0.tar.xz
sudo mv zig-linux-x86_64-0.11.0 /opt/zig
echo 'export PATH=$PATH:/opt/zig' >> ~/.bashrc
source ~/.bashrc

# Verify
zig version
```

## Verifying Installation

```bash
# Check Erlang/Elixir
erl -version
elixir --version

# Check GCC
gcc --version

# Check SDL2
sdl2-config --version

# Check Zig (if installed)
zig version
```

## Building DesktopUI

```bash
# Clone repository
git clone https://github.com/yourusername/desktop_ui.git
cd desktop_ui

# Fetch dependencies
mix deps.get

# Build
mix compile

# Run tests
mix test
```

## Distribution-Specific Notes

### Ubuntu 20.04 (Focal)

Older GCC version may cause issues. Consider:

```bash
# Install newer GCC
sudo add-apt-repository ppa:ubuntu-toolchain-r/test
sudo apt-get update
sudo apt-get install gcc-11 g++-11
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100
```

### Debian

You may need to enable backports for newer packages:

```bash
# Add backports repository
sudo apt-add-repository non-free contrib
```

### Fedora

SELinux may interfere with NIF loading. If you have issues:

```bash
# Check SELinux status
getenforce

# Temporary disable for testing (not recommended for production)
sudo setenforce 0
```

### Arch Linux

Keep your system updated for best compatibility:

```bash
sudo pacman -Syu
```

## Architecture-Specific Notes

### x86_64 (AMD64)

Most common desktop/server architecture. All instructions above apply.

### ARM64 (aarch64)

Common on ARM servers and Raspberry Pi 4+:

```bash
# On ARM64 Ubuntu/Debian
sudo apt-get install -y build-essential libsdl2-dev
```

### ARMv6/ARMv7 (Raspberry Pi 3 and older)

Use ARMv6/ARMv7 specific repositories:

```bash
# On Raspberry Pi OS
sudo apt-get update
sudo apt-get install -y build-essential libsdl2-dev
```

## Performance Tips

### Use Zig for Faster Builds

```bash
export DESKTOPUI_PREFER_COMPILER=zig
mix compile
```

### Parallel Compilation

Mix automatically parallelizes compilation. For larger projects:

```bash
export MIX_BUILDembed=1
mix compile
```

### CCache for Makefile Builds

If using Makefile compiler, enable ccache:

```bash
sudo apt-get install ccache
export CC="ccache gcc"
export CXX="ccache g++"
mix compile
```

## Troubleshooting

### "SDL2 not found"

```bash
# Check if SDL2 is installed
sdl2-config --cflags

# Install if missing
sudo apt-get install libsdl2-dev
```

### "Cannot find -lSDL2"

Make sure SDL2 development libraries are installed, not just runtime:

```bash
# Correct: development package
sudo apt-get install libsdl2-dev

# Wrong: runtime only
sudo apt-get install libsdl2-2.0-0
```

### NIF Loading Error

If you get "dlopen: cannot open shared object":

```bash
# Check library dependencies
ldd priv/desktop_ui_nif.so

# Install missing dependencies
sudo apt-get install libstdc++6
```

## Getting Help

- [Troubleshooting Guide](../troubleshooting.md)
- [Cross-Compilation Guide](../cross-compilation.md)
- Report issues on GitHub
