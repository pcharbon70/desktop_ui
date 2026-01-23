# Phase 1: Architecture Validation (Jido-First)

This phase establishes the core architectural foundations of DesktopUI using **Jido agents** for component lifecycle and **Jido signals** for event communication. We build a distributed agent-based system with a mock renderer to validate the Elm Architecture pattern works effectively with autonomous UI components before introducing C/NIF complexity.

---

## 1.1 Elm Behaviour Definition

Define the contract that all UI components must implement, following the Elm Architecture pattern (TEA) integrated with Jido.Agent for agent capabilities.

- [x] **Task 1.1** Create `DesktopUI.Elm` behaviour module

Define the three core callbacks that components must implement:

- [x] 1.1.1 Define `init/1` callback specification - receives options, returns `{initial_state, initial_commands}`
- [x] 1.1.2 Define `update/2` callback specification - receives message and state, returns `{new_state, commands}`
- [x] 1.1.3 Define `view/1` callback specification - receives state, returns `ui_element()` structure
- [x] 1.1.4 Define `ui_element()` type specification - recursive structure for UI trees
- [x] 1.1.5 Define `command()` type specification - structured side effect representation

**Implementation Notes:**
- Use `@callback` directive for each function specification
- Include `@type` definitions for `ui_element()` and `command()`
- Provide `__using__/1` macro to scaffold boilerplate for component modules
- Include optional `@impl true` annotations for better Dialyzer support
- Document each callback with clear examples in module documentation

**Unit Tests for Section 1.1:**
- [x] 1.1.1 Verify behaviour is defined with correct callback specifications
- [x] 1.1.2 Verify `use DesktopUI.Elm` generates required function stubs
- [x] 1.1.3 Verify `ui_element()` type compiles correctly
- [x] 1.1.4 Verify `command()` type compiles correctly
- [x] 1.1.5 Verify Dialyzer type checking passes for behaviour module

**Status:** Completed 2025-01-22 - See `notes/summaries/section-1.1-elm-behaviour-definition.md` for details.

**NOTE:** Task 1.3-J will revise this module to integrate with `Jido.Agent`.

---

## 1.2 Widget Construction DSL

Create the declarative widget system that components use to build their UI trees. These are pure data structures, not renderers— they describe what to render, not how.

- [x] **Task 1.2** Create `DesktopUI.Widget` module and widget constructors

Define the core widget data structure and helper functions:

- [x] 1.2.1 Define `DesktopUI.Widget` struct with `:type`, `:id`, `:props`, `:children` fields
- [x] 1.2.2 Create `label/2` helper function - text string and optional props
- [x] 1.2.3 Create `button/3` helper function - text, on_click message, and optional props
- [x] 1.2.4 Create `container/3` helper function - type (`:vbox`, `:hbox`), children list, and props
- [x] 1.2.5 Define `@type` specifications for all widget constructors
- [x] 1.2.6 Add validation functions for widget structure integrity

**Implementation Notes:**
- Widget structs should be serializable and comparable
- Use keyword lists or maps for props to allow flexible properties
- Support nested widgets through the `:children` field
- Include optional `:id` field for event targeting and debugging
- Consider using `@enforce_keys` for required fields
- Props should support common attributes like `:width`, `:height`, `:spacing`, `:padding`

**Unit Tests for Section 1.2:**
- [x] 1.2.1 Verify widget struct creation with all fields
- [x] 1.2.2 Verify `label/2` creates correct widget structure
- [x] 1.2.3 Verify `button/3` creates correct widget with on_click property
- [x] 1.2.4 Verify `container/3` supports both :vbox and :hbox types
- [x] 1.2.5 Verify nested widgets through children field
- [x] 1.2.6 Verify widget validation catches invalid structures
- [x] 1.2.7 Verify widget equality comparison works correctly

**Status:** Completed 2025-01-22 - See `notes/summaries/section-1.2-widget-construction-dsl.md` for details.

---

## 1.3 Jido Integration Foundation

Add Jido dependencies and create the signal-based infrastructure for agent communication.

- [x] **Task 1.3** Add Jido dependencies and create signal infrastructure

Implement the foundation for Jido-based architecture:

