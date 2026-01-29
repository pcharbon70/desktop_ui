# Section 1.4: SDL2 Detection Module - Feature Planning Document

**Feature Branch:** `feature/section-1.4-sdl2-detection`
**Base Branch:** `feature/multi-platform-build`
**Status:** ✅ COMPLETE
**Created:** 2026-01-28
**Last Updated:** 2026-01-29

## Current Status

**Overall:** Complete

**Tasks:**
- [x] 1.4.1 Create `lib/desktop_ui/nif/sdl2.ex` module - Complete
- [x] 1.4.2 Implement `available?/0` to check SDL2 availability - Complete
- [x] 1.4.3 Implement `cflags/0` to get SDL2 C compiler flags - Complete
- [x] 1.4.4 Implement `ldflags/0` to get SDL2 linker flags - Complete
- [x] 1.4.5 Implement `find_sdl2_config/0` to locate sdl2-config tool - Complete
- [x] 1.4.6 Implement `find_pkg_config/0` to locate pkg-config tool - Complete
- [x] 1.4.7 Create unit tests - Complete

## What Works

All functionality implemented and tested:
- SDL2 availability detection using multiple methods (pkg-config, sdl2-config, standard paths)
- C compiler flags retrieval (`-I` include paths)
- Linker flags retrieval (`-L` library paths, `-lSDL2`)
- Tool detection (pkg-config, sdl2-config)
- Environment variable override (DESKTOPUI_SDL2_PREFIX)
- Platform-specific path detection for Linux, macOS, Windows
- Graceful degradation when SDL2 not found (returns empty lists)

## Test Results

All 16 unit tests pass:
- available?/0 tests (3 tests)
- cflags/0 tests (3 tests)
- ldflags/0 tests (3 tests)
- find_pkg_config/0 tests (2 tests)
- find_sdl2_config/0 tests (1 test)
- DESKTOPUI_SDL2_PREFIX override tests (2 tests)
- Integration tests (2 tests)

## What's Next

Ready to commit and merge to multi-platform-build branch.

## How to Run

```bash
# After implementation
iex -S mix
iex> DesktopUI.Nif.SDL2.available?()
true

iex> DesktopUI.Nif.SDL2.cflags()
["-I/usr/include/SDL2"]

iex> DesktopUI.Nif.SDL2.ldflags()
["-lSDL2"]
```

## 1. Problem Statement

SDL2 (Simple DirectMedia Layer 2) is the graphics library dependency for DesktopUI. To compile the NIF with SDL2 support, we need to:

1. Detect if SDL2 is installed on the system
2. Find the SDL2 include directories for compiler flags
3. Find the SDL2 library directories for linker flags
4. Support multiple installation methods (system package, Homebrew, vcpkg, etc.)
5. Provide graceful fallback when SDL2 is not available

### Impact Analysis

**Build System Impact (HIGH):**
- NIF compilation requires SDL2 headers and libraries
- SDL2 flags must be passed to C compiler and linker
- Missing SDL2 should not prevent compilation (NIF has stub implementations)

**Cross-Platform Impact (HIGH):**
- SDL2 installation varies by platform and package manager
- Include/library paths differ between Linux, macOS, Windows
- Different detection tools available (pkg-config, sdl2-config)

**Developer Experience Impact (MEDIUM):**
- Clear error messages when SDL2 is not found
- Easy override via environment variable
- Helpful installation instructions

### Goals

Create a `DesktopUI.Nif.SDL2` module that:
1. Detects SDL2 availability using multiple methods
2. Retrieves C compiler flags (cflags) for SDL2 headers
3. Retrieves linker flags (ldflags) for SDL2 libraries
4. Provides graceful fallback when SDL2 is not available
5. Supports `DESKTOPUI_SDL2_PREFIX` environment variable override

## 2. Solution Overview

### High-Level Approach

Create a pure Elixir module that tries multiple methods to detect SDL2 and retrieve compiler/linker flags.

### Design Decisions

**Detection Priority Order:**
1. `DESKTOPUI_SDL2_PREFIX` - Manual override
2. `pkg-config` - Most portable, works on Linux/macOS
3. `sdl2-config` - Fallback for Unix systems
4. Standard paths - Last resort

**Graceful Degradation:**
- Return empty list `[]` when SDL2 not found
- NIF has stub implementations, so compilation can proceed
- `available?/0` returns `false` when not found

**Platform-Specific Paths:**
- Linux: `/usr/include/SDL2`, `/usr/local/include/SDL2`
- macOS: `/opt/homebrew/include/SDL2`, `/usr/local/include/SDL2`
- Windows: `C:\Program Files\SDL2\include`, `C:\SDL2\include`

**Tool Detection:**
- `pkg-config SDL2` for package config
- `sdl2-config --cflags` and `sdl2-config --libs`
- Fallback to path-based detection

## 3. Agent Consultations Performed

**No external agent consultations required.** This feature is based on:
- SDL2 documentation for standard installation paths
- Common Unix build tools (pkg-config, sdl2-config)
- Existing Makefile SDL2 detection logic

