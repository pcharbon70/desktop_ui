# Cross-Compilation Guide

DesktopUI supports cross-compilation from any platform to any supported target using Zig's built-in cross-compilation capabilities.

## Overview

Cross-compilation allows you to build binaries for one platform while running on another. For example, you can build Windows binaries from Linux, or macOS ARM64 binaries from x86_64 Linux.

## Target Triple Format

Targets are specified using the format: `{arch}-{os}-{env}`

### Architecture (arch)

| Value | Description |
|-------|-------------|
| `x86_64` | 64-bit Intel/AMD |
| `aarch64` | 64-bit ARM (Apple Silicon, ARMv8+) |
| `arm64` | Alias for aarch64 |
| `arm` | 32-bit ARM |
| `x86` | 32-bit Intel/AMD |
| `riscv64` | 64-bit RISC-V |
| `riscv32` | 32-bit RISC-V |
| `mips64` | 64-bit MIPS |
| `mips` | 32-bit MIPS |

### Operating System (os)

| Value | Description |
|-------|-------------|
| `linux` | Linux |
| `macos` | macOS |
| `windows` | Windows |

### Environment (env)

| Value | Description |
|-------|-------------|
| `gnu` | GNU C library (Linux default) |
| `musl` | Musl C library (static linking friendly) |
| `none` | No C library (macOS, Windows) |

### Common Target Examples

```bash
x86_64-linux-gnu      # Linux x86_64 (most common)
aarch64-linux-gnu     # Linux ARM64 (Raspberry Pi 4+, ARM servers)
x86_64-macos-none     # macOS Intel
aarch64-macos-none    # macOS ARM64 (Apple Silicon M1/M2/M3)
x86_64-windows-gnu    # Windows x86_64 (MinGW)
aarch64-windows-gnu   # Windows ARM64
x86_64-linux-musl     # Linux x86_64 with musl (static linking)
```

## Setting the Target

Use the `DESKTOPUI_TARGET` environment variable:

```bash
# Build for Windows from Linux
export DESKTOPUI_TARGET=x86_64-windows-gnu
mix compile

# Build for macOS ARM64 from any platform
export DESKTOPUI_TARGET=aarch64-macos-none
mix compile

# Build for Linux ARM64
export DESKTOPUI_TARGET=aarch64-linux-gnu
mix compile
```

## Cross-Compilation Scenarios

### Linux → Windows

```bash
# From Linux, build for Windows
export DESKTOPUI_TARGET=x86_64-windows-gnu
mix compile
```

**Requirements:**
- Zig compiler (required for Windows cross-compilation)
- No additional Windows dependencies needed

**Output:**
- `priv/desktop_ui_nif.so` - Windows DLL (with .so extension, renamed for use)

### Linux → macOS

```bash
# Build for macOS Intel
export DESKTOPUI_TARGET=x86_64-macos-none
mix compile

# Build for macOS ARM64 (Apple Silicon)
export DESKTOPUI_TARGET=aarch64-macos-none
mix compile
```

**Requirements:**
- Zig compiler (required)
- macOS SDK (included with Zig)

**Note:** You cannot sign/notarize the binaries cross-compiled. For distribution, build on macOS hardware.

### Linux → ARM Linux (Raspberry Pi, etc.)

```bash
# Build for Raspberry Pi 4 (ARM64)
export DESKTOPUI_TARGET=aarch64-linux-gnu
mix compile

# Build for older Raspberry Pi (ARMv6)
export DESKTOPUI_TARGET=arm-linux-gnueabihf
mix compile
```

**Requirements:**
- Zig compiler
- Target device compatible ARM libraries

### macOS → Linux

```bash
# From macOS, build for Linux
export DESKTOPUI_TARGET=x86_64-linux-gnu
mix compile
```

**Requirements:**
- Zig compiler on macOS

### macOS → Windows

```bash
# From macOS, build for Windows
export DESKTOPUI_TARGET=x86_64-windows-gnu
mix compile
```

**Requirements:**
- Zig compiler on macOS

## SDL2 Cross-Compilation

SDL2 (Simple DirectMedia Layer) is a required dependency. The build system handles SDL2 automatically for cross-compilation:

### System SDL2 (Native Builds)

For native builds, the build system uses SDL2 from your system:

```bash
# No DESKTOPUI_TARGET set - uses system SDL2
mix compile
```

### Zig-Bundled SDL2 (Cross-Compilation)

For cross-compilation, Zig provides its own SDL2 libraries automatically:

```bash
# Cross-compile uses Zig's SDL2
export DESKTOPUI_TARGET=x86_64-windows-gnu
mix compile  # Uses Zig's bundled SDL2
```

## Verification

Verify cross-compiled binaries:

```bash
# Linux/macOS - use file command
file priv/desktop_ui_nif.so

# Expected output for Windows binary built from Linux:
# priv/desktop_ui_nif.so: PE32+ executable (DLL) x86-64, for MS Windows

# Expected output for ARM64 Linux:
# priv/desktop_ui_nif.so: ELF 64-bit LSB shared object, ARM aarch64
```

## Docker Cross-Compilation

For reliable cross-compilation, use Docker:

### Linux → Windows via Docker

```dockerfile
FROM ghcr.io/ziglang/zig:ubuntu-* AS builder

WORKDIR /app
COPY . .

RUN zig version
RUN mix deps.get
RUN export DESKTOPUI_TARGET=x86_64-windows-gnu && mix compile
```

### Linux Multi-Arch Build

```bash
# Build for multiple architectures
docker run --rm -v $(pwd):/app -w /app \
  ghcr.io/ziglang/zig:ubuntu-* \
  sh -c "export DESKTOPUI_TARGET=aarch64-linux-gnu && mix compile"
```

## CI/CD Integration

See [CI/CD Examples](ci-examples.md) for GitHub Actions workflows that handle cross-compilation automatically.

## Troubleshooting

### "Invalid target triple"

Check your target format:

```bash
# Correct format: arch-os-env
export DESKTOPUI_TARGET=x86_64-linux-gnu

# Incorrect: missing components
export DESKTOPUI_TARGET=x86_64-linux  # ERROR: needs 3 components
```

### "Unknown architecture"

Ensure the architecture is supported. See [Architecture](#architecture) table for valid values.

### Cross-compiled binary doesn't work on target

Common causes:

1. **Wrong target triple** - Double-check arch/os/env
2. **Incompatible libraries** - Some libraries may not support the target
3. **Runtime dependencies** - Static linking recommended (use `-musl` targets)

### Zig not found

Zig is **required** for cross-compilation:

```bash
# Install Zig
# macOS
brew install zig

# Linux
# Download from https://ziglang.org/download/
```

## Advanced: Static Linking

For truly portable binaries, use musl targets for static linking:

```bash
# Statically linked Linux binary
export DESKTOPUI_TARGET=x86_64-linux-musl
mix compile
```

This produces binaries that work on any Linux distribution without additional dependencies.

## Next Steps

- [Platform Setup](platform-setup/) - Platform-specific details
- [Troubleshooting](troubleshooting.md) - Common cross-compilation issues
- [CI/CD Examples](ci-examples.md) - Automated cross-compilation workflows
