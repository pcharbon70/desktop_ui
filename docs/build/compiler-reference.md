# Compiler Reference

This reference describes all environment variables and compiler options for the DesktopUI build system.

## Environment Variables

### DESKTOPUI_TARGET

**Purpose:** Specify cross-compilation target

**Format:** `{arch}-{os}-{env}`

**Default:** Native platform

**Examples:**

```bash
# Native build (no variable)
mix compile

# Linux x86_64
export DESKTOPUI_TARGET=x86_64-linux-gnu

# Linux ARM64 (Raspberry Pi 4)
export DESKTOPUI_TARGET=aarch64-linux-gnu

# macOS Intel
export DESKTOPUI_TARGET=x86_64-macos-none

# macOS ARM64 (Apple Silicon)
export DESKTOPUI_TARGET=aarch64-macos-none

# Windows x86_64
export DESKTOPUI_TARGET=x86_64-windows-gnu

# Static linking (musl)
export DESKTOPUI_TARGET=x86_64-linux-musl
```

**See:** [Cross-Compilation Guide](cross-compilation.md)

---

### DESKTOPUI_PREFER_COMPILER

**Purpose:** Force specific compiler

**Values:**
- `zig` - Use Zig compiler (preferred)
- `makefile` - Use traditional Makefile with system compiler
- `none` - Skip compilation
- (unset) - Auto-detect (Zig → Makefile → Error)

**Default:** Auto-detect

**Examples:**

```bash
# Use Zig explicitly
export DESKTOPUI_PREFER_COMPILER=zig
mix compile

# Use Makefile explicitly
export DESKTOPUI_PREFER_COMPILER=makefile
mix compile

# Skip compilation
export DESKTOPUI_PREFER_COMPILER=none
mix compile
```

**Compiler Selection Flow:**

```
┌─────────────────────┐
│ Check PREFERENCE    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ If "none" → Skip compilation        │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ If "zig" → Try Zig, error if fail   │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ If "makefile" → Try make, error     │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ If unset → Auto-detect:             │
│   1. Try Zig if installed           │
│   2. Fall back to Makefile          │
│   3. Error if both unavailable      │
└─────────────────────────────────────┘
```

---

### DESKTOPUI_SKIP_NIF

**Purpose:** Skip NIF compilation entirely

**Values:**
- Any non-empty value = skip compilation
- (unset) = compile normally

**Default:** (not set)

**Examples:**

```bash
# Skip compilation
export DESKTOPUI_SKIP_NIF=1
mix compile

# Skip with any value
export DESKTOPUI_SKIP_NIF=true
mix compile

# Compile normally (unset or empty)
export DESKTOPUI_SKIP_NIF=
mix compile
```

**Use Cases:**
- Quick development on pure Elixir code
- CI environments without build tools
- Testing without native dependencies

## Compiler Comparison

### Zig Compiler

**Advantages:**
- Superior cross-compilation support
- Faster compilation times
- Better error messages
- Built-in C library integration
- Single toolchain for all platforms

**Disadvantages:**
- Additional installation required
- Newer toolchain (less mature)

**When to Use:**
- Cross-compilation (required)
- Faster builds desired
- Better error messages needed

**Minimum Version:** 0.11.0

### Makefile Compiler

**Advantages:**
- Uses system compiler (gcc/clang)
- No additional dependencies
- Familiar build process
- Widely available

**Disadvantages:**
- Poor cross-compilation support
- Slower compilation
- More complex error messages
- Platform-specific quirks

**When to Use:**
- Zig not available
- Native builds only
- System compiler integration needed

## Build Configuration

### Mix Compilation Modes

```bash
# Development build (default)
mix compile

# Production build
MIX_ENV=prod mix compile

# Test build
MIX_ENV=test mix compile
```

### Clean Build

```bash
# Remove build artifacts
mix clean

# Remove all artifacts including deps
mix clean --deps

# Rebuild after clean
mix clean && mix compile
```

