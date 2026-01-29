# Section 2.2: Zig Compiler Integration - Feature Planning Document

**Feature Branch:** `feature/section-2.2-zig-compiler-integration`
**Base Branch:** `feature/multi-platform-build`
**Status:** COMPLETE
**Created:** 2026-01-29
**Last Updated:** 2026-01-29

## Current Status

**Overall:** Complete

**Tasks:**
- [x] 2.2.1 Create `compile_with_zig/4` function in Mix compiler
- [x] 2.2.2 Implement Zig target triple mapping
- [x] 2.2.3 Implement Zig command construction
- [x] 2.2.4 Implement Zig output parsing for errors
- [x] 2.2.5 Implement fallback to Makefile when Zig unavailable
- [x] 2.2.6 Add `choose_compiler/0` strategy function
- [x] 2.2.7 Update `compile_nif/0` to use compiler choice
- [x] 2.2.8 Add DESKTOPUI_PREFER_COMPILER override
- [x] 2.2.9 Add unit tests for Zig compilation

## What Works

**Mix Compiler Integration (260 lines added to compiler):**
- `compile_with_zig/4` - Zig compilation with full ERTS/SDL2 integration
- `map_target_for_zig/1` - Target triple validation (our format is Zig-compatible)
- `build_zig_command/4` - Zig cc command construction with all required flags
- `get_output_path/0` - Platform-specific output path generation
- `choose_compiler/0` - Compiler selection strategy with DESKTOPUI_PREFER_COMPILER support
- `choose_compiler_default/0` - Default: Zig preferred, Makefile fallback
- `try_makefile_fallback/0` - Makefile availability check
- Updated `compile_nif/0` - Uses selected compiler instead of only Makefile

**Unit Tests (13 tests, all passing):**
- Compiler selection with DESKTOPUI_PREFER_COMPILER
- Target triple compatibility validation
- Zig integration (when Zig is installed)
- Compiler workflow tests
- Cross-compilation environment tests
- SDL2 detection integration

## What's Next

Ready to commit and merge to multi-platform-build branch.

Section 2.3 will add explicit cross-compilation support via DESKTOPUI_TARGET environment variable with target triple validation and target-specific output naming.

## How to Run

```bash
# After implementation
# Compile with Zig (preferred, if available)
mix compile

# Force Zig
DESKTOPUI_PREFER_COMPILER=zig mix compile

# Force Makefile
DESKTOPUI_PREFER_COMPILER=makefile mix compile

# Skip NIF compilation
DESKTOPUI_SKIP_NIF=1 mix compile

# Cross-compile with Zig
DESKTOPUI_TARGET=aarch64-linux-gnu mix compile
```

## 1. Problem Statement

The Mix compiler currently only uses Makefile for NIF compilation. Section 2.1 added Zig detection, but we haven't integrated Zig as an actual compiler yet. We need to add Zig compilation support to enable the benefits of Zig (first-class cross-compilation, single binary toolchain, etc.).

### Impact Analysis

**Build System Impact (HIGH):**
- Zig will become the preferred compiler when available
- Makefile remains as fallback for systems without Zig
- Users can explicitly choose compiler via DESKTOPUI_PREFER_COMPILER

**Cross-Compilation Impact (HIGH):**
- Zig provides superior cross-compilation support
- No need for platform-specific toolchains
- Single command can target any platform

**Developer Experience Impact (MEDIUM):**
- Clear logging of which compiler is being used
- Helpful error messages when both compilers fail
- Version checking ensures compatible Zig is used

### Goals

Integrate Zig into the Mix compiler so that:
1. Zig is tried first when available and version-compatible
2. Falls back to Makefile when Zig is not available
3. User can override compiler choice via DESKTOPUI_PREFER_COMPILER
4. Both compilers use the same ERTS/SDL2 detection
5. Error handling provides clear diagnostics

## 2. Solution Overview

### High-Level Approach

