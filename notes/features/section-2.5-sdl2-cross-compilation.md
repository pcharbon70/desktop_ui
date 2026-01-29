# Section 2.5: SDL2 Cross-Compilation Handling - Feature Planning Document

**Feature Branch:** `feature/section-2.5-sdl2-cross-compilation`
**Base Branch:** `feature/multi-platform-build`
**Status:** COMPLETE
**Created:** 2026-01-29
**Last Updated:** 2026-01-29

## Current Status

**Overall:** Complete

**Tasks:**
- [x] 2.5.1 Create feature branch
- [x] 2.5.2 Create planning document
- [x] 2.5.3 Review existing SDL2 module
- [x] 2.5.4 Implement cross-sysroot detection
- [x] 2.5.5 Implement target-specific SDL2 paths
- [x] 2.5.6 Implement SDL2 static library linking option
- [x] 2.5.7 Add DESKTOPUI_SDL2_STATIC option
- [x] 2.5.8 Update Mix compiler to pass target to SDL2
- [x] 2.5.9 Create unit tests
- [ ] 2.5.10 Write summary document
- [ ] 2.5.11 Commit and merge to multi-platform-build

## What Works

**SDL2 Module Extensions (DesktopUI.Nif.SDL2):**
- `cflags/1` - Now accepts optional target parameter for cross-compilation
- `ldflags/1` - Now accepts optional target parameter for cross-compilation
- `static_linking?/0` - New function to detect static linking mode
- `get_cross_sdl2_prefix/1` - Detects SDL2 in cross-compilation sysroots
- `get_cross_sysroot_sdl2/1` - Searches standard multiarch paths
- `get_dynamic_ldflags/1` - Handles dynamic linking for cross-compilation
- `get_static_ldflags/1` - Handles static linking for cross-compilation
- `get_cflags_native/0` - Refactored native cflags detection
- `get_cflags_from_prefix/1` - Helper to extract cflags from a prefix

**Mix Compiler Updates:**
- `compile_with_makefile/3` - Passes target to SDL2 functions for cross-compilation
- `build_zig_command/4` - Passes target to SDL2 functions for cross-compilation

**Tests (13 new tests, all passing):**
- `static_linking?/0` tests (3 tests)
- `cflags/1` with target tests (3 tests)
- `ldflags/1` with target and static linking tests (3 tests)
- Cross-compilation detection tests (2 tests)
- Fallback behavior tests (2 tests)

## What's Next

Write summary document and request commit/merge permission.

## How to Run

```bash
# Native build with SDL2
mix compile

# Cross-compile with custom SDL2 path
DESKTOPUI_TARGET=aarch64-linux-gnu \
DESKTOPUI_SDL2_CROSS_PATH=/usr/aarch64-linux-gnu \
mix compile

# Cross-compile with static linking
DESKTOPUI_TARGET=aarch64-linux-gnu \
DESKTOPUI_SDL2_STATIC=1 \
mix compile

# Cross-compile with both options
DESKTOPUI_TARGET=aarch64-linux-gnu \
DESKTOPUI_SDL2_CROSS_PATH=/usr/aarch64-linux-gnu \
DESKTOPUI_SDL2_STATIC=1 \
mix compile
```

## 1. Problem Statement

Section 2.2-2.3 added Zig compiler integration and cross-compilation support via `DESKTOPUI_TARGET`. However, the SDL2 detection module (`DesktopUI.Nif.SDL2`) only detects SDL2 for the native platform. When cross-compiling, SDL2 headers and libraries need to be found for the target platform, which may be in different locations.

### Impact Analysis

**Cross-Compilation Impact (HIGH):**
- Cross-compilation fails if SDL2 can't be found for target
- Developers need a way to specify SDL2 location for target platform
- Static linking can simplify cross-compilation by avoiding runtime dependencies

**Developer Experience Impact (MEDIUM):**
- Clear environment variables for SDL2 cross-compilation
- Helpful error messages when SDL2 not found for target
- Static linking option for portable binaries

**Build System Impact (LOW):**
- Extend existing SDL2 module with cross-compilation support
- No changes to compiler selection logic

### Goals

Extend SDL2 detection so that:
1. SDL2 can be found in cross-compilation sysroots
2. Developers can specify custom SDL2 paths for cross-compilation
3. Static linking is supported for portable binaries
4. Clear error messages when SDL2 not found for target
5. Existing native compilation continues to work unchanged

## 2. Solution Overview

### High-Level Approach