- [x] 1.3.1 Add `{:jido, "~> 1.2"}` to mix.exs dependencies
- [x] 1.3.2 Add `{:jido_signal, "~> 1.2"}` to mix.exs dependencies
- [x] 1.3.3 Add `{:jido_action, "~> 1.0"}` to mix.exs dependencies
- [x] 1.3.4 Run `mix deps.get` and verify compilation
- [x] 1.3.5 Create `DesktopUI.Signals` module with UI signal types
- [x] 1.3.6 Define `StateChanged` signal for component state changes
- [x] 1.3.7 Define `Clicked` signal for mouse click events
- [x] 1.3.8 Define `KeyPressed` signal for keyboard events
- [x] 1.3.9 Define `RenderRequest` signal for rendering coordination

**Implementation Notes:**
- Use `use Jido.Signal` macro for signal type definitions
- Follow CloudEvents v1.0.2 specification for signal structure
- Include schema validation for all signal types
- Signals should have descriptive types like `"desktop_ui.state.changed"`
- Include source tracking for debugging and causality

**Unit Tests for Section 1.3:**
- [x] 1.3.1 Verify Jido dependencies compile without errors
- [x] 1.3.2 Verify StateChanged signal validates component_id and states
- [x] 1.3.3 Verify Clicked signal validates target_id and button
- [x] 1.3.4 Verify KeyPressed signal validates key and modifiers
- [x] 1.3.5 Verify RenderRequest signal validates component_id
- [x] 1.3.6 Verify signals serialize to JSON correctly

**Status:** Completed 2025-01-23 - See `notes/summaries/section-1.3-jido-integration.md` for details.

---

## 1.4 DesktopUI.Elm with Jido.Agent Integration

Revise the Elm behaviour to integrate with Jido.Agent, making components autonomous agents.

- [x] **Task 1.4** Revise `DesktopUI.Elm` to use Jido.Agent

Update Elm behaviour for agent-based components:

- [x] 1.4.1 Integrate `use Jido.Agent` into `DesktopUI.Elm.__using__/1` macro
- [x] 1.4.2 Add `on_signal/2` callback for signal-based event handling
- [x] 1.4.3 Create `handle_ui_signal/2` helper for processing UI messages
- [x] 1.4.4 Auto-publish state_change signals after state updates
- [x] 1.4.5 Maintain backward compatibility with existing init/update/view callbacks
- [x] 1.4.6 Add agent registration helpers for component discovery

**Implementation Notes:**
- Components using `use DesktopUI.Elm` automatically get Jido.Agent capabilities
- State changes automatically publish `desktop_ui.state.changed` signals
- `on_signal/2` allows components to handle custom signal types
- Keep the Elm callbacks (init, update, view) pure and simple
- Agent state schema includes the component's Elm state
- Support both sync and async signal handling
- Elm state is lazily initialized on first handle_ui_signal/2 call

**Unit Tests for Section 1.4:**
- [x] 1.4.1 Verify component with `use DesktopUI.Elm` is a valid Jido.Agent
- [x] 1.4.2 Verify component's init/1 is called on agent startup
- [x] 1.4.3 Verify state changes publish StateChanged signals
- [x] 1.4.4 Verify on_signal/2 receives UI event signals
- [x] 1.4.5 Verify handle_ui_signal/2 calls update/2 with message
- [x] 1.4.6 Verify view/1 returns valid widget tree

**Status:** Completed 2025-01-23 - See `notes/summaries/section-1.4-elm-jido-integration.md` for details.

---

## 1.5 RenderingCoordinator Agent

Create the agent that subscribes to state changes and orchestrates rendering.

- [ ] **Task 1.5** Create `DesktopUI.RenderingCoordinator` agent

Implement the rendering coordination agent:

- [ ] 1.5.1 Define agent with `use Jido.Agent` for agent capabilities
- [ ] 1.5.2 Implement `init/1` to subscribe to state_change signals
- [ ] 1.5.3 Create component registry for tracking active components
- [ ] 1.5.4 Implement signal handler for StateChanged signals
- [ ] 1.5.5 Call component's view/1 when state changes
- [ ] 1.5.6 Validate widget tree before rendering
- [ ] 1.5.7 Pass validated tree to renderer module
- [ ] 1.5.8 Add register_component/3 and unregister_component/2 functions

**Implementation Notes:**
- Subscribe to `"desktop_ui.state.**"` signal pattern
- Store component PIDs and modules for view/1 calls
- Use Jido.Signal.Bus.subscribe/3 for subscriptions
- Renderer module is dependency-injected for testing
- Handle rendering errors gracefully without crashing
- Support render request signals for forced redraws
- Track pending renders for metrics