1. **Add Zig Compilation Function** - Create `compile_with_zig/4` parallel to `compile_with_makefile/3`
2. **Compiler Selection Strategy** - Add `choose_compiler/0` to determine which compiler to use
3. **Target Triple Mapping** - Map our target format to Zig's target format
4. **Command Construction** - Build `zig cc` command with correct flags
5. **Output Parsing** - Parse Zig output for error diagnostics
6. **Main Compiler Update** - Update `compile_nif/0` to use selected compiler

### Design Decisions

**Compiler Preference Order:**
1. DESKTOPUI_PREFER_COMPILER=zig → Use Zig
2. DESKTOPUI_PREFER_COMPILER=makefile → Use Makefile
3. DESKTOPUI_PREFER_COMPILER=none → Skip compilation
4. Default: Try Zig first, fall back to Makefile

**Zig Command Structure:**
```bash
zig cc \
  -target {zig_target} \
  -O2 \
  -fPIC \
  -shared \
  -I {erts_include} \
  {sdl2_cflags} \
  c_src/desktop_ui_nif.c \
  -o priv/desktop_ui_nif.{ext} \
  {sdl2_ldflags}
```

**Target Triple Mapping:**
| Our Format | Zig Format | Notes |
|---|---|---|
| x86_64-linux-gnu | x86_64-linux-gnu | Same |
| aarch64-linux-gnu | aarch64-linux-gnu | Same |
| x86_64-macos-none | x86_64-macos-none | Same |
| aarch64-macos-none | aarch64-macos-none | Same |
| x86_64-windows-gnu | x86_64-windows-gnu | Same |

**Zig Output Parsing:**
- Parse error lines with `file:line:column: error:` format
- Parse warning lines similarly
- Include full Zig output in diagnostic for debugging

## 3. Implementation Plan

### Step 1: Add Zig Compilation Function

- [ ] Create `compile_with_zig/4` function
- [ ] Add Zig executable detection
- [ ] Add version compatibility check
- [ ] Return same result format as `compile_with_makefile/3`

### Step 2: Implement Target Triple Mapping

- [ ] Add `map_target_for_zig/1` function
- [ ] Map our target triples to Zig format
- [ ] Handle unknown targets gracefully

### Step 3: Implement Zig Command Construction

- [ ] Build `zig cc` command with target
- [ ] Add optimization flags (-O2)
- [ ] Add PIC flag (-fPIC)
- [ ] Add shared library flag (-shared)
- [ ] Add ERTS include path
- [ ] Add SDL2 flags

### Step 4: Implement Output Parsing

- [ ] Parse Zig error output
- [ ] Create Mix.Task.Compiler diagnostics
- [ ] Include relevant error snippets

### Step 5: Add Compiler Selection Strategy

- [ ] Create `choose_compiler/0` function
- [ ] Check DESKTOPUI_PREFER_COMPILER
- [ ] Default to Zig when available
- [ ] Fall back to Makefile

### Step 6: Update Main Compiler

- [x] Update `compile_nif/0` to use compiler choice
- [x] Add logging for which compiler is used
- [x] Aggregate errors from all attempted compilers

### Step 7: Write Tests

- [x] Mock System.cmd for Zig command tests
- [x] Test target triple mapping
- [x] Test compiler selection logic
- [x] Test error output parsing
- [x] Test fallback behavior

## 4. Task Checklist

### Implementation Tasks
- [x] Create `compile_with_zig/4` function
- [x] Implement `map_target_for_zig/1`
- [x] Implement `choose_compiler/0` function
- [x] Update `compile_nif/0` to use selected compiler
- [x] Add compiler selection logging
- [x] Add DESKTOPUI_PREFER_COMPILER support

### Testing Tasks
- [x] Create Zig compiler test file
- [x] Test Zig command construction
- [x] Test target triple mapping
- [x] Test compiler selection logic
- [x] Test fallback behavior
- [x] Test error output parsing

### Final Tasks
- [x] All tests pass (13/13)
- [x] Update planning document
- [ ] Write summary document
- [ ] Commit changes
- [ ] Request merge permission

## 5. API Design

### New Internal Functions

