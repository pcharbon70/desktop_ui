# DesktopUI Build Documentation

This directory contains comprehensive documentation for building DesktopUI across multiple platforms.

## Quick Links

- [Getting Started Guide](getting-started.md) - Start here for native builds
- [Cross-Compilation Guide](cross-compilation.md) - Build for other platforms
- [Platform Setup](platform-setup/) - Platform-specific prerequisites
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Compiler Reference](compiler-reference.md) - Environment variables and configuration
- [CI/CD Examples](ci-examples.md) - Automated build workflows

## Overview

DesktopUI uses a multi-platform build system based on Zig for cross-compilation. The build system supports:

- **Native Builds**: Linux, macOS, Windows
- **Cross-Compilation**: Build from any platform to any other platform
- **Multiple Compilers**: Zig (preferred), Makefile (fallback)
- **SDL2 Integration**: Automatic detection and linking

## Supported Platforms

| Platform | Architectures | Status |
|----------|--------------|--------|
| Linux | x86_64, aarch64, arm, riscv64 | Fully Supported |
| macOS | x86_64, aarch64 (Apple Silicon) | Fully Supported |
| Windows | x86_64, aarch64 | Fully Supported |

## Build System Architecture

```
┌─────────────────┐
│   mix compile   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  DesktopUiNif Compiler Task     │
│                                 │
│  1. Check DESKTOPUI_SKIP_NIF    │
│  2. Check DESKTOPUI_PREFER_COMPILER │
│  3. Detect platform & target    │
│  4. Find Zig or Makefile        │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────┐
│  Zig Compiler   │────▶│  Fallback    │
│  (preferred)    │     │  to Makefile │
└────────┬────────┘     └──────────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Native or Cross-Compile        │
│  to DESKTOPUI_TARGET            │
└─────────────────────────────────┘
```

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `DESKTOPUI_TARGET` | Cross-compilation target (e.g., `x86_64-windows-gnu`) | Native |
| `DESKTOPUI_PREFER_COMPILER` | Force Zig or Makefile (zig/makefile/none) | Auto-detect |
| `DESKTOPUI_SKIP_NIF` | Skip NIF compilation | (not set) |

See [Compiler Reference](compiler-reference.md) for details.

## Getting Help

- Check the [Troubleshooting Guide](troubleshooting.md) for common issues
- See test files in `test/mix/tasks/compile/` for examples
- Open an issue on GitHub for build problems
