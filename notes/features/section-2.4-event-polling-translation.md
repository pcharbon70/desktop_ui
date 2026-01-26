# Section 2.4: Event Polling and Translation - Feature Planning Document

**Feature Branch:** `feature/section-2.4-event-polling-translation`
**Status:** Complete
**Created:** 2025-01-24
**Planning Document:** `notes/planning/poc/phase-2-graphics-bridge.md`

## Overview

This feature implements SDL2 event polling and translation, allowing the DesktopUI framework to capture OS input events (keyboard, mouse, window) and translate them to Elixir terms. This is critical for interactive UI applications.

## Problem Statement

DesktopUI needs to capture and handle user input events from the operating system. Without event polling:
- No way to detect when user closes the window (quit)
- No way to detect mouse clicks and movements
- No way to detect keyboard input
- No way to detect window resize/focus events
- Cannot build interactive UI applications

This requires:
1. **Event polling** - Non-blocking and blocking event retrieval from SDL2
2. **Event translation** - Convert SDL2 events to Elixir-friendly terms
3. **Key mapping** - Map SDL keycodes to Elixir atoms
4. **Modifier tracking** - Track shift, ctrl, alt states

## Solution Overview

We will extend the existing NIF with SDL2 event polling functions:

1. Add SDL2 event structures and polling functions to the NIF
2. Implement 2 new NIF functions for event polling
3. Create event translation layer in C (SDL2 events -> Elixir terms)
4. Add keycode mapping table
5. Extend DesktopUI.Graphics module with public event API
6. Add comprehensive unit tests

## Technical Details

### SDL2 Event Architecture

```
OS Input (Keyboard/Mouse/Window)
    ↓ captured by
SDL2 Event Queue
    ↓ polled by
C NIF (desktop_ui_nif.so)
    ↓ translates to
Elixir Terms ({:quit}, {:mouse_button_down, ...}, etc.)
    ↓ consumed by
DesktopUI Application
```

### SDL2 Event Types to Support

| SDL Event | Elixir Term | Description |
|-----------|-------------|-------------|
| SDL_QUIT | `{:quit}` | User requested app exit |
| SDL_MOUSEBUTTONDOWN | `{:mouse_button_down, button, x, y}` | Mouse button pressed |
| SDL_MOUSEBUTTONUP | `{:mouse_button_up, button, x, y}` | Mouse button released |
| SDL_MOUSEMOTION | `{:mouse_motion, x, y, xrel, yrel}` | Mouse moved |
| SDL_KEYDOWN | `{:key_down, keycode, modifiers}` | Key pressed |
| SDL_KEYUP | `{:key_up, keycode, modifiers}` | Key released |
| SDL_WINDOWEVENT | `{:window_event, event_id, data}` | Window state changed |

### Keycode Mapping

SDL keycodes will be mapped to Elixir atoms:
- `SDLK_a` -> `:key_a`
- `SDLK_b` -> `:key_b`
- ...
- `SDLK_ESCAPE` -> `:key_escape`
- `SDLK_RETURN` -> `:key_return`
- `SDLK_SPACE` -> `:key_space`
- `SDLK_BACKSPACE` -> `:key_backspace`
- `SDLK_TAB` -> `:key_tab`
- etc.

### Modifier State

Modifiers will be represented as a map with boolean keys:
```elixir
%{
  shift: boolean(),
  ctrl: boolean(),
  alt: boolean(),
  gui: boolean()  # Windows/cmd key
}
```

### File Structure

```
desktop_ui/
├── c_src/
│   └── desktop_ui_nif.c     # Extended with event polling
├── lib/desktop_ui/
│   └── graphics.ex          # Extended with event API
└── test/desktop_ui/
    └── graphics_test.exs    # Extended with event tests
```

## Implementation Tasks

### Task 2.4.1: Implement poll_event/0
**Status:** ✅ Complete
**Description:** Non-blocking event poll
**NIF Signature:** `nif_poll_event() -> event | :no_event | {:error, reason}`
**Elixir API:** `poll_event() :: term() | :no_event | {:error, String.t()}`
**SDL Function:** `SDL_PollEvent`

### Task 2.4.2: Implement wait_event/1
**Status:** ✅ Complete
**Description:** Blocking event poll with timeout (milliseconds)
**NIF Signature:** `nif_wait_event(timeout) -> event | :timeout | {:error, reason}`
**Elixir API:** `wait_event(timeout) :: term() | :timeout | {:error, String.t()}`
**SDL Function:** `SDL_WaitEventTimeout`

### Task 2.4.3: Translate SDL_QUIT event
**Status:** ✅ Complete
**Description:** Translate quit event to Elixir term
**Elixir Term:** `{:quit}`

### Task 2.4.4: Translate SDL_MOUSEBUTTONDOWN event
**Status:** ✅ Complete
**Description:** Translate mouse button down event
**Elixir Term:** `{:mouse_button_down, button, x, y}`
**Button Values:** `:left`, `:middle`, `:right`, `:x1`, `:x2`

### Task 2.4.5: Translate SDL_MOUSEBUTTONUP event
**Status:** ✅ Complete
**Description:** Translate mouse button up event
**Elixir Term:** `{:mouse_button_up, button, x, y}`

### Task 2.4.6: Translate SDL_MOUSEMOTION event
**Status:** ✅ Complete
**Description:** Translate mouse motion event
**Elixir Term:** `{:mouse_motion, x, y, xrel, yrel}`
**Note:** xrel/yrel are relative motion since last event

