# Section 2.4: Zig Build Configuration - Feature Planning Document

**Feature Branch:** `feature/section-2.4-zig-build-configuration`
**Base Branch:** `feature/multi-platform-build`
**Status:** COMPLETE
**Created:** 2026-01-29
**Last Updated:** 2026-01-29

## Current Status

**Overall:** Complete

**Tasks:**
- [x] 2.4.1 Create feature branch
- [x] 2.4.2 Create planning document
- [x] 2.4.3 Create `build.zig` in project root
- [x] 2.4.4 Configure library target for NIF shared library
- [x] 2.4.5 Add ERTS include path configuration
- [x] 2.4.6 Add SDL2 dependency linking
- [x] 2.4.7 Add install step to priv directory
- [x] 2.4.8 Add build instructions to README
- [x] 2.4.9 Add gitignore entries for Zig artifacts
- [ ] 2.4.10 Write summary document
- [ ] 2.4.11 Commit and merge to multi-platform-build

## What Works

**Zig Build Configuration (build.zig - 116 lines):**
- Native build configuration with `zig build`
- Cross-compilation support via `-Dtarget` option
- Optimization mode selection via `-Doptimize` option
- ERTS include path from `-Derts-include` option or `ERTS_INCLUDE_DIR` environment
- SDL2 system library linking
- Install step to `priv/` directory
- Additional build steps: `check` (build without install), `verbose` (verbose compiler output)
- Platform-specific output file naming (.so, .dylib, .dll)

**Documentation Updates:**
- README.md with comprehensive Zig build instructions
- Includes native build, cross-compilation, and build options documentation
- .gitignore updated for zig-cache/ and zig-out/ directories

## What's Next

Write summary document and request commit/merge permission.

## How to Run

```bash
# Native build with zig
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build

# Cross-compile for ARM64 Linux
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=aarch64-linux-gnu

# Release build
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Doptimize=ReleaseFast

# Build without installing (useful for CI)
zig build check
```

## 1. Problem Statement

Section 2.2 integrated Zig as the primary compiler in the Mix build system. However, we don't have a native `build.zig` file that allows developers to build the NIF using Zig directly without going through Mix. This is useful for:

1. **Non-Elixir builds** - Developers working on the NIF in isolation
2. **Debugging** - Easier to debug Zig-specific compilation issues
3. **CI/CD** - Some CI environments may prefer Zig over Mix
4. **Zig-native workflow** - Developers who prefer Zig's build system

### Impact Analysis

**Build System Impact (MEDIUM):**
- Provides alternative build method for Zig users
- Doesn't affect existing Mix-based builds
- Adds flexibility for different workflows

**Developer Experience Impact (MEDIUM):**
- Zig users can build without installing Elixir
- Easier for debugging Zig-specific issues
- More consistent with Zig ecosystem practices

**Documentation Impact (LOW):**
- Need to document Zig build usage
- Add to README alongside Mix instructions

### Goals

Create `build.zig` so that:
1. `zig build` compiles the NIF for the native platform
2. Cross-compilation works via `-Dtarget` option
3. ERTS include path is configurable via environment variable
4. SDL2 is linked as a system library
5. Output is installed to `priv/` directory

## 2. Solution Overview

### High-Level Approach

1. **Create build.zig** - Add `build.zig` file to project root
2. **Configure Library** - Set up shared library target for NIF
3. **ERTS Detection** - Read ERTS include path from environment
4. **SDL2 Linking** - Link SDL2 as system library
5. **Install Step** - Copy compiled library to priv directory
6. **Documentation** - Add build instructions to README

### Design Decisions

**Zig Build System Features:**
- Use `b.standardTargetOptions(.{})` for target selection via `-Dtarget`
- Use `b.standardOptimizeOption(.{})` for optimization via `-Doptimize`
- Read `ERTS_INCLUDE_DIR` environment variable for ERTS headers
- Use `addSharedLibrary()` for NIF (not static library)
- Output to `zig-out/` by default, with install step to `priv/`

