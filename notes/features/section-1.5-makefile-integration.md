# Section 1.5: Makefile Integration - Feature Planning Document

**Feature Branch:** `feature/section-1.5-makefile-integration`
**Base Branch:** `feature/multi-platform-build`
**Status:** ✅ COMPLETE
**Created:** 2026-01-29
**Last Updated:** 2026-01-29

## Current Status

**Overall:** Complete

**Tasks:**
- [x] 1.5.1 Update Makefile to support DESKTOPUI_TARGET variable - Complete
- [x] 1.5.2 Create `compile_with_makefile/3` function in compiler - Complete
- [x] 1.5.3 Implement make executable detection - Complete
- [x] 1.5.4 Pass ERTS include path to Makefile via environment - Complete
- [x] 1.5.5 Handle Makefile exit codes correctly - Complete

## What Works

All functionality implemented and tested:
- Makefile updated with DESKTOPUI_TARGET, ERTS_INCLUDE_DIR, SDL2_CFLAGS, SDL2_LDFLAGS environment variable support
- Mix compiler module (Mix.Tasks.Compile.DesktopUiNif) created with:
  - `run/1` callback for compilation
  - `clean/0` callback for cleanup
  - `manifests/0` callback for incremental compilation
  - `compile_with_makefile/3` function that invokes make with environment variables
  - `find_make_executable/0` for make/mingw32-make detection
  - Exit code handling and Mix compiler diagnostics
- DESKTOPUI_SKIP_NIF environment variable support
- 12 unit tests, all passing

## Test Results

All 12 unit tests pass:
- clean/0 tests (3 tests)
- manifests/0 tests (1 test)
- run/1 tests (4 tests)
- environment variable handling tests (2 tests)
- diagnostic format tests (1 test)
- integration tests (1 test)

## What's Next

Ready to commit and merge to multi-platform-build branch.

## How to Run

```bash
# After implementation
mix compile  # Will use Makefile as fallback compiler
make         # Standalone Makefile still works

# With custom target
DESKTOPUI_TARGET=x86_64-windows-gnu mix compile
```

## 1. Problem Statement

The existing Makefile works for standalone compilation but needs to be integrated into the Mix compiler workflow. This will enable `mix compile` to use the Makefile as a fallback build method when Zig (Phase 2) is not available, while maintaining backward compatibility with standalone `make` invocation.

### Impact Analysis

**Build System Impact (HIGH):**
- Makefile becomes the fallback compiler for Phase 1
- Must work seamlessly with Mix compiler diagnostics
- Environment variables must be passed correctly

**Backward Compatibility Impact (HIGH):**
- Standalone `make` invocation must continue to work
- Existing workflows should not break

**Developer Experience Impact (MEDIUM):**
- Clear error messages when make is not found
- Proper exit code handling for CI/CD integration

### Goals

Create Makefile integration that:
1. Allows Mix compiler to invoke Makefile with proper environment
2. Supports DESKTOPUI_TARGET for cross-compilation
3. Handles Makefile exit codes correctly
4. Maintains backward compatibility with standalone `make`
5. Provides clear error diagnostics

## 2. Solution Overview

### High-Level Approach

1. **Makefile Updates**: Add support for DESKTOPUI_TARGET and ERTS_INCLUDE_DIR environment variables
2. **Mix Compiler Function**: Create `compile_with_makefile/3` that invokes make with proper environment
3. **Error Handling**: Convert Makefile exit codes to Mix compiler diagnostics
4. **Detection**: Check for make executable availability

### Design Decisions

**Environment Variable Passing:**
- `ERTS_INCLUDE_DIR` - Override ERTS include detection (from Mix compiler)
- `DESKTOPUI_TARGET` - Target triple for cross-compilation
- `DESKTOPUI_SKIP_NIF` - Skip NIF compilation (already supported)

**Makefile Detection:**
- Use `System.find_executable("make")` for Unix
- Use `System.find_executable("mingw32-make")` for Windows (MSYS2)

**Exit Code Mapping:**
- Exit code 0 → `{:ok, []}`
- Exit code 2 → `{:error, [diagnostic]}`
- Make not found → Warning logged, attempt fallback

## 3. Agent Consultations Performed

**No external agent consultations required.** This feature is based on:
- Existing Makefile structure analysis
- Mix.Task.Compiler behavior documentation
- Standard Unix make conventions

## 4. Technical Details

### Files to Create

