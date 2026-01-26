# Section 2.1: C NIF Foundation - Feature Planning Document

**Feature Branch:** `feature/section-2.1-c-nif-foundation`
**Status:** In Progress
**Created:** 2025-01-24
**Planning Document:** `notes/planning/poc/phase-2-graphics-bridge.md`

## Overview

This feature implements the C NIF (Native Implemented Functions) foundation required for SDL2 integration. This is the foundational layer that allows Elixir code to call native C functions for graphics operations.

## Problem Statement

DesktopUI needs to integrate with SDL2 for cross-platform graphics and window management. This requires:

1. **Build infrastructure** for compiling C code into shared libraries that BEAM can load
2. **NIF binding layer** to translate between Erlang/Elixir terms and C types
3. **Module structure** to organize the NIF code
4. **SDL2 dependency detection** to provide clear error messages when SDL2 is missing

Without this foundation, no graphics operations can be performed.

## Solution Overview

We will create a complete NIF build infrastructure:

1. Create `c_src/` directory for all C source files
2. Create `c_src/desktop_ui_nif.c` as the main NIF implementation file
3. Update `mix.exs` to use `:erlc_make` compiler for C code
4. Create `Makefile` for building the NIF shared library
5. Create `DesktopUI.Graphics` module to load and manage the NIF
6. Add SDL2 dependency detection with helpful error messages
7. Implement basic NIF initialization stub

## Technical Details

### NIF Architecture

```
Elixir Code (DesktopUI.Graphics)
    ↓ loads NIF
C NIF (desktop_ui_nif.so)
    ↓ links to
SDL2 Library
```

### File Structure

```
desktop_ui/
├── c_src/
│   └── desktop_ui_nif.c     # Main NIF implementation
├── lib/desktop_ui/
│   └── graphics.ex          # Graphics module with NIF loading
├── Makefile                 # Build configuration
├── mix.exs                  # Updated with :erlc_make compiler
└── test/desktop_ui/
    └── graphics_test.exs    # Unit tests for Graphics module
```

### NIF Functions to Implement (Initial Stub)

For this section, we only need the basic NIF initialization:

- `nif_init()` - Initialize the NIF, return library version info
- Future: SDL2 window creation, drawing primitives, etc.

### Dependencies

**System Requirements:**
- SDL2 development library (`libsdl2-dev` on Ubuntu, `sdl2` via Homebrew on macOS)
- C compiler (gcc/clang)
- Make build tool
- Erlang/Elixir development headers

**Mix Dependencies (existing):**
- No new Elixir dependencies required for NIF foundation

## Implementation Tasks

### Task 2.1.1: Create c_src/ directory
**Status:** Pending
**Description:** Create `c_src/` directory at project root for C source files
**Files:** `c_src/` (new directory)

### Task 2.1.2: Create desktop_ui_nif.c
**Status:** Pending
**Description:** Create main NIF implementation file with basic stubs
**Files:** `c_src/desktop_ui_nif.c` (new file)
**Key Functions:**
- NIF initialization function
- Version info function
- Load/unload callbacks

### Task 2.1.3: Update mix.exs
**Status:** Pending
**Description:** Add `:erlc_make` compiler to project configuration
**Files:** `mix.exs` (modify)
**Changes:**
- Add `compilers: [:erlc_make] ++ Mix.compilers()`
- Ensure proper load order

### Task 2.1.4: Create Makefile
**Status:** Pending
**Description:** Create Makefile for building NIF shared library
**Files:** `Makefile` (new file)
**Targets:**
- `all` - Build the NIF
- `clean` - Remove build artifacts
- Must detect SDL2 and provide helpful errors

### Task 2.1.5: Create DesktopUI.Graphics module
**Status:** Pending
**Description:** Create Graphics module with NIF loading
**Files:** `lib/desktop_ui/graphics.ex` (new file)
**Functions:**
- `load_nif/0` - Load the compiled NIF library
- `version/0` - Get NIF version info
- `initialized?/0` - Check if NIF loaded successfully
- Fallback implementations when NIF not loaded

### Task 2.1.6: Add SDL2 dependency detection
**Status:** Pending
**Description:** Detect SDL2 presence and provide helpful errors
**Files:** `Makefile`, `lib/desktop_ui/graphics.ex`
**Implementation:**
- Makefile: Check for SDL2 headers/libraries
- Graphics module: Provide clear error messages
- Document installation instructions

### Task 2.1.7: Implement basic NIF stub
**Status:** Pending
**Description:** Implement minimal NIF with initialization
**Files:** `c_src/desktop_ui_nif.c`
**Functions:**
- `nif_init()` - Return version map
- `nif_get_error()` - Get last error message

## Testing Strategy

### Unit Tests (5 tests required)

1. **Test NIF loading** - Verify NIF loads without crashing
2. **Test version info** - Verify version function returns expected format
3. **Test initialized?** - Verify NIF initialization state
4. **Test fallback when NIF missing** - Verify graceful degradation
5. **Test error handling** - Verify error messages are helpful

### Integration Strategy

- NIF should load cleanly when SDL2 is present
- Should provide helpful errors when SDL2 is missing
- Should not crash the BEAM VM even if NIF fails to load

## Success Criteria

1. ✅ `c_src/` directory exists with `desktop_ui_nif.c`
2. ✅ `mix compile` successfully builds NIF (when SDL2 present)
3. ✅ `DesktopUI.Graphics` module can load NIF
4. ✅ `DesktopUI.Graphics.version/0` returns version info
5. ✅ `DesktopUI.Graphics.initialized?/0` returns true when NIF loaded
6. ✅ Helpful error message when SDL2 missing
7. ✅ 5 unit tests passing
8. ✅ No compiler warnings

## Progress

### 2025-01-24
- [x] Created feature branch `feature/section-2.1-c-nif-foundation`
- [ ] Created feature planning document
- [ ] Implementation in progress

## Notes/Considerations

### Risk Assessment

**High Risk Items:**
- SDL2 detection across platforms (Linux/macOS/Windows)
- NIF crash could take down entire BEAM VM

**Medium Risk Items:**
- Mix compiler configuration may conflict with other tools
- Makefile portability across platforms

**Low Risk Items:**
- C code stub implementation
- Module structure

### Platform Support

**Primary:** Linux (Ubuntu/Debian with `libsdl2-dev`)
**Secondary:** macOS (with SDL2 via Homebrew)
**Future:** Windows (requires different build approach)

### NIF Safety

- All NIF functions must be crash-safe
- Use `enif_protect`/`enif_unprotect` for long-running operations
- Validate all input parameters
- Never block in NIF (use async threads for long operations)

### Testing Without SDL2

Tests should pass even when SDL2 is not installed:
- Use mock/fallback implementations
- Skip tests that require SDL2 with clear messages
- Document SDL2 requirement in test output

## References

- Planning document: `notes/planning/poc/phase-2-graphics-bridge.md`
- Erlang NIF documentation: http://erlang.org/doc/man/erl_nif.html
- SDL2 documentation: https://wiki.libsdl.org/
- Elixir NIF guide: https://elixir-lang.org/getting-started/mix-otp/erlfoundation.html
- Branch: `feature/section-2.1-c-nif-foundation`
- Target branch: `poc`
