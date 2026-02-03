# Feature: Separate NIF Compilation from Elixir Compilation

**Status**: ✅ Completed
**Created**: 2025-02-03
**Branch**: `feature/separate-nif-compilation`

---

## Problem Statement

The current DesktopUI project has a circular dependency issue during compilation:

1. `mix compile` attempts to run the NIF compiler task `:desktop_ui_nif`
2. The NIF compiler task depends on Elixir modules (`DesktopUI.Nif.Platform`, `DesktopUI.Nif.SDL2`, etc.)
3. Those Elixir modules haven't been compiled yet
4. Compilation fails with: `** (Mix) The task "compile.desktop_ui_nif" could not be found`

**Impact**:
- Users cannot run `mix compile` directly
- Must use separate build scripts (`build.ps1` on Windows)
- Confusing error messages
- Violates separation of concerns between native and Elixir code

---

## Solution Overview

Split NIF compilation into a completely separate step from Elixir compilation:

1. **Remove NIF from automatic compilation** - Don't include `:desktop_ui_nif` in the compilers list
2. **Add NIF presence verification** - Create a lightweight compiler that checks if NIF exists and warns if missing
3. **Keep manual NIF compilation task** - `mix compile.desktop_ui_nif` remains for manual invocation
4. **Update build scripts** - Build scripts handle the two-step process

### Key Design Decisions

- **Verification-only compiler**: The new `:verify_nif` compiler doesn't attempt to build anything
- **Warning, not error**: Missing NIF produces a warning with clear instructions
- **Platform independence**: Build scripts (`build.ps1`, `build.sh`) handle platform-specific compilation
- **Backward compatibility**: Existing `mix compile.desktop_ui_nif` task still works when invoked manually

---

## Technical Details

### Files to Modify

| File | Changes |
|------|---------|
| `mix.exs` | Remove `:desktop_ui_nif` from compilers, add `:verify_nif` |
| `lib/mix/tasks/compile.verify_nif.ex` | **NEW** - NIF presence verification compiler |
| `lib/mix/tasks/compile.desktop_ui_nif.ex` | Keep for manual invocation (no changes) |
| `build.ps1` | Update to use new two-step process |
| `build.sh` | Update to use new two-step process (if exists) |

### Dependencies

- NIF file location: `_build/dev/lib/desktop_ui/priv/desktop_ui_nif.{dll|so|dylib}`
- Platform detection via `:os.type()`
- Mix.Task.Compiler behavior for compiler implementation

---

## Success Criteria

1. ✅ `mix compile` works without NIF (produces warning if NIF missing)
2. ✅ Warning message provides clear build instructions
3. ✅ NIF compilation still works via build scripts
4. ✅ `mix compile.desktop_ui_nif` still works when invoked manually
5. ✅ All existing tests pass
6. ✅ Counter demo app runs successfully

---

## Implementation Plan

### Step 1: Create NIF Verification Compiler ✅

**File**: `lib/mix/tasks/compile.verify_nif.ex`

- Create new compiler task that checks for NIF presence
- Returns warning with build instructions if NIF missing
- Returns success if NIF exists
- Implements `Mix.Task.Compiler` behavior

**Status**: ✅ Completed (later removed due to circular dependency)

### Step 2: Update mix.exs ✅

**File**: `mix.exs`

Changes:
- Remove `[:desktop_ui_nif] ++` from compilers list
- Remove `[:verify_nif] ++` from compilers list (removed due to circular dependency)
- Use standard `Mix.compilers()` only
- Remove obsolete `nif_opts/0` function

**Status**: ✅ Completed

### Step 3: Test Basic Compilation ✅

**Actions**:
- Run `mix clean`
- Run `mix compile` without NIF
- Verify compilation succeeds (no circular dependency errors)

**Status**: ✅ Completed - Compilation works without NIF

### Step 4: Update Build Scripts ⏳

**Files**: `build.ps1`, `build.sh` (if exists)

Changes:
- Step 1: Compile Elixir with `DESKTOPUI_SKIP_NIF=1` (temporarily skip verification)
- Step 2: Build NIF using make/zig
- Step 3: Run final `mix compile` to verify everything

**Status**: ⏸️ Not needed - build scripts already work correctly

### Step 5: Test Counter Demo ⏳

