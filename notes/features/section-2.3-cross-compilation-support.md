# Section 2.3: Cross-Compilation Support - Feature Planning Document

**Feature Branch:** `feature/section-2.3-cross-compilation-support`
**Base Branch:** `feature/multi-platform-build`
**Status:** COMPLETE
**Created:** 2026-01-29
**Last Updated:** 2026-01-29

## Current Status

**Overall:** Complete

**Tasks:**
- [x] 2.3.1 Implement `get_target/0` with environment variable support
- [x] 2.3.2 Implement target triple validation
- [x] 2.3.3 Implement target-specific output naming
- [x] 2.3.4 Add documentation for cross-compilation usage
- [x] 2.3.5 Create examples for common cross-compile scenarios
- [x] 2.3.6 Add unit tests for cross-compilation
- [x] 2.3.7 Add integration tests for cross-compilation

## What Works

**Cross-Compilation Support (180 lines added to compiler):**
- `validate_target/1` - Validates target triple format and components
- `get_output_path/1` - Accepts target parameter for target-specific output naming
- `is_cross_compile?/1` - Detects if target is different from native platform
- `valid_architecture?/1` - Checks if architecture is valid (permissive)
- `valid_os?/1` - Checks if OS is valid (permissive)
- `valid_environment?/1` - Checks if environment is valid (permissive)
- `format_target_error/2` - Creates helpful error messages for invalid targets
- Updated `get_target/0` - Validates target before compilation
- Updated `compile_nif/0` - Handles invalid target errors
- Updated `compile_with_zig/4` - Uses target-specific output path

**Target-Specific Output Naming:**
- Native builds: `desktop_ui_nif.{ext}` (unchanged)
- Cross builds: `desktop_ui_nif.{target}.{ext}`
- Example: `desktop_ui_nif.x86_64-windows-gnu.dll`

**Unit Tests (16 tests, all passing):**
- Target validation for valid and invalid targets
- Target component validation (arch, OS, environment)
- Cross-compilation scenarios (Linux→Windows, Linux→macOS, Linux→ARM64)
- Error message quality verification
- Integration tests

## What's Next

Ready to commit and merge to multi-platform-build branch.

Section 2.4 will create Zig build configuration (`build.zig`) for Zig-native builds as an alternative to Mix compiler.

## How to Run

```bash
# Cross-compile for Windows from Linux
DESKTOPUI_TARGET=x86_64-windows-gnu mix compile

# Cross-compile for macOS aarch64 from Linux
DESKTOPUI_TARGET=aarch64-macos-none mix compile

# Cross-compile for Linux ARM64 from x86_64
DESKTOPUI_TARGET=aarch64-linux-gnu mix compile

# Native compilation (default)
mix compile
```

## 1. Problem Statement

Section 2.2 added Zig as the primary compiler and the `DESKTOPUI_TARGET` environment variable is partially implemented. However, we need to enhance cross-compilation support with proper validation, target-specific output naming, and better documentation.

### Impact Analysis

**Cross-Compilation Impact (HIGH):**
- Developers can build for any target from any platform
- Multiple target NIFs can coexist for testing
- Clear error messages for invalid targets

**Developer Experience Impact (MEDIUM):**
- Helpful error messages when target format is wrong
- Clear documentation for cross-compilation scenarios
- Examples for common cross-compile workflows

**Build System Impact (LOW):**
- Target validation happens early
- Output files are named by target for clarity

### Goals

Enhance cross-compilation support so that:
1. Target triples are validated before compilation starts
2. Cross-compiled NIFs have target-specific names
3. Invalid targets produce helpful error messages
4. Cross-compilation is well-documented with examples

## 2. Solution Overview

### High-Level Approach

1. **Target Validation** - Add `validate_target/1` to check target format
2. **Target-Specific Output** - Name output files as `desktop_ui_nif.{target}.{ext}`
3. **Error Messages** - Provide helpful errors for invalid targets
4. **Documentation** - Add cross-compilation guide with examples
5. **Tests** - Unit tests for validation, integration tests for scenarios

### Design Decisions

**Target Validation:**
- Check target triple format: `{arch}-{os}-{env}`
- Known architectures: x86_64, aarch64, arm64, arm, x86, riscv64
- Known OS: linux, macos, windows
- Known environments: gnu, none, musl, musleabi

**Output Naming:**
- Native builds: `desktop_ui_nif.{ext}` (unchanged)
- Cross builds: `desktop_ui_nif.{target}.{ext}`
- Example: `desktop_ui_nif.x86_64-windows-gnu.dll`

**Validation Strategy:**
- Strict validation for explicit targets
- Permissive validation - allow Zig to handle unknown targets
- Helpful error messages for malformed targets

## 3. Implementation Plan

### Step 1: Add Target Validation

- [ ] Create `validate_target/1` function
- [ ] Add target triple format validation
- [ ] Add known architecture/os/environment lists
- [ ] Return helpful errors for invalid targets

### Step 2: Add Target-Specific Output Naming

- [ ] Create `get_output_path/1` that accepts target
- [ ] Update `build_zig_command/4` to use target-specific output
- [ ] Update `compile_with_makefile/3` to use target-specific output
- [ ] Keep native builds using simple naming

### Step 3: Enhance Error Messages

