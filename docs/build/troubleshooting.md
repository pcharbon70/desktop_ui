# Troubleshooting Guide

This guide covers common issues and solutions when building DesktopUI.

## Quick Diagnostic Commands

```bash
# Check NIF compilation status
mix compile

# Check environment
echo "DESKTOPUI_TARGET: $DESKTOPUI_TARGET"
echo "DESKTOPUI_PREFER_COMPILER: $DESKTOPUI_PREFER_COMPILER"
echo "DESKTOPUI_SKIP_NIF: $DESKTOPUI_SKIP_NIF"

# Check Zig
zig version

# Check SDL2
sdl2-config --version  # Linux/macOS

# Check Erlang/Elixir
erl -version
elixir --version

# Check NIF file
file priv/desktop_ui_nif.so
ldd priv/desktop_ui_nif.so  # Linux
otool -L priv/desktop_ui_nif.so  # macOS
```

## Compiler Issues

### "zig: command not found"

**Cause:** Zig is not installed or not in PATH.

**Solutions:**

1. Install Zig:
   ```bash
   # macOS
   brew install zig

   # Linux (download from ziglang.org)
   # Arch
   sudo pacman -S zig
   ```

2. Or use Makefile compiler instead:
   ```bash
   export DESKTOPUI_PREFER_COMPILER=makefile
   mix compile
   ```

### "make: command not found"

**Cause:** Build tools not installed.

**Solutions:**

```bash
# Ubuntu/Debian
sudo apt-get install build-essential

# macOS
xcode-select --install

# Fedora
sudo dnf install gcc make
```

### "Zig version too old"

**Cause:** Zig version is below minimum required (0.11.0).

**Solution:**

```bash
# Check version
zig version

# Upgrade via package manager or download latest from ziglang.org
```

## SDL2 Issues

### "SDL2 not found"

**Cause:** SDL2 development libraries are not installed.

**Solutions:**

```bash
# Ubuntu/Debian
sudo apt-get install libsdl2-dev

# macOS
brew install sdl2

# Fedora
sudo dnf install SDL2-devel

# Arch Linux
sudo pacman -S sdl2
```

### "Cannot find -lSDL2"

**Cause:** SDL2 development libraries not installed, or pkg-config can't find SDL2.

**Solutions:**

```bash
# Check SDL2 installation
sdl2-config --cflags
sdl2-config --libs

# Install development libraries (not just runtime)
sudo apt-get install libsdl2-dev  # NOT libsdl2-2.0-0

# Set SDL2 path manually if needed
export SDL2_DIR=/usr/local/lib
```

### "SDL2/SDL.h not found"

**Cause:** SDL2 headers not in include path.

**Solutions:**

```bash
# Find SDL2 headers
find /usr -name SDL.h 2>/dev/null

# Set include path
export C_INCLUDE_PATH=/usr/include/SDL2
```

## Target/Platform Issues

### "Invalid target triple"

**Cause:** Target format is incorrect.

**Correct format:** `{arch}-{os}-{env}`

```bash
# Correct
export DESKTOPUI_TARGET=x86_64-linux-gnu

# Incorrect (missing components)
export DESKTOPUI_TARGET=x86_64-linux

# Incorrect (wrong format)
export DESKTOPUI_TARGET=linux-x86_64
```