1. **Cross-Sysroot Detection** - Add search paths for target-specific SDL2 locations
2. **Custom Path Override** - Support `DESKTOPUI_SDL2_CROSS_PATH` for manual specification
3. **Static Linking** - Add `DESKTOPUI_SDL2_STATIC` for static linking option
4. **Target-Aware Detection** - Modify SDL2 detection to be aware of compilation target
5. **Documentation** - Document SDL2 requirements for cross-compilation

### Design Decisions

**Cross-Compilation SDL2 Search Paths:**
1. `DESKTOPUI_SDL2_CROSS_PATH` - Manual override for cross-compilation SDL2
2. `/usr/{target-triple}/include` and `/usr/{target-triple}/lib` - Standard cross-sysroot locations
3. Existing native paths as fallback

**Static Linking:**
- When `DESKTOPUI_SDL2_STATIC=1`, link SDL2 statically
- Change linker flags from `-lSDL2` to path-based static linking
- Requires SDL2 static library (.a file) to be available

**Detection Priority (Cross-Compilation):**
```
1. DESKTOPUI_SDL2_CROSS_PATH (if set)
2. /usr/{target-triple}/{include,lib}
3. DESKTOPUI_SDL2_PREFIX (existing, native)
4. pkg-config with --host={target-triple}
5. Existing native paths (may fail at link time)
```

## 3. Implementation Plan

### Step 1: Add Cross-Compilation Awareness

- [ ] Add target parameter to SDL2 detection functions
- [ ] Detect when cross-compiling vs native compilation
- [ ] Route to appropriate detection logic

### Step 2: Implement Cross-Sysroot Detection

- [ ] Add `find_cross_sysroot_sdl2/1` function
- [ ] Check `/usr/{target-triple}/include` and `/usr/{target-triple}/lib`
- [ ] Support Debian-style multiarch paths

### Step 3: Add Custom Path Override

- [ ] Support `DESKTOPUI_SDL2_CROSS_PATH` environment variable
- [ ] Check this path first during cross-compilation
- [ ] Validate path contains include/ and lib/ subdirectories

### Step 4: Implement Static Linking

- [ ] Add `static_linking?/0` function
- [ ] Check `DESKTOPUI_SDL2_STATIC` environment variable
- [ ] Modify ldflags to return static library path
- [ ] Update compiler to use static flags

### Step 5: Update Compiler Integration

- [ ] Pass target to SDL2 detection functions
- [ ] Use static flags when requested
- [ ] Improve error messages for missing SDL2

### Step 6: Write Tests

- [ ] Test SDL2 found in cross-sysroot when present
- [ ] Test DESKTOPUI_SDL2_CROSS_PATH override works
- [ ] Test static linking produces correct flags
- [ ] Test error messages when SDL2 not found
- [ ] Test dynamic linking works when static not requested

### Step 7: Document

- [ ] Add cross-compilation SDL2 documentation
- [ ] Document DESKTOPUI_SDL2_CROSS_PATH usage
- [ ] Document DESKTOPUI_SDL2_STATIC usage
- [ ] Add troubleshooting section

## 4. Task Checklist

### Implementation Tasks
- [ ] Add target-aware SDL2 detection
- [ ] Implement cross-sysroot SDL2 search
- [ ] Add DESKTOPUI_SDL2_CROSS_PATH support
- [ ] Add static linking detection
- [ ] Modify ldflags for static linking
- [ ] Update Mix compiler to pass target to SDL2 module
- [ ] Add helpful error messages

### Testing Tasks
- [ ] Test cross-sysroot SDL2 detection
- [ ] Test custom path override
- [ ] Test static linking flags
- [ ] Test error messages
- [ ] Test native compilation unchanged

### Final Tasks
- [ ] All tests pass
- [ ] Update planning document
- [ ] Write summary document
- [ ] Commit changes
- [ ] Request merge permission

## 5. API Design

### New Environment Variables

| Variable | Purpose | Example |
|---|---|---|
| `DESKTOPUI_SDL2_CROSS_PATH` | SDL2 path for cross-compilation | `/usr/aarch64-linux-gnu` |
| `DESKTOPUI_SDL2_STATIC` | Enable static linking | `1` |

### Extended SDL2 Module Functions

```elixir
@spec cflags(target :: String.t() | nil) :: [String.t()]
def cflags(target \\ nil)

@spec ldflags(target :: String.t() | nil) :: [String.t()]
def ldflags(target \\ nil)

@spec static_linking?() :: boolean()
def static_linking?()

@spec find_cross_sysroot_sdl2(target :: String.t()) :: {:ok, String.t()} | :error
def find_cross_sysroot_sdl2(target)
```