**Unit Tests for Section 1.5:**
- [ ] 1.5.1 Verify coordinator subscribes to state_change signals
- [ ] 1.5.2 Verify component registration works
- [ ] 1.5.3 Verify coordinator calls view/1 on state change
- [ ] 1.5.4 Verify coordinator validates widget trees
- [ ] 1.5.5 Verify coordinator passes tree to renderer
- [ ] 1.5.6 Verify coordinator handles render errors
- [ ] 1.5.7 Verify component unregistration works

---

## 1.6 Mock Renderer

Create a test double renderer that validates UI trees without actually drawing anything. This proves the rendering pipeline works before we have real graphics.

- [ ] **Task 1.6** Create `DesktopUI.Renderer.Mock` module

Implement a validating renderer:

- [ ] 1.6.1 Define `render/2` function that accepts UI tree and state
- [ ] 1.6.2 Validate UI tree structure (well-formedness check)
- [ ] 1.6.3 Record render calls for test assertions
- [ ] 1.6.4 Support widget introspection for debugging
- [ ] 1.6.5 Return success/failure status
- [ ] 1.6.6 Provide a "screenshot" function returning tree as readable text

**Implementation Notes:**
- Store render history in agent or ETS for test verification
- Return `:ok` or `{:error, reason}` tuple
- Text representation should be indented hierarchy
- Include widget type and key props in text output
- Support render count tracking for optimization testing
- Should be thread-safe for concurrent test access

**Unit Tests for Section 1.6:**
- [ ] 1.6.1 Verify mock render accepts valid UI tree
- [ ] 1.6.2 Verify mock render rejects invalid UI tree
- [ ] 1.6.3 Verify render history is recorded correctly
- [ ] 1.6.4 Verify text representation shows widget hierarchy
- [ ] 1.6.5 Verify render count tracking works
- [ ] 1.6.6 Verify multiple renders are recorded sequentially

---

## 1.7 DesktopUI.Runtime (Bootstrap & Event Bridge)

Create the runtime that starts agents and bridges external events to signals.

- [ ] **Task 1.7** Create `DesktopUI.Runtime` bootstrap supervisor

Implement the runtime as a bootstrap and event bridge:

- [ ] 1.7.1 Define `child_spec/1` for OTP supervision integration
- [ ] 1.7.2 Implement `start_link/2` with root component and renderer options
- [ ] 1.7.3 Start Jido.Signal.Bus with name `:desktop_ui`
- [ ] 1.7.4 Start RenderingCoordinator agent
- [ ] 1.7.5 Start root component as Jido agent
- [ ] 1.7.6 Register root component with RenderingCoordinator
- [ ] 1.7.7 Implement event bridge for converting external events to signals
- [ ] 1.7.8 Handle shutdown and cleanup of all agents

**Implementation Notes:**
- Runtime is NOT a central orchestrator—agents are autonomous
- Runtime's job is to bootstrap the supervision tree
- Bridge external events (SDL, keyboard, etc.) to Jido signals
- Use a supervisor to manage agent lifecycles
- Store minimal state (root component, coordinator ref, signal bus name)
- Support graceful shutdown of all agents

**Unit Tests for Section 1.7:**
- [ ] 1.7.1 Verify runtime starts signal bus
- [ ] 1.7.2 Verify runtime starts RenderingCoordinator
- [ ] 1.7.3 Verify runtime starts root component agent
- [ ] 1.7.4 Verify runtime bridges events to signals
- [ ] 1.7.5 Verify runtime shuts down cleanly
- [ ] 1.7.6 Verify agent crashes are isolated

---

## 1.8 Example Counter Component (Jido Agent)

Build a complete working example component demonstrating the agent-based architecture.

- [ ] **Task 1.8** Create `DesktopUI.Examples.Counter` component

Implement a classic counter as a Jido agent:

- [ ] 1.8.1 Define component with `use DesktopUI.Elm`
- [ ] 1.8.2 Implement `init/1` returning initial count of 0
- [ ] 1.8.3 Implement `update/2` handling `:increment`, `:decrement`, `:reset` messages
- [ ] 1.8.4 Implement `view/1` returning label and button widgets
- [ ] 1.8.5 Implement `on_signal/2` for Clicked signal handling
- [ ] 1.8.6 Demonstrate nested container (vbox with hbox for buttons)