- [ ] Add target validation to `get_target/0`
- [ ] Provide examples of valid targets in errors
- [ ] Link to documentation in error messages

### Step 4: Add Documentation

- [ ] Create cross-compilation guide
- [ ] Add examples for common scenarios
- [ ] Document target triple format
- [ ] Document known targets

### Step 5: Write Tests

- [ ] Test target validation for valid targets
- [ ] Test target validation for invalid targets
- [ ] Test target-specific output naming
- [ ] Test cross-compilation scenarios

## 4. Task Checklist

### Implementation Tasks
- [x] Create `validate_target/1` function
- [x] Create `get_output_path/1` with target parameter
- [x] Update `get_target/0` to validate target
- [x] Update Zig compilation to use target-specific output
- [x] Update Makefile compilation to use target-specific output
- [x] Add cross-compilation documentation

### Testing Tasks
- [x] Test valid target triples are accepted
- [x] Test invalid target triples are rejected
- [x] Test target-specific output naming
- [x] Test cross-compilation from Linux to Windows
- [x] Test cross-compilation from Linux to macOS
- [x] Test native compilation still works

### Final Tasks
- [x] All tests pass (16/16)
- [x] Update planning document
- [ ] Write summary document
- [ ] Commit changes
- [ ] Request merge permission

## 5. API Design

### New Internal Functions

```elixir
@spec validate_target(String.t()) :: :ok | {:error, :invalid_target}
def validate_target(target)

@spec get_output_path(String.t() | nil) :: Path.t()
def get_output_path(target \\ nil)

@spec is_cross_compile?() :: boolean()
def is_cross_compile?()

@spec format_target_error(String.t()) :: String.t()
def format_target_error(target)
```

### Target Triple Format

```
{arch}-{os}-{env}

Examples:
x86_64-linux-gnu
aarch64-linux-gnu
x86_64-macos-none
aarch64-macos-none
x86_64-windows-gnu
```

### Supported Targets

| Architecture | OS | Environment | Target Triple |
|---|---|---|---|
| x86_64 | linux | gnu | x86_64-linux-gnu |
| aarch64 | linux | gnu | aarch64-linux-gnu |
| x86_64 | macos | none | x86_64-macos-none |
| aarch64 | macos | none | aarch64-macos-none |
| x86_64 | windows | gnu | x86_64-windows-gnu |

## 6. Cross-Compilation Examples

### Linux to Windows

```bash
DESKTOPUI_TARGET=x86_64-windows-gnu mix compile
# Output: priv/desktop_ui_nif.x86_64-windows-gnu.dll
```

### Linux to macOS (Apple Silicon)

```bash
DESKTOPUI_TARGET=aarch64-macos-none mix compile
# Output: priv/desktop_ui_nif.aarch64-macos-none.dylib
```

### Linux to Linux ARM64

```bash
DESKTOPUI_TARGET=aarch64-linux-gnu mix compile
# Output: priv/desktop_ui_nif.aarch64-linux-gnu.so
```

### Native Build (no override)

```bash
mix compile
# Output: priv/desktop_ui_nif.{ext}
```

## 7. Error Handling

### Invalid Target Format

```
Invalid target triple: "invalid-format"

Expected format: {arch}-{os}-{env}
Example: x86_64-linux-gnu

See documentation for supported targets.
```

### Unknown Architecture

```
Invalid target triple: "unknown_arch-linux-gnu"

Unknown architecture: "unknown_arch"

Supported architectures: x86_64, aarch64, arm64, arm, x86, riscv64
```

### Unknown OS

```
Invalid target triple: "x86_64-unknown_os-gnu"

Unknown OS: "unknown_os"

Supported OS: linux, macos, windows
```

## 8. Testing Strategy

### Unit Tests

**Target Validation:**
- Test all known valid targets are accepted
- Test invalid targets are rejected with helpful errors
- Test malformed targets produce clear errors

**Output Naming:**
- Test native builds use simple naming
- Test cross builds use target-specific naming
- Test target is correctly inserted in filename

**Cross-Compilation Detection:**
- Test `is_cross_compile?/0` returns correct values

### Integration Tests

**Cross-Compilation Scenarios:**
- Test Linux to Windows compilation
- Test Linux to macOS compilation
- Test native compilation unchanged
- Test multiple targets can coexist

## 9. Dependencies

**Internal Modules:**
- `DesktopUI.Nif.Platform` - For native target detection
- `DesktopUI.Nif.Zig` - For Zig cross-compilation

**External Dependencies:**
- Zig 0.11.0 or later (for cross-compilation)

## 10. Notes and Considerations

### Target Triple Permissiveness

We should be permissive with target triples:
- Validate format but allow unknown architectures/OS
- Zig may support targets we don't know about
- Provide warnings for unknown targets, not errors

### Output File Naming

Target-specific naming helps with:
- Storing multiple target builds
- Identifying which binary is which
- Testing cross-compiled NIFs

### Future Enhancements

**Auto-Detection:**
- Detect target from NifLoader preference
- Automatically select appropriate NIF at runtime

**Pre-built Binaries:**
- Use target-specific naming for pre-built NIFs
- Download from releases based on target

**Testing:**
- Run tests under QEMU for cross-compiled targets
- Automate cross-compilation in CI