## Build Artifacts

### Output Files

| File | Description |
|------|-------------|
| `priv/desktop_ui_nif.so` | NIF shared library (Linux/macOS) |
| `priv/desktop_ui_nif.dll` | NIF shared library (Windows, renamed from .so) |
| `_build/dev/lib/desktop_ui/` | Build metadata |
| `_build/dev/lib/desktop_ui/.compile.desktop_ui_nif` | Compiler manifest |

### Manifest Files

The compiler stores metadata in manifest files for incremental builds:

```bash
# View manifest
cat _build/dev/lib/desktop_ui/.compile.desktop_ui_nif

# Force rebuild by removing manifest
rm _build/dev/lib/desktop_ui/.compile.desktop_ui_nif
mix compile
```

## Performance Tuning

### Compilation Speed

```bash
# Use Zig (2-3x faster than Makefile)
export DESKTOPUI_PREFER_COMPILER=zig
mix compile

# Enable ccache for Makefile
export CC="ccache gcc"
export CXX="ccache g++"
```

### Binary Size

```bash
# Production builds are smaller
MIX_ENV=prod mix compile

# Strip symbols (after build)
strip priv/desktop_ui_nif.so  # Linux
strip -x priv/desktop_ui_nif.so  # macOS
```

## Advanced Options

### Custom Compiler Flags

**Note:** DesktopUI doesn't currently support custom compiler flags via environment variables. Use the Makefile directly for advanced options:

```bash
# Direct make invocation with custom flags
cd c_src
make CC=clang CFLAGS="-O3 -march=native"
```

### SDL2 Configuration

The build system auto-detects SDL2, but you can override:

```bash
# Specify SDL2 path
export SDL2_DIR=/usr/local/lib
export SDL2_INCDIR=/usr/local/include/SDL2

# Or use pkg-config
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
```

## Diagnostics

### Enable Verbose Output

```bash
# Mix verbose mode
mix compile --verbose

# Enable build logging
mix compile 2>&1 | tee build.log

# Check for warnings
mix compile --warnings-as-errors
```

### Compiler Diagnostics

The build system provides structured diagnostics:

```elixir
# Success
{:ok, []}

# Success with warnings
{:ok, [], [warning1, warning2]}

# No changes needed
{:noop, []}

# Error
{:error, [diagnostic1, diagnostic2]}
```

### Diagnostic Format

```elixir
%{
  compiler: :zig | :makefile,
  file: "path/to/source.c",
  line: 42,
  column: 10,
  message: "error message",
  severity: :error | :warning | :info
}
```

## Platform Defaults

### Linux

| Setting | Default |
|---------|---------|
| Compiler | Zig (if installed) → Makefile |
| Target | `x86_64-linux-gnu` |
| SDL2 | System via pkg-config |

### macOS

| Setting | Default |
|---------|---------|
| Compiler | Zig (if installed) → Makefile |
| Target | Native (detects arm64/x86_64) |
| SDL2 | Homebrew or framework |

### Windows

| Setting | Default |
|---------|---------|
| Compiler | Zig (if installed) → Makefile |
| Target | `x86_64-windows-gnu` |
| SDL2 | MSYS2 or manual |

## Integration Examples

### GitHub Actions

See [CI/CD Examples](ci-examples.md) for complete workflows.

### Docker

```dockerfile
FROM ghcr.io/ziglang/zig:ubuntu-*

RUN apt-get update && apt-get install -y \
    libsdl2-dev \
    erlang \
    elixir

WORKDIR /app
COPY . .

RUN mix deps.get
RUN mix compile
```

### Nix

```nix
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    zig
    SDL2
    erlang
    elixir
  ];
}
```

## See Also

- [Getting Started Guide](getting-started.md)
- [Cross-Compilation Guide](cross-compilation.md)
- [Troubleshooting Guide](troubleshooting.md)