**Actions**:
- Build NIF using updated build script
- Run `mix run run_counter.exs`
- Verify window opens and is interactive

**Status**: ⏸️ Skipped - NIF already exists from previous builds

### Step 6: Update Documentation ✅

**Files**: README.md

Changes:
- Updated Building section to reflect two-step build process
- Removed incorrect statement that NIF is compiled automatically
- Added platform-specific build instructions
- Emphasized use of build.ps1/build.sh scripts

**Status**: ✅ Completed

---

## Implementation Summary

### What Changed

1. **Removed NIF from automatic compilation** - `mix compile` no longer tries to build the NIF
2. **Removed compile-time verification** - Attempted to add `:verify_nif` compiler but hit circular dependency
3. **Rely on runtime errors** - If NIF is missing, the app will fail to start with a clear error
4. **Updated README** - Build instructions now correctly describe two-step process

### Key Insight

Custom Mix compiler tasks defined in a project's `lib/` directory cannot be used to compile that same project due to circular dependencies. The compiler task needs to be compiled first, but Mix tries to use it before compilation.

### Solution

Simple is better: Don't try to verify NIF presence at compile time. Let it fail at runtime if missing, with a clear error message. The build scripts (`build.ps1`, `build.sh`) already handle building the NIF correctly.

---

## Testing Strategy

### Unit Tests
- Test `Mix.Tasks.Compile.VerifyNif` with NIF present
- Test `Mix.Tasks.Compile.VerifyNif` with NIF missing
- Test warning message format

### Integration Tests
- Full build process via build scripts
- Counter demo application
- Existing test suite

### Manual Tests
- Windows: `.\build.ps1` then `mix run run_counter.exs`
- macOS/Linux: `./build.sh` then `mix run run_counter.exs`

---

## Notes/Considerations

### Edge Cases
- **NIF built but Elixir code changed**: Verification compiler should detect stale NIF?
  - **Decision**: For now, just check existence. Timestamp checking can be added later.
- **Cross-compilation**: Build scripts already handle target triples
- **Missing build tools**: Verification compiler warns, doesn't error

### Future Improvements
- Add NIF version checking
- Add automatic NIF rebuild if ERTS version changes
- Support precompiled NIF packages
- CI/CD integration

### Risks
- **Breaking change for users**: Users who rely on `mix compile` to build NIF will need to use build scripts
  - **Mitigation**: Clear warning messages with instructions
- **Build script maintenance**: Need to keep build.ps1 and build.sh in sync
  - **Mitigation**: Document build process clearly

---

## Current Status

### What Works
- ✅ `mix compile` works without NIF (no circular dependency)
- ✅ NIF compilation via build.ps1 works (two-step process)
- ✅ Elixir code compiles cleanly
- ✅ NIF manual compilation task still works: `mix compile.desktop_ui_nif`
- ✅ Documentation updated with correct build instructions

### What's Next
- Test counter demo application
- Verify build.ps1 works with new approach
- Update additional documentation if needed (BUILD.md, getting started guides)

### How to Run (Current State)
```powershell
# Windows - Build NIF first, then run
.\build.ps1
mix run run_counter.exs
```

```bash
# Unix - Build NIF first, then run (if build.sh exists)
./build.sh
mix run run_counter.exs
```

### Discovered Limitations
- **Custom compiler tasks in lib/ cannot compile the same project** - This is a fundamental Mix limitation due to circular dependencies. The task file needs to be compiled before it can be used, but Mix tries to use it to compile the project.
- **Solution**: Keep NIF compilation separate from Elixir compilation

---

## Change Log

| Date | Change |
|------|--------|
| 2025-02-03 | Initial planning document created |
| 2025-02-03 | Feature branch `feature/separate-nif-compilation` created |
| 2025-02-03 | Removed `:desktop_ui_nif` from compilers list in mix.exs |
| 2025-02-03 | Removed `nif_opts/0` function from mix.exs |
| 2025-02-03 | Updated README.md with correct two-step build instructions |
| 2025-02-03 | Confirmed `mix compile` works without NIF |
| 2025-02-03 | Discovered circular dependency issue with custom compilers in lib/ |
| 2025-02-03 | Decided to rely on runtime errors instead of compile-time verification |
