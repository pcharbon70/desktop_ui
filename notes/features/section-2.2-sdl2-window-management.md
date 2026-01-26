# Section 2.2: SDL2 Initialization and Window Management - Feature Planning Document

**Feature Branch:** `feature/section-2.2-sdl2-window-management`
**Status:** ✅ Complete
**Created:** 2025-01-24
**Planning Document:** `notes/planning/poc/phase-2-graphics-bridge.md`

## Overview

This feature implements SDL2 window management functions, allowing the DesktopUI framework to create and manage native windows. This is the first step in connecting Elixir to real graphics operations through SDL2.

## Problem Statement

DesktopUI needs to create and manage native windows to display UI components. Without SDL2 window management:
- No visible output can be shown to users
- No event capture from the OS window system
- No graphics context for drawing operations

This requires:
1. **SDL2 initialization** - Set up the SDL2 video subsystem
2. **Window creation** - Create native windows with specified properties
3. **Window lifecycle management** - Track and clean up window resources
4. **Window property manipulation** - Resize and rename windows

## Solution Overview

We will extend the existing NIF with SDL2 window management functions:

1. Add SDL2 headers and link SDL2 libraries in the build
2. Implement window resource tracking using ERL_NIF_RESOURCE
3. Add 6 new NIF functions for window management
4. Extend DesktopUI.Graphics module with public window API
5. Add comprehensive unit tests

## Technical Details

### SDL2 Integration

```
Elixir (DesktopUI.Graphics)
    ↓ calls NIF functions
C NIF (desktop_ui_nif.so)
    ↓ links to SDL2
SDL2 Library (libSDL2.so)
    ↓ creates
Native Window (X11/Wayland/Windows/macOS)
```

### NIF Resource Management

Windows will be tracked using Erlang's resource system:
- `ERL_NIF_RESOURCE` type for safe window handle management
- Automatic cleanup when Elixir terms are garbage collected
- Reference counting for shared window access

### Window State Structure

```c
typedef struct {
    SDL_Window* window;
    uint32_t window_id;
    int width;
    int height;
    char title[256];
} window_resource_t;
```

### File Structure

```
desktop_ui/
├── c_src/
│   └── desktop_ui_nif.c     # Extended with window functions
├── lib/desktop_ui/
│   └── graphics.ex          # Extended with window API
├── Makefile                 # Updated to link SDL2
└── test/desktop_ui/
    └── graphics_test.exs    # Extended with window tests
```

### Dependencies

**System Requirements:**
- SDL2 development library (existing requirement from Section 2.1)
- C compiler (gcc/clang)
- Erlang/Elixir development headers

**Mix Dependencies:**
- No new Elixir dependencies

## Implementation Tasks

### Task 2.2.1: Implement sdl_init/0
**Status:** Pending
**Description:** Initialize SDL2 video subsystem
**NIF Signature:** `nif_sdl_init() -> {:ok, %{}} | {:error, reason}`
**Elixir API:** `sdl_init() :: {:ok, map()} | {:error, String.t()}`

### Task 2.2.2: Implement create_window/4
**Status:** Pending
**Description:** Create SDL2 window with title, width, height, flags
**NIF Signature:** `nif_create_window(title, width, height, flags) -> {:ok, window_ref} | {:error, reason}`
**Elixir API:** `create_window(title, width, height, opts \\ []) :: {:ok, reference()} | {:error, String.t()}`

### Task 2.2.3: Implement destroy_window/1
**Status:** Pending
**Description:** Cleanup window resources
**NIF Signature:** `nif_destroy_window(window_ref) -> :ok | {:error, reason}`
**Elixir API:** `destroy_window(window_ref) :: :ok | {:error, String.t()}`

### Task 2.2.4: Implement get_window_size/1
**Status:** Pending
**Description:** Query current window dimensions
**NIF Signature:** `nif_get_window_size(window_ref) -> {:ok, {width, height}} | {:error, reason}`
**Elixir API:** `get_window_size(window_ref) :: {:ok, {pos_integer(), pos_integer()}} | {:error, String.t()}`