**C Source File:**
- The NIF is in `c_src/desktop_ui_nif.c`
- This is a C file, not Zig - Zig's C compilation support is used

**Platform-Specific Extensions:**
- Zig will automatically handle `.so`, `.dylib`, `.dll` based on target

### build.zig Structure

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get ERTS include directory from environment
    const erts_include = b.option(
        []const u8,
        "erts-include",
        "Path to ERTS include directory"
    ) orelse std.process.getEnvVarOwned(
        b.allocator,
        "ERTS_INCLUDE_DIR"
    ) catch {
        std.debug.print("Error: ERTS_INCLUDE_DIR not set\n", .{});
        std.process.exit(1);
    };

    // Create shared library for NIF
    const nif_lib = b.addSharedLibrary(.{
        .name = "desktop_ui_nif",
        .target = target,
        .optimize = optimize,
    });

    // Add C source files
    nif_lib.addCSourceFiles(.{
        .files = &.{"c_src/desktop_ui_nif.c"},
        .flags = &.{"-fPIC"},
    });

    // Add ERTS include path
    nif_lib.addIncludePath(.{ .path = erts_include });

    // Link SDL2
    nif_lib.linkSystemLibrary("SDL2");

    // Install to priv directory
    const install_step = b.addInstallArtifact(nif_lib, .{
        .dest_dir = .{ .custom = "priv" },
    });

    b.getInstallStep().dependOn(&install_step.step);
}
```

## 3. Implementation Plan

### Step 1: Create build.zig File

- [ ] Create `build.zig` in project root
- [ ] Import std module
- [ ] Define build function with standard options

### Step 2: Configure Library Target

- [ ] Add shared library target for desktop_ui_nif
- [ ] Add C source files from c_src/
- [ ] Set proper compile flags (-fPIC)

### Step 3: Add ERTS Include Path

- [ ] Add option for ERTS include path
- [ ] Fall back to ERTS_INCLUDE_DIR environment variable
- [ ] Provide helpful error if not set

### Step 4: Add SDL2 Linking

- [ ] Link SDL2 as system library
- [ ] Handle SDL2 not found gracefully

### Step 5: Add Install Step

- [ ] Configure install directory to `priv/`
- [ ] Add install step to build

### Step 6: Add Documentation

- [ ] Add Zig build instructions to README
- [ ] Document ERTS_INCLUDE_DIR requirement
- [ ] Document cross-compilation usage

### Step 7: Write Tests

- [ ] Test native build: `zig build`
- [ ] Test cross-compilation: `zig build -Dtarget=aarch64-linux-gnu`
- [ ] Test ERTS_INCLUDE_DIR handling
- [ ] Test optimize modes: Debug, ReleaseSafe, ReleaseFast, ReleaseSmall

## 4. Task Checklist

### Implementation Tasks
- [ ] Create `build.zig` file in project root
- [ ] Configure shared library target
- [ ] Add C source file compilation
- [ ] Add ERTS include path configuration
- [ ] Add SDL2 system library linking
- [ ] Configure install step to priv directory
- [ ] Update README with build instructions

### Testing Tasks
- [ ] Test `zig build` compiles NIF successfully
- [ ] Test `ERTS_INCLUDE_DIR` is respected
- [ ] Test output is placed in priv directory
- [ ] Test `-Dtarget` option works for cross-compilation
- [ ] Test `-Doptimize` option affects binary size
- [ ] Test SDL2 linking works correctly

### Final Tasks
- [ ] All tests pass
- [ ] Update planning document
- [ ] Write summary document
- [ ] Commit changes
- [ ] Request merge permission

## 5. API Design

### build.zig Public Interface

```zig
pub fn build(b: *std.Build) void
```

### Build Options

| Option | Type | Default | Description |
|---|---|---|---|
| `-Dtarget` | string | native | Target triple for cross-compilation |
| `-Doptimize` | enum | Debug | Optimization mode (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall) |
| `-Derts-include` | string | $ERTS_INCLUDE_DIR | Path to ERTS include directory |

### Environment Variables

| Variable | Required | Description |
|---|---|---|
| `ERTS_INCLUDE_DIR` | Yes | Path to ERTS include directory |

### Build Commands

```bash
# Native build (debug)
zig build