```elixir
@spec compile_with_zig(Path.t(), String.t(), String.t(), list()) ::
  {:ok, []} | {:error, [diagnostic()]}
def compile_with_zig(erts_include, target, output_path, opts)

@spec map_target_for_zig(String.t()) :: {:ok, String.t()} | {:error, :unknown_target}
def map_target_for_zig(target_triple)

@spec choose_compiler() :: {:ok, :zig | :makefile | :none}
def choose_compiler()
```

### Environment Variables

| Variable | Values | Description |
|---|---|---|
| DESKTOPUI_PREFER_COMPILER | zig, makefile, none | Force specific compiler |
| DESKTOPUI_TARGET | target triple | Cross-compilation target |
| DESKTOPUI_SKIP_NIF | 1 | Skip NIF compilation |

### Compiler Selection Flow

```
1. Check DESKTOPUI_PREFER_COMPILER
   ├─ "zig" → Try Zig, error if unavailable
   ├─ "makefile" → Try Makefile, error if unavailable
   ├─ "none" → Skip compilation
   └─ unset → Continue

2. Default Strategy
   ├─ Check Zig availability + version
   │  ├─ Available and compatible → Use Zig
   │  └─ Not available → Try Makefile
   └─ If Makefile also unavailable → Return error
```

## 6. Error Handling

### Zig Not Available

When Zig is selected but unavailable:
- Return warning diagnostic (if fallback available)
- Return error diagnostic (if forced via DESKTOPUI_PREFER_COMPILER)

### Zig Version Incompatible

When Zig version is incompatible:
- Log warning
- Fall back to Makefile (if available)
- Return error if forced via DESKTOPUI_PREFER_COMPILER

### Compilation Errors

When Zig compilation fails:
- Parse error output for diagnostics
- Return `{:error, [diagnostic]}`
- Include full output in diagnostic message

### Both Compilers Fail

When both Zig and Makefile fail:
- Aggregate errors from both attempts
- Return combined diagnostic
- Indicate which compilers were tried

## 7. Testing Strategy

### Unit Tests

**Zig Command Construction:**
- Test command is built correctly
- Test target triple is mapped correctly
- Test flags are in correct order

**Compiler Selection:**
- Test DESKTOPUI_PREFER_COMPILER=zig forces Zig
- Test DESKTOPUI_PREFER_COMPILER=makefile forces Makefile
- Test default prefers Zig when available
- Test fallback to Makefile when Zig unavailable

**Target Mapping:**
- Test all known target triples map correctly
- Test unknown target returns error

**Output Parsing:**
- Test error lines are parsed correctly
- Test warnings are parsed correctly
- Test multi-line errors are handled

### Integration Tests

**End-to-End Compilation:**
- Test Zig compiles NIF successfully
- Test output file is correct
- Test manifest is written

**Fallback Behavior:**
- Test fallback to Makefile works
- Test error when both compilers unavailable

## 8. Dependencies

**Internal Modules:**
- `DesktopUI.Nif.Zig` - For Zig detection and version checking
- `DesktopUI.Nif.Platform` - For target triple detection
- `DesktopUI.Nif.Erts` - For ERTS include directory
- `DesktopUI.Nif.SDL2` - For SDL2 flags

**External Dependencies:**
- Zig 0.11.0 or later (for Zig compilation)
- make (for Makefile fallback)

## 9. Notes and Considerations

### Zig vs Makefile Output Paths

Both compilers should output to the same location:
```
priv/desktop_ui_nif.{ext}
```

### Zig Cache

Zig creates a `zig-cache` directory. This should be added to `.gitignore`.

### Windows Path Handling

Zig on Windows handles forward slashes correctly, so no special path conversion needed.

### Incremental Compilation

Zig has its own build cache. The Mix manifest will still be written for consistency.

### Cross-Compilation

Zig cross-compilation is transparent - just pass `-target`. No sysroot needed for most targets.

### Future Enhancements

**build.zig Integration:**
- Could add `build.zig` file for Zig-native builds
- Would allow `zig build` workflow

**Cache Zig Binary:**
- Cache Zig executable path in Application environment
- Avoid repeated System.find_executable calls

**Parallel Compilation:**
- Could try both compilers in parallel
- Use first successful result
- Complex, may not be worth it
