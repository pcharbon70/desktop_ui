# Section 1.7: DesktopUI.Runtime (Bootstrap & Event Bridge) - Feature Document

**Feature Branch:** `feature/section-1.7-runtime`
**Status:** Complete
**Created:** 2025-01-24
**Completed:** 2025-01-24
**Planning Document:** `notes/planning/poc/phase-1-architecture-validation.md`

## Overview

Create the Runtime that acts as a bootstrap supervisor and event bridge for DesktopUI applications. The Runtime is NOT a central orchestrator—agents are autonomous. The Runtime's job is to bootstrap the supervision tree and bridge external events (SDL, keyboard, etc.) to Jido signals.

## Tasks

### 1.7.1 Define child_spec/1 for OTP supervision integration
- [x] Create `lib/desktop_ui/runtime.ex`
- [x] Define `child_spec/1` for inclusion in application supervisor
- [x] Support options for bus name, renderer, root component

### 1.7.2 Implement start_link/2 with root component and renderer options
- [x] Create `start_link/2` function accepting options
- [x] Accept root component module and initial options
- [x] Accept renderer configuration (module or {module, name})
- [x] Accept signal bus name (default: :desktop_ui)

### 1.7.3 Start Jido.Signal.Bus with name :desktop_ui
- [x] Start Jido.Signal.Bus as child of supervisor
- [x] Configure bus with provided name
- [x] Handle bus startup failures

### 1.7.4 Start RenderingCoordinator agent
- [x] Start RenderingCoordinator as child of supervisor
- [x] Pass renderer configuration from options
- [x] Pass signal bus name

### 1.7.5 Start root component as Jido agent
- [x] Start root component using Jido.Agent.Server
- [x] Pass component options from configuration
- [x] Store root component PID for event routing (via supervisor child query)

### 1.7.6 Register root component with RenderingCoordinator
- [x] Publish ComponentRegister signal for root component
- [x] Include component_id, module, and PID
- [x] Handle registration errors gracefully

### 1.7.7 Implement event bridge for converting external events to signals
- [x] Create `bridge_event/2` function to convert external events to signals
- [x] Support SDL event types (keyboard, mouse, quit)
- [x] Publish converted signals to bus
- [x] Document event format for future SDL integration

### 1.7.8 Handle shutdown and cleanup of all agents
- [x] Implement proper supervisor shutdown strategy
- [x] Ensure all children terminate gracefully
- [x] Clean up signal bus on shutdown

## Files to Create

| File | Purpose | Status |
|------|---------|--------|
| `lib/desktop_ui/runtime.ex` | Runtime bootstrap supervisor | Complete |
| `test/desktop_ui/runtime_test.exs` | Runtime tests | Complete |

## Files to Modify

| File | Changes | Status |
|------|---------|--------|
| `lib/desktop_ui/signals.ex` | Added KeyReleased and MousePressed signals | Complete |

## Design Decisions

### Architecture Pattern

The Runtime follows the **Supervisor as Bootstrap** pattern:

```
Application Supervisor
    ↓
DesktopUI.Runtime (DynamicSupervisor)
    ↓
├── Jido.Signal.Bus (:desktop_ui)
├── RenderingCoordinator
└── Root Component (Jido.Agent)
```

**Key Design Principle**: Runtime is NOT a central orchestrator. Agents are autonomous and communicate via signals. Runtime only:
1. Bootstraps the supervision tree
2. Bridges external events to signals
3. Manages lifecycle (start/stop)

### Supervisor Strategy

Use `DynamicSupervisor` for flexibility:
- Children can be added/removed dynamically
- Each child runs independently
- Crashes are isolated per child
- Strategy: `one_for_one` (default)

### Child Specification Structure