### Task 2.4.7: Translate SDL_KEYDOWN event
**Status:** ✅ Complete
**Description:** Translate key down event
**Elixir Term:** `{:key_down, keycode, modifiers}`
**Keycodes:** Elixir atoms like `:key_a`, `:key_escape`, etc.

### Task 2.4.8: Translate SDL_KEYUP event
**Status:** ✅ Complete
**Description:** Translate key up event
**Elixir Term:** `{:key_up, keycode, modifiers}`

### Task 2.4.9: Translate SDL_WINDOWEVENT event
**Status:** ✅ Complete
**Description:** Translate window event
**Elixir Term:** `{:window_event, event_id, data}`

## Testing Strategy

### Unit Tests (8 tests required)

1. **Test poll_event returns :no_event when idle** - Verify no events when queue empty
2. **Test poll_event returns event after user action** - Verify event retrieval
3. **Test quit event translates correctly** - Verify SDL_QUIT -> {:quit}
4. **Test mouse click event includes coordinates** - Verify button, x, y
5. **Test mouse motion includes relative coordinates** - Verify x, y, xrel, yrel
6. **Test key press includes keycode and modifiers** - Verify key and modifiers
7. **Test window resize event translates** - Verify window events
8. **Test wait_event times out correctly** - Verify timeout behavior

### Integration Strategy

- Tests require SDL2 to be available
- Tests marked with `@tag :sdl2` and `@tag :event`
- Tests should handle both SDL2 available and unavailable scenarios
- Note: Actual user action tests require manual testing or SDL event injection

## Success Criteria

1. ✅ poll_event/0 returns events or :no_event
2. ✅ wait_event/1 supports timeout and returns :timeout
3. ✅ SDL_QUIT translates to {:quit}
4. ✅ Mouse button events include button, x, y
5. ✅ Mouse motion events include x, y, xrel, yrel
6. ✅ Keyboard events include keycode and modifiers
7. ✅ Window events translate correctly
8. ✅ 8 unit tests passing
9. ✅ No compiler warnings
10. ✅ Graceful error handling when SDL2 missing

## Progress

### 2025-01-24
- [x] Created feature branch `feature/section-2.4-event-polling-translation`
- [x] Created feature planning document
- [x] Implementation complete - all 9 tasks done
- [x] All tests passing (298 tests, 100% pass rate)
- [x] Ready for merge

## Notes/Considerations

### Risk Assessment

**High Risk Items:**
- Event polling must be non-blocking to not stall the BEAM VM
- Event translation must handle all SDL event types safely
- Memory leaks if event data not properly freed

**Medium Risk Items:**
- Keycode mapping must be comprehensive
- Modifier state must be accurate across platforms
- Window event IDs vary across SDL versions

**Low Risk Items:**
- Basic event polling (SDL_PollEvent)
- Event tuple creation
- Timeout handling for wait_event

### Design Decisions

1. **Non-blocking by default:** poll_event/0 returns :no_event when queue empty
2. **Blocking with timeout:** wait_event/1 allows waiting with timeout
3. **Event atoms:** Events use tagged tuples for pattern matching
4. **Modifier map:** Modifiers use map for clarity and extensibility
5. **Keycode atoms:** Keycodes use atoms for pattern matching in cond/case

### Platform Support

**Primary:** Linux (X11/Wayland with SDL2)
- X11 keyboard mapping
- Wayland keyboard mapping

**Secondary:** macOS (with SDL2 via Homebrew)
- Cocoa keyboard mapping

**Future:** Windows (requires different build approach)
- Win32 keyboard mapping

### Testing Without SDL2

Tests will use ExUnit tags to skip event-dependent tests when SDL2 is unavailable. Note that testing actual user-triggered events requires either:
1. Manual testing
2. SDL event injection (complex)
3. Mock event queue for unit testing

### Event Translation Mapping

**Mouse Buttons:**
- SDL_BUTTON_LEFT -> `:left`
- SDL_BUTTON_MIDDLE -> `:middle`
- SDL_BUTTON_RIGHT -> `:right`
- SDL_BUTTON_X1 -> `:x1`
- SDL_BUTTON_X2 -> `:x2`

**Window Event IDs:**
- SDL_WINDOWEVENT_SHOWN -> `:shown`
- SDL_WINDOWEVENT_HIDDEN -> `:hidden`
- SDL_WINDOWEVENT_EXPOSED -> `:exposed`
- SDL_WINDOWEVENT_MOVED -> `:moved`
- SDL_WINDOWEVENT_RESIZED -> `:resized`
- SDL_WINDOWEVENT_SIZE_CHANGED -> `:size_changed`
- SDL_WINDOWEVENT_MINIMIZED -> `:minimized`
- SDL_WINDOWEVENT_MAXIMIZED -> `:maximized`
- SDL_WINDOWEVENT_RESTORED -> `:restored`
- SDL_WINDOWEVENT_ENTER -> `:enter`
- SDL_WINDOWEVENT_LEAVE -> `:leave`
- SDL_WINDOWEVENT_FOCUS_GAINED -> `:focus_gained`
- SDL_WINDOWEVENT_FOCUS_LOST -> `:focus_lost`
- SDL_WINDOWEVENT_CLOSE -> `:close`

## References

- Planning document: `notes/planning/poc/phase-2-graphics-bridge.md`
- Section 2.3 summary: `notes/summaries/section-2.3-renderer-drawing-primitives.md`
- SDL2 Event documentation: https://wiki.libsdl.org/SDL2/CategoryEvent
- SDL2 Keyboard documentation: https://wiki.libsdl.org/SDL2/CategoryKeyboard
- Branch: `feature/section-2.4-event-polling-translation`
- Target branch: `poc`
