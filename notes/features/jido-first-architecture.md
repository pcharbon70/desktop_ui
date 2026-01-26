# Jido-First Architecture - Feature Document

**Feature Branch:** `feature/jido-first-architecture`
**Status:** Planning Phase
**Created:** 2025-01-23
**Planning Document:** `notes/planning/poc/jido-first-architecture.md`

## Overview

This feature represents a major architectural pivot for DesktopUI from a GenServer-based runtime to a **Jido-agent-first architecture**. This aligns with the research vision and leverages the Jido ecosystem for agent-based UI components.

## Tasks

### Phase 1: Foundation

- [ ] 1.1-J Add Jido dependencies to mix.exs
  - Add `{:jido, "~> 1.2"}`
  - Add `{:jido_signal, "~> 1.2"}`
  - Add `{:jido_action, "~> 1.0"}`
  - Run `mix deps.get`

- [ ] 1.2-J Revise DesktopUI.Elm behaviour
  - Integrate `use Jido.Agent` into `__using__/1` macro
  - Add signal handling helpers (handle_ui_signal)
  - Keep init/1, update/2, view/1 callbacks
  - Add automatic state_change signal publishing

- [ ] 1.3-J Create DesktopUI.Signals module
  - StateChanged signal type
  - Clicked UI event signal
  - KeyPressed UI event signal
  - RenderRequest signal type

- [ ] 1.4-J Create RenderingCoordinator agent
  - Subscribe to state_change signals
  - Maintain component registry
  - Call view/1 on state changes
  - Validate and render widget trees
  - Handle render requests

- [ ] 1.5-J Revise DesktopUI.Runtime
  - Convert from orchestrator to bootstrap/event bridge
  - Start and supervise agents
  - Start signal bus
  - Bridge SDL events to Jido signals

### Phase 2: Component Examples

- [ ] 2.1-J Revise Counter component
  - Use `use DesktopUI.Elm` with Jido integration
  - Implement init/1, update/2, view/1 callbacks
  - Add signal routing for UI events
  - Test full event flow

### Phase 3: Testing

- [ ] 3.1-J Create integration tests
  - Test state_change signal publishing
  - Test RenderingCoordinator subscription
  - Test Runtime event bridging
  - Test full click → update → render flow

- [ ] 3.2-J Update existing tests
  - Adapt Elm behaviour tests for Jido integration
  - Update Widget tests (should work unchanged)

## Files to Modify

| File | Action | Status |
|------|--------|--------|
| `mix.exs` | Add Jido dependencies | Pending |
| `lib/desktop_ui/elm.ex` | Add Jido.Agent integration | Pending |
| `lib/desktop_ui/runtime.ex` | Rewrite as bootstrap/event bridge | Pending |

## Files to Create

| File | Purpose | Status |
|------|---------|--------|
| `lib/desktop_ui/signals.ex` | UI signal definitions | Pending |
| `lib/desktop_ui/rendering_coordinator.ex` | Rendering coordination agent | Pending |
| `lib/desktop_ui/examples/counter_agent.ex` | Revised counter example | Pending |
| `test/desktop_ui/signals_test.exs` | Signal tests | Pending |
| `test/desktop_ui/rendering_coordinator_test.exs` | Coordinator tests | Pending |
| `test/integration/jido_first_test.exs` | Integration tests | Pending |

## Status

**Current State:** Planning complete, awaiting implementation

## Progress

### 2025-01-23
- Created planning document
- Researched Jido libraries (Agent, Agent.Server, Signal, Action)
- Created feature tracking document
- Ready to begin implementation

## Success Criteria

- [ ] All Jido dependencies added and compiling
- [ ] DesktopUI.Elm integrates with Jido.Agent
- [ ] RenderingCoordinator successfully subscribes and renders
- [ ] Counter component works with new architecture
- [ ] Integration tests pass
- [ ] Signal flow is observable and traceable

## Notes

The Jido-first architecture provides:
- **Fault Isolation** - Each component is a supervised agent
- **Distributed State** - No single point of failure
- **Decoupled Communication** - Signals enable flexible routing
- **Observable** - All state changes published as signals
- **Testable** - Components testable in isolation

## References

- Planning: `notes/planning/poc/jido-first-architecture.md`
- Research: `notes/research/1.01-foundation/1.01.4-component-architecture.md`
- Jido Docs: https://hexdocs.pm/jido/