```elixir
%{
  id: :signal_bus,
  start: {Jido.Signal.Bus, :start_link, [[name: :desktop_ui]]},
  restart: :permanent,
  type: :supervisor
}
%{
  id: :rendering_coordinator,
  start: {DesktopUI.RenderingCoordinator, :start_link, [[
    renderer: renderer,
    bus: :desktop_ui,
    name: :rendering_coordinator
  ]]},
  restart: :permanent,
  type: :worker
}
%{
  id: :root_component,
  start: {Jido.Agent.Server, :start_link, [[
    agent: root_component_module,
    name: :root_component
  ]]},
  restart: :permanent,
  type: :worker
}
```

### Public API

```elixir
# Start the runtime with root component
{:ok, pid} = DesktopUI.Runtime.start_link(
  root_component: MyCounterComponent,
  renderer: DesktopUI.Renderer.Mock,
  bus: :desktop_ui
)

# Or include in application supervisor
children = [
  {DesktopUI.Runtime,
    root_component: MyCounterComponent,
    renderer: DesktopUI.Renderer.Mock,
    bus: :desktop_ui
  }
]

# Bridge external events to signals
DesktopUI.Runtime.bridge_event(pid, {:sdl_keydown, key: :escape, mod: [:ctrl]})
DesktopUI.Runtime.bridge_event(pid, {:sdl_mouseup, x: 100, y: 50, button: :left})
DesktopUI.Runtime.bridge_event(pid, {:sdl_quit})
```

### Event Bridge Protocol

External events are converted to Jido signals:

```elixir
# Keyboard event
{:sdl_keydown, key: :up, mod: []}
  → KeyPressed signal with key: :up, modifiers: []

# Mouse event
{:sdl_mouseup, x: 100, y: 50, button: :left}
  → Clicked signal with target_id (determined by hit testing), button: :left

# Quit event
{:sdl_quit}
  → ApplicationQuit signal (to be defined)
```

**Note**: Hit testing for mouse events will be implemented in Phase 2 (Graphics Bridge). For now, the bridge accepts optional target_id.

### Minimal State

Runtime stores minimal state:
```elixir
%{
  bus: atom(),
  root_component_pid: pid() | nil,
  root_component_id: String.t()
}
```

### Shutdown Strategy

- DynamicSupervisor terminates children in reverse start order
- Each child gets `shutdown` timeout (default 5000ms)
- Signal bus terminates last (after all agents)
- All agents can clean up via `terminate/2` callback

## Status

**Current State:** Complete

## Progress

### 2025-01-24
- [x] Created feature branch `feature/section-1.7-runtime`
- [x] Created feature tracking document
- [x] Read existing code (Signals, RenderingCoordinator, Elm)
- [x] Implemented DesktopUI.Runtime module (295 lines)
- [x] Created comprehensive test suite (19 tests, all passing)
- [x] Added KeyReleased and MousePressed signal types
- [x] Created summary document
- [x] Updated planning document with completed tasks

## Notes

### Future Event Bridge Work

The event bridge in this section is a placeholder for full SDL integration. Phase 2 will:
- Connect actual SDL events via NIFs
- Implement hit testing for mouse events
- Add focus management
- Handle window events (resize, move, etc.)

For now, the bridge provides a clean API for converting event tuples to signals, which will be called from future SDL integration.

### Root Component Registration

The root component must implement `DesktopUI.Elm` and be a valid Jido.Agent. The Runtime:
1. Starts the component via `Jido.Agent.Server.start_link/2`
2. Waits for component to be ready
3. Publishes `ComponentRegister` signal via the signal bus
4. RenderingCoordinator receives the signal and tracks the component

### Error Handling

- If signal bus fails to start: Runtime startup fails
- If RenderingCoordinator fails: Restarted (one_for_one)
- If root component crashes: Restarted (one_for_one)
- If registration fails: Logged but doesn't crash runtime

### Integration Tests

Section 1.9 will add integration tests for the full runtime lifecycle. Section 1.7 tests focus on:
- Successful startup
- Child process management
- Event bridge function
- Clean shutdown
