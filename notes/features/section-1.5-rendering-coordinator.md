# Section 1.5: RenderingCoordinator Agent - Feature Document

**Feature Branch:** `feature/section-1.5-rendering-coordinator`
**Status:** Complete
**Created:** 2025-01-23
**Completed:** 2025-01-23
**Planning Document:** `notes/planning/poc/phase-1-architecture-validation.md`

## Overview

Create the RenderingCoordinator agent that subscribes to component state changes and orchestrates rendering. The coordinator acts as the bridge between component state changes and actual rendering, validating widget trees and passing them to a renderer module.

## Tasks

### 1.5.1 Define RenderingCoordinator agent structure
- [x] Create `lib/desktop_ui/rendering_coordinator.ex`
- [x] Add `use GenServer` (changed from Jido.Agent due to architectural needs)
- [x] Define ETS tables for component registry
- [x] Define ETS tables for metrics and configuration

### 1.5.2 Implement init/1 for signal subscription
- [x] Subscribe to `"desktop_ui.**"` signal pattern
- [x] Initialize ETS tables for component registry
- [x] Store renderer module reference
- [x] Set up render metrics tracking

### 1.5.3 Create component registry
- [x] Store component PIDs and modules in ETS
- [x] Support component ID tracking
- [x] Implement register_component/4 function (signal-based)
- [x] Implement unregister_component/3 function (signal-based)
- [x] Handle duplicate registrations (overwrites with new timestamp)

### 1.5.4 Implement StateChanged signal handler
- [x] Create handle_info/2 clause for StateChanged
- [x] Extract component_id from signal
- [x] Look up component in ETS registry
- [x] Call component's view/1 with new state

### 1.5.5 Implement widget tree validation
- [x] Call DesktopUI.Widget.validate/1 on widget tree
- [x] Handle validation errors gracefully (track in metrics)
- [x] Continue operation after validation failures

### 1.5.6 Implement renderer integration
- [x] Pass validated widget tree to renderer module
- [x] Handle renderer errors without crashing
- [x] Support dependency injection for testing (module or {module, name})

### 1.5.7 Add RenderRequest signal support
- [x] Handle RenderRequest signals for forced redraws
- [x] Support targeted renders by component_id
- [x] Query component state via Jido.Agent.Server.state/1

### 1.5.8 Add metrics tracking
- [x] Track renders_completed count
- [x] Track renders_failed count
- [x] Track renders_skipped count
- [x] Support getting metrics via get_metrics/1

## Files to Create

| File | Purpose | Status |
|------|---------|--------|
| `lib/desktop_ui/rendering_coordinator.ex` | RenderingCoordinator GenServer | Complete |
| `test/desktop_ui/rendering_coordinator_test.exs` | Coordinator tests | Complete |

## Files to Modify

| File | Changes | Status |
|------|---------|--------|
| `lib/desktop_ui/signals.ex` | Add ComponentRegister, ComponentUnregister signals | Complete |

## Design Decisions

### Component Registry Structure

The coordinator tracks registered components:
```elixir
%{
  component_id => %{
    pid: pid(),
    module: atom(),
    last_rendered: DateTime.t()
  }
}
```

### Signal Subscription Pattern

Subscribe to all state changes:
```elixir
Jido.Signal.Bus.subscribe(
  :desktop_ui,
  "desktop_ui.state.**",
  dispatch: {:pid, target: self()}
)
```

### Renderer Dependency Injection

Renderer module is configurable via agent options:
```elixir
{:ok, pid} = Jido.Agent.Server.start_link(
  agent: DesktopUI.RenderingCoordinator,
  renderer: DesktopUI.Renderer.Mock,
  name: :rendering_coordinator
)
```

### Error Handling Strategy

- Invalid widget trees log errors but don't crash
- Unknown components are ignored
- Renderer failures are caught and logged
- Render requests continue even after errors

### Validation Flow

```
StateChanged signal arrives
  ↓
Look up component in registry
  ↓
Call component.view/1(new_state)
  ↓
Validate widget tree with Widget.validate/1
  ↓
Pass to renderer module
  ↓
Track metrics
```

## Status

**Current State:** Complete

## Progress

### 2025-01-23
- [x] Created feature branch `feature/section-1.5-rendering-coordinator`
- [x] Created feature tracking document
- [x] Read existing code (Signals, Widget, Elm)
- [x] Implemented RenderingCoordinator as GenServer (not Jido.Agent)
- [x] Created ETS-backed component registry
- [x] Implemented signal-based component registration
- [x] Implemented StateChanged signal handling
- [x] Added widget tree validation
- [x] Implemented render metrics tracking
- [x] Created comprehensive test suite (14 tests, all passing)
- [x] Created summary document

### Architectural Decision: GenServer instead of Jido.Agent

After extensive investigation and prototyping, determined that Jido.Agent is not suitable for the RenderingCoordinator use case:

**Why Jido.Agent didn't work:**
- Jido.Agent requires signal routing configuration
- Signals must either contain Instructions or match configured routes
- `handle_signal/2` callback has signature `handle_signal(Signal.t(), t()) :: {:ok, Signal.t()}` - returns signal, not agent state
- `on_before_run/2` only called during signal processing, not at startup
- Agent state changes from callbacks are not persisted by Jido.Agent.Server

**Why GenServer works:**
- Direct `handle_info/2` access to signals from bus subscription
- Predictable initialization via `init/1`
- Full control over state management
- ETS tables for persistent storage accessible from public API
- No routing complexity

### Test Results

```
RenderingCoordinator Tests: 14/14 passing
- Server initialization tests: 3/3
- Component registration tests: 5/5
- Metrics tests: 1/1
- Rendering tests: 3/3
- Container widget tests: 1/1
- Error handling tests: 1/1
```
