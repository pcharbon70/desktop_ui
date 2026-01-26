# Section 1.7: DesktopUI.Runtime (Bootstrap & Event Bridge) - Summary

**Date:** 2025-01-24
**Branch:** `feature/section-1.7-runtime`
**Status:** Complete

## Overview

Section 1.7 implements the DesktopUI.Runtime, a bootstrap supervisor and event bridge for DesktopUI applications. The Runtime is NOT a central orchestrator—agents are autonomous and communicate via signals. The Runtime's responsibilities are:
1. Bootstrap the supervision tree with signal bus, renderer, and components
2. Bridge external events (SDL, keyboard, etc.) to Jido signals
3. Manage lifecycle (startup/shutdown) of all processes

## Implementation Summary

### Files Created

1. **lib/desktop_ui/runtime.ex** (295 lines)
   - Bootstrap supervisor using `Supervisor` behavior
   - Starts children in order: Jido.Signal.Bus, RenderingCoordinator, Root Component
   - Event bridge functions converting SDL-style events to Jido signals
   - Public API: `start_link/1`, `bridge_event/2`, `get_bus/0`, `get_root_component/0`

2. **test/desktop_ui/runtime_test.exs** (430 lines)
   - Comprehensive test suite with 19 tests (all passing)
   - Test helper for unique runtime per test
   - Tests for: start_link, child processes, event bridge, shutdown

### Files Modified

1. **lib/desktop_ui/signals.ex**
   - Added `KeyReleased` signal module
   - Added `MousePressed` signal module
   - Both follow CloudEvents v1.0.2 spec via Jido.Signal

## Key Design Decisions

### Architecture Pattern

**Runtime as Bootstrap Supervisor** (NOT central orchestrator):
```
DesktopUI.Runtime (Supervisor)
    ├── Jido.Signal.Bus (:desktop_ui)
    ├── RenderingCoordinator
    └── Root Component (Jido.Agent.Server)
```

Agents are autonomous and communicate via signals. The Runtime only:
1. Bootstraps the supervision tree
2. Bridges external events to signals
3. Manages lifecycle (start/stop)

### Event Bridge Protocol

External events are converted to Jido signals:

```elixir
# Keyboard events
{:sdl_keydown, key: :up, mod: []}  → KeyPressed signal
{:sdl_keyup, key: :escape, mod: [:ctrl]}  → KeyReleased signal

# Mouse events
{:sdl_mouseup, x: 100, y: 50, button: :left, target_id: :btn}  → Clicked signal
{:sdl_mousedown, x: 50, y: 25, button: :right, target_id: :menu}  → MousePressed signal
{:sdl_mousemove, x: 10, y: 20}  → {:ok, :mouse_move} (no signal)

# App events
{:sdl_quit}  → Quit signal
```

### Root Component Discovery

**Issue:** `Jido.Agent.Server.start_link/2` with `name: :root_component` does NOT register the process with the Erlang Process registry using that name.

**Solution:** The Runtime finds the root component by querying the supervisor's children:
```elixir
def get_root_component(runtime_name) do
  children = Supervisor.which_children(runtime_name)
  # Find child with id: Jido.Agent.Server
end
```

This requires the runtime name (for named runtimes) or uses the default `DesktopUI.Runtime` module name.

### Test Isolation

Each test creates a unique runtime with:
- Unique runtime name: `:"runtime_#{System.unique_integer()}"`
- Unique bus name: `:"bus_#{System.unique_integer()}"`
- Unique renderer name: `:"renderer_#{System.unique_integer()}"`

Cleanup uses `try/catch` blocks to handle already-stopped processes gracefully.

## Event Bridge Implementation Details

### Signal Conversion

| Event Type | Conversion | Result |
|------------|------------|--------|
| `{:sdl_keydown, data}` | KeyPressed.new(%{key: key_str, modifiers: mods}) | Signal published |
| `{:sdl_keyup, data}` | KeyReleased.new(%{key: key_str, modifiers: mods}) | Signal published |
| `{:sdl_mouseup, data}` | Clicked.new(%{target_id, button, x, y}) | Signal published (if target_id) |
| `{:sdl_mousedown, data}` | MousePressed.new(%{target_id, button, x, y}) | Signal published (if target_id) |
| `{:sdl_mousemove, data}` | `{:ok, :mouse_move}` | Acknowledged only |
| `{:sdl_quit}` | Quit.new(%{}) | Signal published |
| Unknown | `{:error, :unknown_event_type}` | Error returned |

### Type Conversion

Atom keys are converted to strings for signal schema compliance:
```elixir
key_str = if is_atom(key), do: Atom.to_string(key), else: key
```

## Public API

### Starting the Runtime

```elixir
# With all options
{:ok, pid} = DesktopUI.Runtime.start_link(
  name: :my_runtime,
  root_component: MyCounterComponent,
  renderer: {DesktopUI.Renderer.Mock, :mock_renderer},
  bus: :my_bus
)

# Or in application supervisor
children = [
  {DesktopUI.Runtime,
    root_component: MyCounterComponent,
    renderer: DesktopUI.Renderer.Mock,
    bus: :desktop_ui
  }
]
```

### Bridging Events

```elixir
# Keyboard event to default bus
:ok = DesktopUI.Runtime.bridge_event({:sdl_keydown, key: :up, mod: []})

# Mouse event with target to custom bus
:ok = DesktopUI.Runtime.bridge_event(
  {:sdl_mouseup, x: 100, y: 50, button: :left, target_id: :btn_click},
  bus: :my_bus
)

# Quit event
:ok = DesktopUI.Runtime.bridge_event({:sdl_quit})
```

### Getting the Root Component

```elixir
# Get root component from named runtime
pid = DesktopUI.Runtime.get_root_component(:my_runtime)

# Get root component from default runtime
pid = DesktopUI.Runtime.get_root_component()
```

## Test Results

```
Finished in 4.4 seconds (0.00s async, 4.4s sync)
19 tests, 0 failures
```

All tests cover:
- Starting with required and optional options
- Starting child processes (bus, coordinator, root component)
- Event bridge for all supported event types
- Shutdown and cleanup
- Error handling for missing options

## Integration Notes

### With RenderingCoordinator

The Runtime starts the RenderingCoordinator with the renderer and bus options. The coordinator subscribes to `desktop_ui.state.**` signals to trigger re-renders.

### With Root Components

Root components must:
1. `use DesktopUI.Elm` (which includes `use Jido.Agent`)
2. Implement `init/1`, `update/2`, and `view/1` callbacks
3. Be startable via `Jido.Agent.Server.start_link/2`

Components publish `StateChanged` signals after state changes, which the RenderingCoordinator receives.

## Known Limitations

1. **Hit Testing**: Mouse events require `target_id` to be provided by the caller. Hit testing will be implemented in Phase 2 (Graphics Bridge).

2. **Event Types**: Only SDL-style events are currently supported. Future work may add:
   - Window events (resize, move, focus)
   - Drag and drop events
   - Text input events

3. **Process Naming**: `get_root_component/0` requires the runtime name because `Jido.Agent.Server` doesn't register with the provided name in the Process registry.

## Next Steps

Per the planning document, the next phase is:
- **Section 1.8**: Counter component as Jido agent with signal handling
- **Section 1.9**: Expanded integration tests for signal flow

## References

- Feature document: `notes/features/section-1.7-runtime.md`
- Planning document: `notes/planning/poc/phase-1-architecture-validation.md`
- Code: `lib/desktop_ui/runtime.ex`
- Tests: `test/desktop_ui/runtime_test.exs`