# Native build (release)
zig build -Doptimize=ReleaseFast

# Cross-compile for ARM64 Linux
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=aarch64-linux-gnu

# Cross-compile for Windows
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=x86_64-windows-gnu

# Cross-compile for macOS ARM64
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=aarch64-macos-none
```

## 6. Error Handling

### ERTS_INCLUDE_DIR Not Set

```
Error: ERTS_INCLUDE_DIR not set

Please set the ERTS_INCLUDE_DIR environment variable to point to your
Erlang/OTP installation include directory.

Example:
  ERTS_INCLUDE_DIR=/usr/lib/erlang/erts-14.2.1/include zig build
```

### SDL2 Not Found

Zig's system library linking will fail with a helpful error:
```
error: unable to find system library 'SDL2'
```

Users need to install SDL2 development libraries:
- Linux: `sudo apt-get install libsdl2-dev`
- macOS: `brew install sdl2`
- Windows: Download from SDL2 website

## 7. Testing Strategy

### Unit Tests

**Build Configuration:**
- Test that `build.zig` compiles without errors
- Test that all options are parsed correctly

### Integration Tests

**Native Build:**
```bash
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build
```

**Cross-Compilation:**
```bash
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=aarch64-linux-gnu
```

**Optimization Modes:**
```bash
for mode in Debug ReleaseSafe ReleaseFast ReleaseSmall; do
  ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
  zig build -Doptimize=$mode
done
```

## 8. Dependencies

**Zig Version:**
- Zig 0.11.0 or later required

**External Dependencies:**
- Erlang/OTP headers (ERTS)
- SDL2 development libraries

**Source Files:**
- `c_src/desktop_ui_nif.c` - C NIF implementation

## 9. Notes and Considerations

### C vs Zig Source

The NIF is written in C, not Zig. Zig's `addSharedLibrary()` with `addCSourceFiles()` handles C compilation. This means:

- No Zig code is being written
- Zig is being used as a build system and C compiler
- Zig's clang-based toolchain handles all platforms

### Priv Directory

The `priv/` directory is where Mix expects NIFs. Our `build.zig` needs to install there, not to `zig-out/lib/`.

### Zig Cache

Zig creates a `zig-cache/` directory and `zig-out/` build directory. These should be in `.gitignore`.

### Build vs Mix Compiler

The `build.zig` is an **alternative** to the Mix compiler, not a replacement. Both methods:
- Use Zig for compilation (when available)
- Target the same output: `priv/desktop_ui_nif.{ext}`
- Accept the same environment variables

### Cross-Compilation

Zig's cross-compilation is transparent via `-Dtarget`. No sysroot needed for most targets.

## 10. Documentation Updates

### README.md Section

Add a new "Building with Zig" section:

```markdown
## Building with Zig

DesktopUI can also be built using Zig directly without Mix. This requires Zig 0.11.0 or later.

### Prerequisites

1. Install Zig from https://ziglang.org/download
2. Install SDL2 development libraries:
   - Linux: `sudo apt-get install libsdl2-dev`
   - macOS: `brew install sdl2`
   - Windows: Download from https://github.com/libsdl-org/SDL/releases
3. Erlang/OTP must be installed for ERTS headers

### Native Build

```bash
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build
```

### Cross-Compilation

```bash
# Build for ARM64 Linux
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=aarch64-linux-gnu

# Build for Windows
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=x86_64-windows-gnu

# Build for macOS ARM64
ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
zig build -Dtarget=aarch64-macos-none
```

### Build Options

- `-Dtarget=<triple>` - Target triple for cross-compilation
- `-Doptimize=<mode>` - Optimization mode (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall)
- `-Derts-include=<path>` - Path to ERTS include directory (overrides ERTS_INCLUDE_DIR)
```