### Linker Flag Changes

**Dynamic Linking (default):**
```elixir
["-L/path/to/lib", "-lSDL2"]
```

**Static Linking (DESKTOPUI_SDL2_STATIC=1):**
```elixir
["/path/to/lib/libSDL2.a"]
```

## 6. Cross-Compilation Examples

### Cross-Compile with Custom SDL2 Path

```bash
DESKTOPUI_TARGET=aarch64-linux-gnu \
DESKTOPUI_SDL2_CROSS_PATH=/opt/cross-sdl2/aarch64-linux-gnu \
mix compile
```

### Cross-Compile with Static Linking

```bash
DESKTOPUI_TARGET=aarch64-linux-gnu \
DESKTOPUI_SDL2_STATIC=1 \
mix compile
```

### Cross-Compile with Both Options

```bash
DESKTOPUI_TARGET=aarch64-linux-gnu \
DESKTOPUI_SDL2_CROSS_PATH=/usr/aarch64-linux-gnu \
DESKTOPUI_SDL2_STATIC=1 \
mix compile
```

## 7. Error Handling

### SDL2 Not Found for Target

```
Error: SDL2 not found for target aarch64-linux-gnu

Cross-compilation requires SDL2 headers and libraries for the target platform.

Solutions:
1. Set DESKTOPUI_SDL2_CROSS_PATH to point to SDL2 for the target:
   DESKTOPUI_SDL2_CROSS_PATH=/usr/aarch64-linux-gnu

2. Install SDL2 for the target in the standard location:
   sudo apt-get install libsdl2-dev:arm64

3. Use Zig's built-in SDL2 handling (may work for some targets):
   DESKTOPUI_PREFER_COMPILER=zig mix compile
```

### Static Library Not Found

```
Warning: DESKTOPUI_SDL2_STATIC=1 but libSDL2.a not found
Falling back to dynamic linking.

Static library path checked: /usr/aarch64-linux-gnu/lib/libSDL2.a
```

## 8. Testing Strategy

### Unit Tests

**Cross-Sysroot Detection:**
- Mock File.dir?/File.exists? for cross-sysroot paths
- Test that cross-sysroot is found when present
- Test that native paths are used when cross-sysroot not found

**Custom Path Override:**
- Test DESKTOPUI_SDL2_CROSS_PATH is respected
- Test that custom path takes precedence over sysroot

**Static Linking:**
- Test static_linking? returns true when env var set
- Test ldflags returns static library path when static enabled
- Test ldflags returns dynamic flags when static not enabled

**Error Messages:**
- Test helpful error when SDL2 not found for target
- Test warning when static library not found

### Integration Tests

**Cross-Compilation Workflow:**
- Test full cross-compilation with custom SDL2 path
- Test cross-compilation with static linking
- Test that native compilation still works

## 9. Dependencies

**Internal Modules:**
- `DesktopUI.Nif.Platform` - For target detection
- `DesktopUI.Nif.SDL2` - Being extended with cross-compilation support

**Modified Files:**
- `lib/desktop_ui/nif/sdl2.ex` - Extended with cross-compilation support
- `lib/mix/tasks/compile.desktop_ui_nif.ex` - Pass target to SDL2 functions

**External Dependencies:**
- SDL2 development libraries (native and/or cross-platform)

## 10. Notes and Considerations

### Zig's SDL2 Handling

Zig has its own SDL2 detection and may handle cross-compilation SDL2 automatically. Our implementation should complement, not conflict with, Zig's approach.

### Debian Multiarch

Debian/Ubuntu use multiarch paths like `/usr/lib/x86_64-linux-gnu/`. Our cross-sysroot detection should support this pattern.

### Static Linking Trade-offs

**Pros:**
- Portable binary (no runtime SDL2 dependency)
- Simpler deployment

**Cons:**
- Larger binary size
- License considerations (SDL2 is zlib-licensed, static linking is OK)

### pkg-config Cross-Compilation

pkg-config supports cross-compilation via `--host` and `--define-prefix` options. We could leverage this for more sophisticated detection.

### Future Enhancements

**vcpkg Integration:**
- Support for vcpkg-installed SDL2 on Windows
- vcpkg has triple-specific directories

**Homebrew Cross-Compilation:**
- Document how to use Homebrew for cross-compilation on macOS
- Homebrew installs to `/opt/homebrew/` (ARM) or `/usr/local/` (x86_64)
