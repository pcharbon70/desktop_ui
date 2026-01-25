# Section 2.7: Runtime Integration with SDL2 (Jido Event Bridge) - Feature Planning Document

**Feature Branch:** `feature/section-2.7-runtime-sdl2-integration`
**Status:** Pending
**Created:** 2026-01-25
**Planning Document:** `notes/planning/poc/phase-2-graphics-bridge.md`
**Dependencies:** Section 2.6 (DesktopUI.Renderer.SDL2), Section 1.7 (DesktopUI.Runtime)

## 1. Problem Statement

DesktopUI currently has a complete Graphics API with SDL2 bindings, a real SDL2 renderer, and a Runtime supervisor with event bridging capabilities. However, these pieces are not integrated:

- The Runtime uses `DesktopUI.Renderer.Mock` by default instead of `DesktopUI.Renderer.SDL2`
- The Runtime's event bridge is only called manually via `bridge_event/2` - there is no automatic event polling
- SDL2 is not initialized automatically when the Runtime starts
- No SDL2 window is created automatically
- SDL events are not polled and translated to signals in a loop
- There is no graceful shutdown handling for SDL2 resources

Developers can:
- Manually initialize SDL2 via `DesktopUI.Graphics.sdl_init()`
- Manually create windows via `DesktopUI.Graphics.create_window/4`
- Manually poll events via `DesktopUI.Graphics.poll_event()`
- Manually bridge events to signals via `DesktopUI.Runtime.bridge_event/2`

But they cannot:
- Have SDL2 automatically initialize when starting the Runtime
- Have a window automatically created on startup
- Have events automatically polled and bridged to signals
- Have a complete "fire and forget" desktop UI experience

## 2. Solution Overview

Update `DesktopUI.Runtime` to integrate SDL2 graphics and automatic event handling:

1. **Initialize SDL2 on startup** - Call `Graphics.sdl_init()` during `init/1`
2. **Create SDL2 window automatically** - Create window with title and dimensions from options
3. **Replace mock renderer with SDL2 renderer** - Pass `DesktopUI.Renderer.SDL2` to RenderingCoordinator
4. **Add event polling loop** - Use `Process.send_after/3` to periodically poll SDL events
5. **Translate SDL events to Jido signals** - Convert raw SDL events to signal types
6. **Publish signals to :desktop_ui signal bus** - Use existing `bridge_event/2` or direct publishing
7. **Handle SDL_QUIT for graceful shutdown** - Trigger application shutdown on quit event
8. **Store window bounds for hit testing** - Keep window dimensions for future event routing

### Architecture Changes

```
Before (Section 1.7):
DesktopUI.Runtime (Supervisor)
    ├── Jido.Signal.Bus (:desktop_ui)
    ├── RenderingCoordinator (with Mock renderer)
    └── Root Component (Jido.Agent)

After (Section 2.7):
DesktopUI.Runtime (Supervisor with GenServer capabilities)
    ├── Jido.Signal.Bus (:desktop_ui)
    ├── RenderingCoordinator (with SDL2 renderer)
    └── Root Component (Jido.Agent)

Event Polling Loop:
Runtime.handle_info(:poll_sdl_events)
    ├── Graphics.poll_event()
    ├── Convert SDL event to Jido signal
    ├── Jido.Signal.Bus.publish()
    └── Process.send_after(self(), :poll_sdl_events, 16)  # ~60 FPS
```

### SDL Event to Signal Translation

| SDL Event | Jido Signal | Notes |
|-----------|-------------|-------|
| `{:quit}` | `Signals.Quit` | Triggers graceful shutdown |
| `{:mouse_button_down, button, x, y}` | `Signals.MousePressed` | With hit testing for target_id |
| `{:key_down, keycode, modifiers}` | `Signals.KeyPressed` | Convert atom keycode to string |
| `{:key_up, keycode, modifiers}` | `Signals.KeyReleased` | Convert atom keycode to string |
| `{:window_event, :resized, w, h}` | `Signals.WindowResized` | Store new dimensions |

## 3. Technical Details

### 3.1 Runtime State Structure

The Runtime will maintain state for SDL2 integration:

```elixir
%{
  bus: atom(),
  window_id: non_neg_integer() | nil,
  window_width: pos_integer(),
  window_height: pos_integer(),
  fullscreen: boolean(),
  event_polling: boolean(),
  poll_interval: pos_integer()
}
```