**New Files:**
- `lib/mix/tasks/compile/desktop_ui_nif.ex` - Mix compiler with Makefile integration (partial)
- `test/mix/tasks/compile/desktop_ui_nif_test.exs` - Compiler tests

### Files to Modify

**Modified Files:**
- `Makefile` - Add DESKTOPUI_TARGET and environment variable support

### Module Structure

```elixir
defmodule Mix.Tasks.Compile.DesktopUiNif do
  use Mix.Task.Compiler

  @impl true
  def run(_args) do
    if should_compile?() do
      compile_nif()
    else
      {:noop, []}
    end
  end

  @impl true
  def clean(), do: # Remove compiled NIFs

  @impl true
  def manifests(), do: # Return manifest paths for incremental compilation

  # Private functions

  defp compile_nif do
    # Try Zig first (Phase 2), fall back to Makefile
  end

  defp compile_with_makefile(erts_include, target, opts) do
    # Invoke make with environment variables
  end

  defp find_make_executable do
    # Detect make or mingw32-make
  end

  defp should_compile? do
    # Check DESKTOPUI_SKIP_NIF
  end
end
```

## 5. Success Criteria

1. **Makefile Integration Works**
   - `mix compile` successfully invokes Makefile
   - ERTS_INCLUDE_DIR is passed correctly
   - DESKTOPUI_TARGET is honored

2. **Exit Codes Handled**
   - Success → `{:ok, []}`
   - Failure → `{:error, [diagnostic]}`

3. **Backward Compatibility**
   - Standalone `make` still works
   - All existing Makefile targets functional

4. **Tests Pass**
   - All unit tests pass
   - Tests cover make detection
   - Tests cover exit code handling

## 6. Implementation Plan

### Step 1: Update Makefile

- [ ] Add DESKTOPUI_TARGET support
- [ ] Add ERTS_INCLUDE_DIR override support
- [ ] Add Windows make executable detection (mingw32-make)
- [ ] Test standalone `make` still works

### Step 2: Create Mix Compiler Module

- [ ] Create `lib/mix/tasks/compile/desktop_ui_nif.ex`
- [ ] Implement `run/1` callback
- [ ] Implement `clean/0` callback
- [ ] Implement `manifests/0` callback

### Step 3: Implement compile_with_makefile/3

- [ ] Detect make executable
- [ ] Set environment variables
- [ ] Invoke System.cmd/3
- [ ] Parse exit codes

### Step 4: Write Tests

- [ ] Test make detection
- [ ] Test ERTS_INCLUDE_DIR passing
- [ ] Test exit code handling
- [ ] Test DESKTOPUI_TARGET support

## 7. Notes and Considerations

### Known Limitations

1. **Phase 1 Only**: Makefile is the primary compiler until Phase 2 (Zig)
2. **Windows Support**: Limited in Phase 1, expanded in Phase 3
3. **Error Parsing**: Makefile output parsing is limited (uses exit codes only)

### Future Work

1. **Zig Integration**: Phase 2 will add Zig as preferred compiler
2. **Windows Support**: Phase 3 will add MinGW/MSYS2 support
3. **Error Parsing**: May add better Makefile output parsing

### Testing Challenges

1. **Make Availability**: make may not be installed on all systems
2. **Cross-Compilation**: Hard to test without actual cross-compilation setup
3. **Exit Codes**: Need to simulate various exit code scenarios

## 8. Task Checklist

### Implementation Tasks
- [ ] Update Makefile with DESKTOPUI_TARGET support
- [ ] Update Makefile with ERTS_INCLUDE_DIR override
- [ ] Create Mix compiler module
- [ ] Implement compile_with_makefile/3
- [ ] Implement make detection
- [ ] Implement exit code handling

### Testing Tasks
- [ ] Create test file
- [ ] Test make detection
- [ ] Test ERTS_INCLUDE_DIR passing
- [ ] Test exit code handling
- [ ] Test DESKTOPUI_TARGET override

### Final Tasks
- [ ] All tests pass
- [ ] Update planning document
- [ ] Write summary document
- [ ] Commit changes
- [ ] Request merge permission

## 9. Dependencies

**Requires:**
- Section 1.1: Mix Compiler Integration (not yet complete - this task starts it)
- Section 1.2: Platform Detection Module (complete)
- Section 1.3: ERTS Detection Module (complete)
- Section 1.4: SDL2 Detection Module (complete)
- Existing Makefile (exists, needs updates)

**Enables:**
- Full NIF compilation via `mix compile`
- Section 1.6: Mix Configuration Update
- Section 1.7: NIF Loader Module
