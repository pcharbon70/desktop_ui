# Section 2.1: Zig Detection and Installation - Feature Planning Document

**Feature Branch:** `feature/section-2.1-zig-detection`
**Base Branch:** `feature/multi-platform-build`
**Status:** COMPLETE
**Created:** 2026-01-29
**Last Updated:** 2026-01-29

## Current Status

**Overall:** Complete

**Tasks:**
- [x] 2.1.1 Create `lib/desktop_ui/nif/zig.ex` module
- [x] 2.1.2 Implement `installed?/0` to check Zig availability
- [x] 2.1.3 Implement `version/0` to get Zig version
- [x] 2.1.4 Implement `find_executable/0` to locate Zig binary
- [x] 2.1.5 Implement `minimum_version/0` to return required version
- [x] 2.1.6 Implement `check_version/1` to verify version compatibility

## What Works

**DesktopUI.Nif.Zig Module (288 lines):**
- `installed?/0` - Checks if Zig is in PATH
- `find_executable/0` - Locates Zig binary
- `version/0` - Returns Zig version with caching
- `minimum_version/0` - Returns "0.11.0"
- `recommended_version/0` - Returns "0.13.0"
- `check_version/1` - Validates version compatibility
- `installation_instructions/0` - Platform-specific guidance
- `not_found_error/0` - Helpful error message

**Unit Tests (28 tests, all passing):**
- Zig detection tests
- Version parsing tests
- Version compatibility tests
- Installation instruction tests
- Integration tests

## What's Next

Ready to commit and merge to multi-platform-build branch.

Section 2.2 will integrate Zig compiler into the Mix compiler as the primary build method.

## How to Run

```bash
# After implementation
DesktopUI.Nif.Zig.installed?()
# => true | false

DesktopUI.Nif.Zig.version()
# => {:ok, "0.13.0"} | {:error, :not_found}

DesktopUI.Nif.Zig.check_version("0.13.0")
# => :ok | {:error, :incompatible_version}
```

## 1. Problem Statement

The DesktopUI NIF build system currently uses Makefile as the primary build method. Phase 2 will integrate Zig as an additional build method for better cross-compilation support. We need a module to detect Zig installation and verify version compatibility.

### Impact Analysis

**Build System Impact (HIGH):**
- Zig will become preferred build method when available
- Fallback to Makefile when Zig is not installed
- Version checking ensures compatibility

**Cross-Compilation Impact (HIGH):**
- Zig provides first-class cross-compilation support
- Single binary includes all tooling (Clang, LLD)
- No need for platform-specific toolchains

**Developer Experience Impact (MEDIUM):**
- Clear error messages when Zig is not found
- Helpful installation instructions by platform
- Version compatibility feedback

### Goals

Create DesktopUI.Nif.Zig module that:
1. Detects if Zig is installed
2. Returns Zig version string
3. Verifies version meets minimum requirements (0.11.0)
4. Provides helpful installation instructions when not found
5. Caches version information for performance

## 2. Solution Overview

### High-Level Approach

1. **Executable Detection** - Use System.find_executable/1 to find zig
2. **Version Parsing** - Run `zig version` and parse output
3. **Version Comparison** - Compare against minimum version (0.11.0)
4. **Caching** - Cache version in process dictionary
5. **Error Messages** - Provide platform-specific installation instructions

### Design Decisions

**Minimum Version:** 0.11.0
- Stable cross-compilation support
- Widely available across platforms
- Well-tested API surface

**Version Format:**
- Zig version output: `0.13.0`
- Parse using regex: `~r/^zig (?<version>\d+\.\d+\.\d+)/`

**Caching Strategy:**
- Store version in process dictionary on first call
- Subsequent calls return cached value
- Cache key: `:desktop_ui_zig_version`

**Installation Instructions by Platform:**
| Platform | Installation Command |
|---|---|
| Linux | `curl -O https://ziglang.org/download/0.13.0/zig-linux-*.tar.xz` |
| macOS | `brew install zig` |
| Windows | Download from https://ziglang.org/download |

## 3. Implementation Plan

### Step 1: Create Module Skeleton

- [x] Create `lib/desktop_ui/nif/zig.ex`
- [x] Add module documentation
- [x] Define types
- [x] Add @spec definitions

### Step 2: Implement Detection Functions

- [x] Implement `find_executable/0`
- [x] Implement `installed?/0`
- [x] Implement `version/0`

### Step 3: Implement Version Functions

- [x] Implement `minimum_version/0`
- [x] Implement `check_version/1`
- [x] Add version comparison logic
- [x] Add caching for performance

### Step 4: Add Error Messages

- [x] Add installation instructions helper
- [x] Add platform-specific guidance
- [x] Add helpful error messages

### Step 5: Write Tests

- [x] Create `test/desktop_ui/nif/zig_test.exs`
- [x] Test Zig detection (installed/not found)
- [x] Test version parsing
- [x] Test version compatibility checking
- [x] Test error messages

## 4. Task Checklist

### Implementation Tasks
- [x] Create DesktopUI.Nif.Zig module
- [x] Implement find_executable/0
- [x] Implement installed?/0
- [x] Implement version/0
- [x] Implement minimum_version/0
- [x] Implement check_version/1

### Testing Tasks
- [x] Create Zig test file
- [x] Test installed? returns correct values
- [x] Test version parsing works
- [x] Test version compatibility
- [x] Test minimum_version function
- [x] Test helpful error messages

### Final Tasks
- [x] All tests pass (28/28)
- [x] Update planning document
- [ ] Write summary document
- [ ] Commit changes
- [ ] Request merge permission

## 5. API Design

### Public Functions

```elixir
@spec installed?() :: boolean()
def installed?()

@spec version() :: {:ok, String.t()} | {:error, :not_found}
def version()

@spec find_executable() :: {:ok, Path.t()} | {:error, :not_found}
def find_executable()

@spec minimum_version() :: String.t()
def minimum_version()

@spec check_version(String.t() | Version Requirement) :: :ok | {:error, :incompatible_version}
def check_version(version)

@spec installation_instructions() :: String.t()
def installation_instructions()
```

### Version Requirements

- **Minimum Version:** 0.11.0
- **Recommended Version:** 0.13.0 or later

### Installation Instructions by Platform

| Platform | Installation Method |
|----------|-------------------|
| Linux | Download tar.xz from ziglang.org |
| macOS | `brew install zig` |
| Windows | Download .zip from ziglang.org |