### 3.2 Updated start_link Options

```elixir
@type option ::
        {:root_component, module()}
        | {:root_component_opts, keyword()}
        | {:renderer, atom() | {atom(), atom()}}
        | {:bus, atom()}
        | {:name, atom()}
        | {:window_title, String.t()}           # NEW
        | {:window_width, pos_integer()}        # NEW
        | {:window_height, pos_integer()}       # NEW
        | {:fullscreen, boolean()}              # NEW
        | {:event_polling, boolean()}           # NEW
        | {:poll_interval, pos_integer()}       # NEW
```

### 3.3 Event Polling Loop

```elixir
@impl true
def handle_info(:poll_sdl_events, state) do
  case poll_all_events(state) do
    {:quit, _state} ->
      {:stop, :normal, state}

    {:continue, new_state} ->
      Process.send_after(self(), :poll_sdl_events, state.poll_interval)
      {:noreply, new_state}
  end
end
```

## 4. Success Criteria

1. **SDL2 initializes on startup** - Runtime calls `Graphics.sdl_init()` during init
2. **Window creates automatically** - Runtime creates SDL2 window with configured title/dimensions
3. **SDL2 renderer is used** - RenderingCoordinator uses `DesktopUI.Renderer.SDL2` instead of Mock
4. **Event polling works** - Runtime polls SDL events at ~60 FPS
5. **Keyboard events publish signals** - KeyDown/KeyUp events become KeyPressed/KeyReleased signals
6. **Mouse events publish signals** - MouseButtonDown events become MousePressed signals
7. **Quit event triggers shutdown** - SDL_QUIT event triggers graceful shutdown
8. **Window resize is tracked** - Window dimensions stored and WindowResized signal published
9. **Graceful cleanup works** - SDL2 resources cleaned up on shutdown
10. **Initialization failures are handled** - Falls back to Mock renderer if SDL2 fails
11. **All 8 tests pass** - New tests pass, existing tests continue to pass

## 5. Implementation Plan

### Task 2.7.1: Read existing Runtime implementation
Understand current Runtime structure before making changes.

### Task 2.7.2: Add SDL2 initialization options to start_link
Add new options: window_title, window_width, window_height, fullscreen, event_polling, poll_interval.

### Task 2.7.3: Initialize SDL2 in init/1
Call Graphics.sdl_init() during initialization with graceful fallback.

### Task 2.7.4: Create SDL2 window on startup
Create window with configured options and store window_id in state.

### Task 2.7.5: Update RenderingCoordinator to use SDL2 renderer
Change default renderer from Mock to SDL2.

### Task 2.7.6: Implement event polling loop
Add handle_info(:poll_sdl_events, state) callback with Process.send_after/3.

### Task 2.7.7: Implement SDL event to signal translation
Translate SDL events to Jido signals and publish to bus.

### Task 2.7.8: Handle SDL_QUIT for graceful shutdown
Implement shutdown on quit event.

### Task 2.7.9: Add SDL2 resource cleanup
Implement terminate/2 callback to destroy window.

## 6. Testing Strategy

### Unit Tests (8 tests)

1. test_runtime_creates_sdl_window_on_startup/1
2. test_runtime_polls_sdl_events/1
3. test_sdl_mouse_events_publish_mouse_pressed_signals/1
4. test_sdl_keyboard_events_publish_key_pressed_signals/1
5. test_quit_event_publishes_quit_signal/1
6. test_render_draws_to_sdl_window_via_coordinator/1
7. test_runtime_cleans_up_sdl_resources_on_shutdown/1
8. test_sdl_initialization_failure_is_handled_gracefully/1

## 7. Progress Tracking

- [x] 2.7.1 Read existing Runtime implementation
- [x] 2.7.2 Add SDL2 initialization options to start_link
- [x] 2.7.3 Initialize SDL2 in init/1
- [x] 2.7.4 Create SDL2 window on startup
- [x] 2.7.5 Update RenderingCoordinator to use SDL2 renderer
- [x] 2.7.6 Implement event polling loop
- [x] 2.7.7 Implement SDL event to signal translation
- [x] 2.7.8 Handle SDL_QUIT for graceful shutdown
- [x] 2.7.9 Add SDL2 resource cleanup
- [x] 2.7.10 Write unit tests (14 tests written)
- [x] 2.7.11 Run tests and fix failures
- [x] 2.7.12 Update planning document
- [x] 2.7.13 Write summary document
