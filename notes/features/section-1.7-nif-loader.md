# Section 1.7: NIF Loader Module - Feature Planning Document

**Feature Branch:** `feature/section-1.7-nif-loader`
**Base Branch:** `feature/multi-platform-build`
**Status:** COMPLETE
**Created:** 2026-01-29
**Last Updated:** 2026-01-29

## Current Status

**Overall:** Complete

**Tasks:**
- [x] 1.7.1 Create `lib/desktop_ui/nif_loader.ex` module - Complete
- [x] 1.7.2 Implement `load_nif/0` to load the compiled NIF - Complete
- [x] 1.7.3 Implement `nif_path/0` to locate the NIF library - Complete
- [x] 1.7.4 Implement `priv_dir/0` to get priv directory path - Complete
- [x] 1.7.5 Implement `load_nif/1` with custom path option - Complete

## What Works

All functionality implemented and tested:
- `DesktopUI.NifLoader.priv_dir/0` - Returns the priv directory path
- `DesktopUI.NifLoader.nif_extension/0` - Returns platform-specific file extension
- `DesktopUI.NifLoader.target_triple/0` - Returns target triple for current platform
- `DesktopUI.NifLoader.nif_path/0` - Locates NIF library using search order
- `DesktopUI.NifLoader.load_nif/0` - Loads NIF from default locations
- `DesktopUI.NifLoader.load_nif/1` - Loads NIF from custom path

**Path Resolution Order (Working):**
1. `priv/desktop_ui_nif.{ext}` (standard location)
2. `priv/native/desktop_ui_nif.{ext}` (alternate location)
3. `priv/prebuilt/{triple}/desktop_ui_nif.{ext}` (prebuilt binaries)

**Error Handling (Working):**
- Returns `:ok` on success
- Returns `{:error, :not_found}` when NIF file not found
- Returns `{:error, {:load_failed, _}}` when NIF fails to load
- Platform-specific hints for missing SDL2 libraries
- Helpful debug, info, warning, and error logging

## Test Results

All 28 unit tests pass:
- priv_dir/0 tests (4 tests)
- nif_extension/0 tests (4 tests)
- target_triple/0 tests (4 tests)
- nif_path/0 tests (6 tests)
- load_nif/0 tests (2 tests)
- load_nif/1 tests (3 tests)
- integration tests (5 tests)

## What's Next

Ready to commit and merge to multi-platform-build branch.

## How to Run

```bash
# Load NIF from default locations
DesktopUI.NifLoader.load_nif()
# => :ok | {:error, reason}

# Load NIF from custom path
DesktopUI.NifLoader.load_nif("/custom/path/nif.so")
# => :ok | {:error, reason}

# Get the NIF path for the current platform
DesktopUI.NifLoader.nif_path()
# => "/path/to/priv/desktop_ui_nif.so"

# Get the priv directory
DesktopUI.NifLoader.priv_dir()
# => "/path/to/priv"

# Get the NIF file extension for current platform
DesktopUI.NifLoader.nif_extension()
# => ".so" (Linux) | ".dylib" (macOS) | ".dll" (Windows)

# Get the target triple
DesktopUI.NifLoader.target_triple()
# => "x86_64-linux-gnu"
```

## 1. Problem Statement

The DesktopUI application needs a runtime NIF loader that can locate and load the compiled NIF library. The loader must handle platform-specific file extensions, multiple possible locations, and provide helpful error messages when loading fails.

### Impact Analysis

**Runtime Impact (HIGH):**
- NIF must be loaded before any Graphics operations
- Loading happens at application startup
- Graceful degradation when NIF is not available

**Cross-Platform Impact (HIGH):**
- Different file extensions (.so, .dylib, .dll)
- Different possible locations (priv, prebuilt)
- Platform-specific error messages

**Developer Experience Impact (MEDIUM):**
- Clear error messages for debugging
- Easy to test with custom paths

### Goals

Create DesktopUI.NifLoader module that:
1. Locates the NIF library using multiple search paths
2. Loads the NIF using `:erlang.load_nif/2`
3. Handles platform-specific file extensions
4. Provides helpful error messages
5. Supports custom path override for testing

## 2. Solution Overview

### High-Level Approach

1. **Path Resolution** - Try multiple locations in order
2. **Platform Detection** - Use correct file extension for platform
3. **NIF Loading** - Use Erlang's `:erlang.load_nif/2`
4. **Error Handling** - Provide clear, actionable error messages

### Path Resolution Order

1. Explicit path if provided to `load_nif/1`
2. `priv/desktop_ui_nif.{ext}` (standard location)
3. `priv/native/desktop_ui_nif.{ext}` (alternate location)
4. `priv/prebuilt/{triple}/desktop_ui_nif.{ext}` (prebuilt binaries)

### Design Decisions

**File Extensions:**
- Linux: `.so`
- macOS: `.dylib`
- Windows: `.dll`

**Error Handling:**
- Return `:ok` on success
- Return `{:error, reason}` on failure
- Log warnings for missing files
- Provide platform-specific hints

## 3. Implementation Plan

### Step 1: Create Module Skeleton

- [x] Create `lib/desktop_ui/nif_loader.ex`
- [x] Add module documentation
- [x] Define types

### Step 2: Implement Helper Functions

- [x] Implement `priv_dir/0`
- [x] Implement `nif_extension/0`
- [x] Implement `nif_path/0`

### Step 3: Implement Loading Functions

- [x] Implement `load_nif/0`
- [x] Implement `load_nif/1` with custom path
- [x] Implement `load_nif_from_path/1` private function

### Step 4: Write Tests

- [x] Test path resolution
- [x] Test loading success/failure
- [x] Test custom path override
- [x] Test error messages

## 4. Task Checklist

### Implementation Tasks
- [x] Create NifLoader module
- [x] Implement priv_dir/0
- [x] Implement nif_extension/0
- [x] Implement nif_path/0
- [x] Implement load_nif/0
- [x] Implement load_nif/1

### Testing Tasks
- [x] Create test file
- [x] Test priv_dir/0
- [x] Test nif_extension/0
- [x] Test nif_path/0
- [x] Test load_nif/0
- [x] Test load_nif/1

### Final Tasks
- [x] All tests pass (28/28 tests)
- [x] Update planning document
- [ ] Write summary document
- [ ] Commit changes
- [ ] Request merge permission