**See:** [Cross-Compilation Guide](cross-compilation.md#target-triple-format)

### "Unknown architecture"

**Cause:** Architecture name not recognized.

**Supported architectures:** x86_64, aarch64, arm64, arm, x86, riscv64, riscv32, mips64, mips

```bash
# Correct
export DESKTOPUI_TARGET=aarch64-linux-gnu

# Incorrect
export DESKTOPUI_TARGET=armv8-linux-gnu  # Use aarch64
```

### "Unknown OS"

**Cause:** OS name not recognized.

**Supported OS:** linux, macos, windows

```bash
# Correct
export DESKTOPUI_TARGET=x86_64-macos-none

# Incorrect
export DESKTOPUI_TARGET=x86_64-osx-none  # Use macos
export DESKTOPUI_TARGET=x86_64-darwin-none  # Use macos
```

## NIF Loading Issues

### "dlopen: cannot open shared object"

**Cause:** NIF binary has missing dependencies or wrong architecture.

**Solutions:**

```bash
# Check binary architecture
file priv/desktop_ui_nif.so

# Check for missing dependencies
ldd priv/desktop_ui_nif.so  # Linux
otool -L priv/desktop_ui_nif.so  # macOS

# Install missing libraries
# Ubuntu/Debian
sudo apt-get install libstdc++6

# Rebuild if architecture mismatch
mix clean
mix compile
```

### "NIF library not loaded"

**Cause:** NIF compilation failed or was skipped.

**Solutions:**

```bash
# Check if NIF was compiled
ls -la priv/desktop_ui_nif.so

# If missing, rebuild
DESKTOPUI_SKIP_NIF= mix clean  # Ensure skip is off
mix compile

# Check for compilation errors
mix compile 2>&1 | tee build.log
```

## Build Performance Issues

### "Compilation is very slow"

**Causes:** System compiler instead of Zig, no parallel builds.

**Solutions:**

```bash
# Use Zig (faster)
export DESKTOPUI_PREFER_COMPILER=zig
mix compile

# Enable parallel builds (automatic with Mix)
# But ensure CPU isn't throttled

# Use ccache with Makefile
sudo apt-get install ccache  # Linux
export CC="ccache gcc"
export CXX="ccache g++"
```

### "Out of memory during compilation"

**Solutions:**

```bash
# Close other applications

# Limit parallel jobs
export MIX_BUILDembed=1

# Use Makefile (uses less RAM)
export DESKTOPUI_PREFER_COMPILER=makefile
mix compile
```

## Cross-Compilation Issues

### "Cross-compiled binary doesn't run on target"

**Causes:** Wrong target, missing runtime libraries, architecture mismatch.

**Solutions:**

```bash
# Verify target architecture
file priv/desktop_ui_nif.so

# Check target matches destination machine
export DESKTOPUI_TARGET=x86_64-linux-gnu  # Match target system

# Use musl for static linking (fewer dependencies)
export DESKTOPUI_TARGET=x86_64-linux-musl

# Test in container matching target
docker run --rm -v $(pwd):/app ubuntu:latest /app/priv/desktop_ui_nif.so
```

### "Cross-compilation to macOS fails code signature"

**Cause:** Cross-compiled macOS binaries aren't signed.

**Solution:** This is expected. Sign on macOS hardware for distribution:

```bash
# On macOS host
codesign --force --deep -s - priv/desktop_ui_nif.so
```

## Erlang/Elixir Issues

### "unsupported Erlang/OTP version"

**Cause:** Erlang version too old.

**Solution:**

```bash
# Check version
erl -version

# Need OTP 27 or higher
# Install via asdf
asdf install erlang 27.0
asdf global erlang 27.0
```

### "mix: command not found"

**Cause:** Elixir not in PATH.

**Solution:**

```bash
# Add to PATH (adjust paths)
export PATH=$PATH:/path/to/elixir/bin

# Or restart terminal after installation
```

## Windows-Specific Issues

### "WSL2 can't access Windows files"

**Solution:** Access via `/mnt/c/`:

```bash
cd /mnt/c/Users/YourName/Projects/desktop_ui
```

Better: Work in WSL2 filesystem (`~`) for performance.

### "PowerShell syntax errors"

**Solution:** Use appropriate syntax for each shell:

```powershell
# PowerShell
$env:VARIABLE="value"

# Command Prompt
set VARIABLE=value

# Git Bash/WSL
export VARIABLE="value"
```

## Getting More Help

### Enable Verbose Output

```bash
# Verge Mix compilation
mix compile --verbose

# Enable Erlang logger
export ELIXIR_LOGGER_LEVEL=debug
mix compile
```

### Check Build Artifacts

```bash
# View compiler output
cat _build/dev/lib/desktop_ui/compile.desktop_ui_nif.log

# Check manifest (build cache)
cat _build/dev/lib/desktop_ui/.compile.desktop_ui_nif
```

### Diagnostic Script

Create `scripts/diagnose.sh`:

```bash
#!/bin/bash
echo "=== DesktopUI Build Diagnostics ==="
echo ""
echo "System:"
uname -a
echo ""
echo "Erlang:"
erl -version 2>&1 | head -1
echo ""
echo "Elixir:"
elixir --version 2>&1 | head -1
echo ""
echo "Zig:"
zig version
echo ""
echo "SDL2:"
sdl2-config --version 2>/dev/null || echo "Not found"
echo ""
echo "Environment:"
echo "DESKTOPUI_TARGET: ${DESKTOPUI_TARGET:-not set}"
echo "DESKTOPUI_PREFER_COMPILER: ${DESKTOPUI_PREFER_COMPILER:-not set}"
echo "DESKTOPUI_SKIP_NIF: ${DESKTOPUI_SKIP_NIF:-not set}"
echo ""
echo "NIF Binary:"
if [ -f priv/desktop_ui_nif.so ]; then
    file priv/desktop_ui_nif.so
else
    echo "NIF not built"
fi
```

### Known Issues

| Issue | Status | Workaround |
|-------|--------|------------|
| Zig 0.10.0 crashes on some ARM64 | Fixed in 0.11.0 | Upgrade Zig |
| Cross-compile to macOS requires signing | Expected | Sign on macOS host |
| WSL2 file access slow | Expected | Work in WSL2 home dir |
| Old Ubuntu (18.04) SDL2 issues | Won't fix | Use Ubuntu 20.04+ |

### Report a Bug

If you encounter an issue not covered here:

1. Run diagnostic script (above)
2. Collect error messages
3. Check existing GitHub issues
4. Create new issue with:
   - Platform and OS version
   - Output of diagnostic script
   - Full error message
   - Steps to reproduce

## Additional Resources

- [Getting Started Guide](getting-started.md)
- [Cross-Compilation Guide](cross-compilation.md)
- [Platform Setup](platform-setup/)
- [Compiler Reference](compiler-reference.md)