**Implementation Notes:**
- Component is a full Jido agent with all capabilities
- State changes automatically publish StateChanged signals
- Clicked signals trigger update/2 with appropriate message
- Keep it simple but representative of real components
- Use integer state for count
- Show spacing and padding props in action

**Unit Tests for Section 1.8:**
- [ ] 1.8.1 Verify counter initializes with count of 0
- [ ] 1.8.2 Verify `:increment` message increases count by 1
- [ ] 1.8.3 Verify `:decrement` message decreases count by 1
- [ ] 1.8.4 Verify state changes publish StateChanged signals
- [ ] 1.8.5 Verify Clicked signals trigger state updates
- [ ] 1.8.6 Verify `view/1` returns valid UI tree

---

## 1.9 Phase 1 Integration Tests

Comprehensive integration tests verifying all Phase 1 components work together correctly.

- [ ] **Task 1.9** Create end-to-end integration test suite

Verify the complete Jido-first architecture:

- [ ] 1.9.1 Test full lifecycle: init → signal → update → state_change → render
- [ ] 1.9.2 Test Counter component through Runtime with Mock Renderer
- [ ] 1.9.3 Test signal flow from component to RenderingCoordinator
- [ ] 1.9.4 Test multiple state changes in sequence
- [ ] 1.9.5 Test state unchanged skips render (no signal published)
- [ ] 1.9.6 Test error handling in component callbacks
- [ ] 1.9.7 Test concurrent event dispatch via signals
- [ ] 1.9.8 Test runtime shutdown and cleanup
- [ ] 1.9.9 Test signal causality tracking
- [ ] 1.9.10 Test agent isolation (component crash doesn't crash coordinator)

**Implementation Notes:**
- Use ExUnit's `async: false` for tests involving named processes
- Clean up any registered processes between tests
- Use timeout to catch hangs in signal processing
- Include performance benchmarks (signal publish time, render time)
- Verify RenderingCoordinator receives expected signals
- Use setup/callbacks for consistent test environment

**Actual Test Coverage:**
- Signal infrastructure: 6 tests
- Elm behaviour with Jido: 6 tests
- RenderingCoordinator: 7 tests
- Agent lifecycle: 4 tests
- Component behavior: 6 tests
- End-to-end flow: 10 tests

**Total: 39 integration tests**

---

## Success Criteria

1. **Jido Integration**: All components work as Jido agents with signal communication
2. **Signal Flow**: State changes propagate via signals to RenderingCoordinator
3. **Rendering Works**: Counter component runs through full lifecycle with mock renderer
4. **Agent Isolation**: Component failures don't crash other agents
5. **Test Coverage**: Unit test coverage >80% for all new modules
6. **Observable**: All state changes are published as signals

---

## Critical Files

**New Files:**
- `lib/desktop_ui/signals.ex` - UI signal type definitions
- `lib/desktop_ui/rendering_coordinator.ex` - Rendering coordination agent
- `lib/desktop_ui/runtime.ex` - Bootstrap and event bridge
- `lib/desktop_ui/renderer/mock.ex` - Mock renderer for testing
- `lib/desktop_ui/examples/counter.ex` - Counter component as Jido agent
- `test/desktop_ui/signals_test.exs` - Signal tests
- `test/desktop_ui/rendering_coordinator_test.exs` - Coordinator tests
- `test/desktop_ui/runtime_test.exs` - Runtime tests
- `test/desktop_ui/renderer/mock_test.exs` - Mock renderer tests
- `test/desktop_ui/examples/counter_test.exs` - Counter component tests
- `test/integration/phase_1_integration_test.exs` - Integration tests

**Modified Files:**
- `lib/desktop_ui/elm.ex` - Integrate with Jido.Agent
- `mix.exs` - Add Jido dependencies

**Dependencies:**
- `{:jido, "~> 1.2"}` - Core agent system
- `{:jido_signal, "~> 1.2"}` - Signal pub/sub system
- `{:jido_action, "~> 1.0"}` - Composable actions

---

## Dependencies

**This phase has no dependencies** - it establishes the foundational architecture with Jido.

**Phases that depend on this phase:**
- Phase 2: The Graphics Bridge (depends on Signal infrastructure, Runtime event bridge)
- Phase 3: First Real Widget (depends on RenderingCoordinator, Elm behaviour, Widget DSL)