## 4. Technical Details

### Files to Create

**New Files:**
- `lib/desktop_ui/nif/sdl2.ex` - SDL2 detection module
- `test/desktop_ui/nif/sdl2_test.exs` - Unit tests

### Module Structure

```elixir
defmodule DesktopUI.Nif.SDL2 do
  @moduledoc "SDL2 detection for NIF compilation"

  @type flag_result :: [String.t()]
  @type avail_result :: boolean()

  @spec available?() :: avail_result()
  @spec cflags() :: flag_result()
  @spec ldflags() :: flag_result()
  @spec find_pkg_config() :: {:ok, String.t()} | {:error, :not_found}
  @spec find_sdl2_config() :: {:ok, String.t()} | {:error, :not_found}
end
```

### Dependencies

**Requires:**
- Elixir ~1.18
- DesktopUI.Nif.Platform (for platform-specific paths)

**Enables:**
- Task 1.1: Mix Compiler (needs SDL2 flags)
- Phase 2: Zig Build System (needs SDL2 linking)
- Full NIF compilation with SDL2 support

## 5. Success Criteria

1. **SDL2 Detection Works**
   - Returns `true` when SDL2 is installed
   - Returns `false` when SDL2 is not available
   - Tries multiple detection methods

2. **CFlags Retrieved**
   - Returns list of include flags
   - Format: `["-I/path/to/include"]`

3. **LdFlags Retrieved**
   - Returns list of library flags
   - Format: `["-lSDL2"]` or `["-L/path -lSDL2"]`

4. **Environment Override Works**
   - `DESKTOPUI_SDL2_PREFIX` forces custom location
   - Useful for testing or non-standard installations

5. **Tests Pass**
   - All unit tests pass
   - Tests cover multiple scenarios
   - Tests handle missing SDL2 gracefully

## 6. Implementation Plan

### Step 1: Create Module Skeleton

- [ ] Create `lib/desktop_ui/nif/sdl2.ex` file
- [ ] Add module documentation
- [ ] Define types

### Step 2: Implement Tool Detection

- [ ] Implement `find_pkg_config/0`
- [ ] Implement `find_sdl2_config/0`
- [ ] Return tool path or `{:error, :not_found}`

### Step 3: Implement SDL2 Detection

- [ ] Implement `available?/0`
- [ ] Try pkg-config first
- [ ] Fall back to sdl2-config
- [ ] Check standard paths as last resort

### Step 4: Implement CFlags

- [ ] Implement `cflags/0`
- [ ] Use pkg-config or sdl2-config
- [ ] Format as `-I/path/to/include`
- [ ] Return empty list if not found

### Step 5: Implement LdFlags

- [ ] Implement `ldflags/0`
- [ ] Use pkg-config or sdl2-config
- [ ] Format as `-lSDL2` or `-L/path -lSDL2`
- [ ] Return empty list if not found

### Step 6: Write Tests

- [ ] Test available? with SDL2 present
- [ ] Test available? with SDL2 absent
- [ ] Test cflags returns correct format
- [ ] Test ldflags returns correct format
- [ ] Test environment override

## 7. Notes and Considerations

### Known Limitations

1. **Unix-First**: Initial implementation focuses on Unix tools (pkg-config, sdl2-config)
2. **Windows Support**: Limited Windows support in this section (Phase 3 will expand)
3. **Static Linking**: No support for static linking currently (may add later)
4. **Multiple Versions**: Doesn't handle multiple SDL2 installations

### Future Work

1. **Windows Support**: Add better Windows detection in Phase 3
2. **Framework Support**: macOS framework support
3. **Static Linking**: Option for static linking
4. **Version Detection**: Report SDL2 version

### Testing Challenges

1. **Optional Dependency**: SDL2 may not be installed on all systems
2. **Tool Availability**: pkg-config and sdl2-config may not be present
3. **Path Variability**: Different systems have different SDL2 locations

## 8. Task Checklist

### Implementation Tasks
- [ ] Create `lib/desktop_ui/nif/sdl2.ex`
- [ ] Implement `find_pkg_config/0`
- [ ] Implement `find_sdl2_config/0`
- [ ] Implement `available?/0`
- [ ] Implement `cflags/0`
- [ ] Implement `ldflags/0`

### Testing Tasks
- [ ] Create test file
- [ ] Test available? with SDL2 present
- [ ] Test available? with SDL2 absent
- [ ] Test cflags
- [ ] Test ldflags
- [ ] Test DESKTOPUI_SDL2_PREFIX override

### Final Tasks
- [ ] All tests pass
- [ ] Update planning document
- [ ] Write summary document
- [ ] Commit changes
- [ ] Request merge permission

## 9. Dependencies

**Requires:**
- Section 1.1: Mix Compiler Integration (complete)
- Section 1.2: Platform Detection Module (complete)
- Section 1.3: ERTS Detection Module (complete)
- SDL2 development libraries (optional)

**Enables:**
- Full NIF compilation with SDL2 support
- Phase 2: Zig Build System (needs SDL2 linking)
- Phase 3: Windows Support