### Task 2.2.5: Implement set_window_size/3
**Status:** Pending
**Description:** Resize window
**NIF Signature:** `nif_set_window_size(window_ref, width, height) -> :ok | {:error, reason}`
**Elixir API:** `set_window_size(window_ref, width, height) :: :ok | {:error, String.t()}`

### Task 2.2.6: Implement set_window_title/2
**Status:** Pending
**Description:** Update window title
**NIF Signature:** `nif_set_window_title(window_ref, title) -> :ok | {:error, reason}`
**Elixir API:** `set_window_title(window_ref, title) :: :ok | {:error, String.t()}`

### Task 2.2.7: Add resource tracking for window lifecycle
**Status:** Pending
**Description:** Implement ERL_NIF_RESOURCE for window handles

## Testing Strategy

### Unit Tests (8 tests required)

1. **Test SDL2 initialization** - Verify SDL2 initializes without errors
2. **Test window creation** - Verify window creates with specified dimensions
3. **Test window destruction** - Verify window destroys cleanly
4. **Test get_window_size** - Verify returns correct dimensions
5. **Test set_window_size** - Verify resizes window
6. **Test set_window_title** - Verify updates title
7. **Test multiple windows** - Verify multiple windows can coexist
8. **Test invalid window** - Verify destroying invalid window returns error

### Integration Strategy

- Tests require display (X11, Wayland, Windows, macOS)
- Tests should pass even when SDL2 is not installed (skip with clear message)
- Use ExUnit `tag: :sdl2` for SDL-dependent tests
- Cleanup should destroy all SDL resources

## Success Criteria

1. ✅ SDL2 initializes successfully via `sdl_init/0`
2. ✅ Window can be created with `create_window/4`
3. ✅ Window properties can be queried with `get_window_size/1`
4. ✅ Window can be resized with `set_window_size/3`
5. ✅ Window title can be updated with `set_window_title/2`
6. ✅ Window resources are cleaned up with `destroy_window/1`
7. ✅ Multiple windows can coexist
8. ✅ 8 unit tests passing
9. ✅ No compiler warnings
10. ✅ Graceful error handling when SDL2 missing

## Progress

### 2025-01-24
- [x] Created feature branch `feature/section-2.2-sdl2-window-management`
- [x] Created feature planning document
- [x] Implementation complete
- [x] All tests passing (280 tests)
- [x] Ready for merge

## Notes/Considerations

### Risk Assessment

**High Risk Items:**
- SDL2 event loop requires careful thread management
- Window resource leaks if not properly cleaned up
- SDL2 initialization may fail on headless systems

**Medium Risk Items:**
- Platform-specific window behavior (X11 vs Wayland vs Windows vs macOS)
- Multiple window management and event routing

**Low Risk Items:**
- Basic window creation and property manipulation
- Resource type implementation

### Platform Support

**Primary:** Linux (Ubuntu/Debian with `libsdl2-dev`)
- X11 window system
- Wayland window system (with SDL2 support)

**Secondary:** macOS (with SDL2 via Homebrew)
- Cocoa window system

**Future:** Windows (requires different build approach)
- Win32 API

### NIF Safety

- All window operations are non-blocking
- Resource handles prevent dangling pointers
- SDL2 errors are captured and returned to Elixir
- Window cleanup happens even if Elixir crashes

### Testing Without SDL2

Tests will use ExUnit tags to skip SDL-dependent tests:
```elixir
@tag :sdl2
test "creates a window" do
  # ... test code
end
```

Test setup will check for SDL2 availability and skip appropriately.

## References

- Planning document: `notes/planning/poc/phase-2-graphics-bridge.md`
- Section 2.1 summary: `notes/summaries/section-2.1-c-nif-foundation.md`
- SDL2 documentation: https://wiki.libsdl.org/SDL2/CategoryWindow
- Erlang NIF documentation: http://erlang.org/doc/man/erl_nif.html
- Branch: `feature/section-2.2-sdl2-window-management`
- Target branch: `poc`
