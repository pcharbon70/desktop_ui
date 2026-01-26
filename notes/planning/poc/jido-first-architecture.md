# Jido-First Architecture for DesktopUI

**Status:** Planning Phase
**Created:** 2025-01-23
**Feature Branch:** `feature/jido-first-architecture`

## Overview

This document outlines a major architectural pivot for DesktopUI from a GenServer-based runtime to a **Jido-agent-first architecture**. This aligns with the research vision documented in `notes/research/1.01-foundation/1.01.4-component-architecture.md` and leverages the Jido ecosystem for agent-based UI components.

## Motivation

### Why Jido-First?

The original POC plan used a centralized `DesktopUI.Runtime` GenServer to manage component lifecycle. While functional, this approach has limitations:

1. **Centralized Bottleneck** - Single runtime process manages all UI state
2. **Tight Coupling** - Components depend on runtime for event handling
3. **Limited Scalability** - Difficult to add inter-component communication
4. **Manual Orchestration** - Runtime must explicitly trigger renders

The Jido-first approach addresses these limitations:

1. **Distributed Agents** - Each component is an autonomous agent
2. **Signal-Based Communication** - Decoupled pub/sub via `Jido.Signal`
3. **Automatic Rendering** - RenderingCoordinator subscribes to state changes
4. **Fault Isolation** - Component failures don't crash the entire UI

## Jido Ecosystem Overview

### Libraries Used

| Package | Version | Purpose |
|---------|---------|---------|
| `jido` | ~1.2.0 | Core agent system with `Jido.Agent.Server` |
| `jido_signal` | ~1.2.0 | CloudEvents-compliant signal system for pub/sub |
| `jido_action` | ~1.0.0 | Composable validated actions for side effects |

### Key Concepts

#### Jido.Agent
- Behaviour defining stateful agents with schemas and lifecycle hooks
- Compile-time configuration with validation
- State management with dirty tracking

#### Jido.Agent.Server
- GenServer that manages agent processes
- Handles signal processing and routing
- Supports both sync (call) and async (cast) signal handling

#### Jido.Signal
- CloudEvents v1.0.2 compliant message format
- Signal Bus for pub/sub with pattern matching
- Persistent subscriptions with acknowledgment
- Causality tracking for debugging

#### Jido.Action
- Composable, validated operations
- Async execution via `Jido.Exec`
- Lifecycle hooks for customization

## Revised Architecture

### Component Model

```
┌─────────────────────────────────────────────────────────────┐
│                     DesktopUI.Application                    │
│  (Bootstrap & Supervision - NOT a central orchestrator)     │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  CounterAgent    │ │  FormAgent       │ │  ToolbarAgent    │
│  (Jido.Agent)    │ │  (Jido.Agent)    │ │  (Jido.Agent)    │
│                  │ │                  │ │                  │
│  - count: 0      │ │  - fields: [...]  │ │  - tools: [...]  │
│  - view/1        │ │  - view/1         │ │  - view/1        │
└────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘
         │                    │                    │
         │ state_changes      │ state_changes      │ state_changes
         │ (signals)          │ (signals)          │ (signals)
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                              ▼
                    ┌──────────────────────┐
                    │ RenderingCoordinator │
                    │   (Jido.Agent)       │
                    │                      │
                    │ - Subscribes to      │
                    │   state_change sigs  │
                    │ - Calls view/1       │
                    │ - Layout engine      │
                    │ - Render trigger     │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   GraphicsEngine     │
                    │   (Future - SDL2)    │
                    └──────────────────────┘
```

### Signal Flow

```
User Click (SDL2)
       │
       ▼
DesktopUI.Runtime (Event Bridge)
       │
       ▼
Publishes "ui.clicked" signal
       │
       ├──────────────────┐
       ▼                  ▼
CounterAgent       RenderingCoordinator
(Signal handler)   (Waiting for state_changes)
       │                  │
       ▼                  ▼
Processes message   Sees state_change
via update/2              │
       │                  ▼
       ▼            Calls view/1
Publishes "state.changed"
       │                  │
       │                  ▼
       │            Triggers render
       │                  │
       └──────────────────┘
```

## Implementation Plan

### Phase 1: Foundation (Revises Sections 1.1-1.2)

#### Task 1.1-J: Add Jido Dependencies

Update `mix.exs` to include Jido packages:

```elixir
defp deps do
  [
    {:jido, "~> 1.2"},
    {:jido_signal, "~> 1.2"},
    {:jido_action, "~> 1.0"}
  ]
end
```

#### Task 1.2-J: Revise DesktopUI.Elm Behaviour

**Current State:** `DesktopUI.Elm` defines init/1, update/2, view/1 callbacks

**New Approach:** Keep Elm callbacks but create adapter for Jido agents

```elixir
defmodule DesktopUI.Elm do
  @moduledoc """
  Elm Architecture behaviour for Jido-based UI components.

  Components use `use DesktopUI.Elm` which:
  1. Includes `use Jido.Agent` for agent capabilities
  2. Defines Elm callbacks (init, update, view)
  3. Provides signal handling for UI events
  4. Automatically publishes state_change signals
  """

  defmacro __using__(opts) do
    quote do
      use Jido.Agent, unquote(opts)

      @behaviour DesktopUI.Elm

      # Elm state type - must be defined in component
      @type state :: map()

      # Elm message type - must be defined in component
      @type message :: any()

      # ... callback definitions
    end
  end

  # Callbacks
  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, term()}
  @callback update(message(), state()) :: {:ok, state()} | {:error, term()}
  @callback view(state()) :: DesktopUI.Widget.t()

  # Signal handling helpers
  def handle_ui_signal(agent, message) do
    case apply(agent.__module__, :update, [message, agent.state]) do
      {:ok, new_state} ->
        # Publish state_change signal
        signal = DesktopUI.Signals.StateChanged.new(%{
          component_id: agent.id,
          old_state: agent.state,
          new_state: new_state
        })

        Jido.Signal.Bus.publish(:desktop_ui, [signal])

        {:ok, %{agent | state: new_state}}

      {:error, _} = error ->
        error
    end
  end
end
```

#### Task 1.3-J: Create DesktopUI.Signals Module

Define signal types for UI communication:

```elixir
defmodule DesktopUI.Signals do
  @moduledoc """
  Signal types for DesktopUI communication.

  All UI events and state changes are communicated via signals
  following the CloudEvents v1.0.2 specification.
  """

  # State change signal - published when component state updates
  defmodule StateChanged do
    use Jido.Signal,
      type: "desktop_ui.state.changed",
      default_source: "/desktop_ui/components",
      schema: [
        component_id: [type: :string, required: true],
        old_state: [type: :map, required: true],
        new_state: [type: :map, required: true]
      ]
  end

  # UI event signals
  defmodule Clicked do
    use Jido.Signal,
      type: "desktop_ui.ui.clicked",
      default_source: "/desktop_ui/input",
      schema: [
        target_id: [type: :atom, required: true],
        button: [type: :atom, default: :left]
      ]
  end

  defmodule KeyPressed do
    use Jido.Signal,
      type: "desktop_ui.ui.key_pressed",
      default_source: "/desktop_ui/input",
      schema: [
        key: [type: :string, required: true],
        modifiers: [type: {:list, :atom}, default: []]
      ]
  end

  # Render signals
  defmodule RenderRequest do
    use Jido.Signal,
      type: "desktop_ui.render.request",
      default_source: "/desktop_ui/coordinator",
      schema: [
        component_id: [type: :string, required: true],
        force: [type: :boolean, default: false]
      ]
  end
end
```

#### Task 1.4-J: Create RenderingCoordinator Agent

New agent that subscribes to state changes and orchestrates rendering:

```elixir
defmodule DesktopUI.RenderingCoordinator do
  @moduledoc """
  Agent responsible for coordinating UI rendering.

  This agent:
  1. Subscribes to state_change signals from all components
  2. Maintains a registry of active components
  3. Calls view/1 on components when state changes
  4. Passes widget trees to the layout engine
  5. Triggers actual rendering via graphics engine

  The coordinator acts as the "view" layer in the Elm Architecture,
  observing state changes and updating the UI accordingly.
  """

  use Jido.Agent,
    name: "rendering_coordinator",
    description: "Coordinates UI rendering based on component state changes",
    category: "ui",
    schema: [
      components: [type: :map, default: %{}],
      renderer: [type: :module, default: DesktopUI.Renderer.Mock],
      pending_renders: [type: :integer, default: 0]
    ]

  @impl true
  def init(opts) do
    # Subscribe to state change signals
    {:ok, _sub} = Jido.Signal.Bus.subscribe(
      :desktop_ui,
      "desktop_ui.state.**",
      dispatch: {:pid, target: self()}
    )

    {:ok, %{
      components: %{},
      renderer: Keyword.get(opts, :renderer, DesktopUI.Renderer.Mock),
      pending_renders: 0
    }}
  end

  # Jido lifecycle callback for signal handling
  def on_signal(agent, signal) do
    case signal.type do
      "desktop_ui.state.changed" -> handle_state_change(agent, signal)
      "desktop_ui.render.request" -> handle_render_request(agent, signal)
      _ -> {:ok, agent}
    end
  end

  defp handle_state_change(agent, signal) do
    component_id = signal.data.component_id

    # Get the component's PID and call view/1
    case Map.get(agent.state.components, component_id) do
      nil ->
        # Unknown component, ignore
        {:ok, agent}

      %{pid: pid, module: module} ->
        # Get current state from the agent
        case Jido.Agent.Server.get_state(pid) do
          {:ok, component_state} ->
            # Call view/1 to get widget tree
            widget_tree = apply(module, :view, [component_state])

            # Validate and render
            case DesktopUI.Widget.validate(widget_tree) do
              :ok ->
                # Call renderer
                agent.state.renderer.render(widget_tree, component_state)

                {:ok, %{agent | pending_renders: agent.state.pending_renders + 1}}

              {:error, reason} ->
                # Log validation error
                {:ok, agent}
            end

          {:error, _} ->
            {:ok, agent}
        end
    end
  end

  defp handle_render_request(agent, signal) do
    # Force render a specific component
    component_id = signal.data.component_id
    # ... implementation
    {:ok, agent}
  end

  # Public API

  def register_component(coordinator_pid, component_id, pid, module) do
    send(coordinator_pid, {:register_component, component_id, pid, module})
    :ok
  end

  def unregister_component(coordinator_pid, component_id) do
    send(coordinator_pid, {:unregister_component, component_id})
    :ok
  end
end
```

#### Task 1.5-J: Revise DesktopUI.Runtime

**Current Role:** Central orchestrator GenServer

**New Role:** Bootstrap and event bridge only

```elixir
defmodule DesktopUI.Runtime do
  @moduledoc """
  Bootstrap and event bridge for DesktopUI applications.

  In the Jido-first architecture, Runtime:
  1. Starts and supervises all agents (components + coordinator)
  2. Bridges SDL events to Jido signals
  3. Manages the signal bus
  4. Provides application lifecycle management

  The Runtime does NOT:
  - Manage component state (agents manage their own state)
  - Trigger renders (coordinator handles this)
  - Route messages (signal bus handles this)
  """

  use GenServer
  require Logger

  defstruct [:root_component, :coordinator, :signal_bus, :renderer]

  # Public API

  def start_link(opts) do
    {root_opts, gen_opts} = Keyword.split(opts, [:root_component, :renderer])
    GenServer.start_link(__MODULE__, root_opts, gen_opts)
  end

  # Callbacks

  @impl true
  def init(opts) do
    root_module = Keyword.fetch!(opts, :root_component)
    renderer = Keyword.get(opts, :renderer, DesktopUI.Renderer.Mock)

    # Start signal bus
    {:ok, _bus_pid} = Jido.Signal.Bus.start_link(name: :desktop_ui)

    # Start rendering coordinator
    {:ok, coordinator_pid} = Jido.Agent.Server.start_link(
      agent: DesktopUI.RenderingCoordinator,
      initial_state: %{renderer: renderer},
      id: "rendering_coordinator"
    )

    # Start root component
    {:ok, root_pid} = Jido.Agent.Server.start_link(
      agent: root_module,
      initial_state: %{},
      id: "root"
    )

    # Register with coordinator
    DesktopUI.RenderingCoordinator.register_component(
      coordinator_pid,
      "root",
      root_pid,
      root_module
    )

    state = %__MODULE__{
      root_component: root_module,
      coordinator: coordinator_pid,
      signal_bus: :desktop_ui,
      renderer: renderer
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:sdl_event, event}, state) do
    # Bridge SDL events to Jido signals
    signal = case event do
      %{type: :mouse_down, button: button, target: target} ->
        {:ok, sig} = DesktopUI.Signals.Clicked.new(%{
          target_id: target,
          button: button
        })
        sig

      %{type: :key_down, key: key} ->
        {:ok, sig} = DesktopUI.Signals.KeyPressed.new(%{key: key})
        sig

      _ ->
        nil
    end

    if signal do
      Jido.Signal.Bus.publish(:desktop_ui, [signal])
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
```

### Phase 2: Component Examples

#### Task 2.1-J: Revise Counter Component

```elixir
defmodule DesktopUI.Examples.Counter do
  @moduledoc """
  Example counter component using Jido-first architecture.

  This component demonstrates:
  1. Using `use DesktopUI.Elm` for agent setup
  2. Implementing Elm callbacks
  3. Automatic state change signaling
  """

  use DesktopUI.Elm,
    name: "counter",
    description: "A simple counter component",
    category: "examples",
    schema: [
      count: [type: :integer, default: 0],
      min: [type: :integer, default: 0],
      max: [type: :integer, default: 100]
    ]

  # Elm callbacks

  @impl true
  def init(_opts) do
    {:ok, %{count: 0, min: 0, max: 100}}
  end

  @impl true
  def update(:increment, state) do
    new_count = min(state.count + 1, state.max)
    {:ok, %{state | count: new_count}}
  end

  def update(:decrement, state) do
    new_count = max(state.count - 1, state.min)
    {:ok, %{state | count: new_count}}
  end

  def update(:reset, state) do
    {:ok, %{state | count: state.min}}
  end

  @impl true
  def view(state) do
    DesktopUI.Widget.container(
      :vbox,
      [
        DesktopUI.Widget.label("Counter Demo", id: :title),
        DesktopUI.Widget.container(
          :hbox,
          [
            DesktopUI.Widget.button("+", :increment),
            DesktopUI.Widget.button("-", :decrement),
            DesktopUI.Widget.button("Reset", :reset)
          ],
          spacing: 8
        ),
        DesktopUI.Widget.label("Count: #{state.count}", id: :count_label)
      ],
      spacing: 16,
      padding: 12
    )
  end

  # Signal routing - map UI signals to update messages
  def on_signal(agent, signal) do
    case signal.type do
      "desktop_ui.ui.clicked" ->
        target = signal.data.target_id
        message = case target do
          :btn_increment -> :increment
          :btn_decrement -> :decrement
          :btn_reset -> :reset
          _ -> nil
        end

        if message do
          DesktopUI.Elm.handle_ui_signal(agent, message)
        else
          {:ok, agent}
        end

      _ ->
        {:ok, agent}
    end
  end
end
```

### Phase 3: Testing

#### Task 3.1-J: Integration Tests

```elixir
defmodule DesktopUI.Integration.JidoFirstTest do
  use ExUnit.Case

  alias DesktopUI.Examples.Counter
  alias DesktopUI.Signals

  test "component publishes state_change on update" do
    # Start signal bus
    {:ok, _bus} = Jido.Signal.Bus.start_link(name: :test_bus)

    # Subscribe to state changes
    {:ok, _sub} = Jido.Signal.Bus.subscribe(
      :test_bus,
      "desktop_ui.state.**",
      dispatch: {:pid, target: self()}
    )

    # Start counter agent
    {:ok, pid} = Jido.Agent.Server.start_link(
      agent: Counter,
      initial_state: %{count: 0, min: 0, max: 100}
    )

    # Send increment signal
    {:ok, signal} = Signals.Clicked.new(%{
      target_id: :btn_increment,
      button: :left
    })

    Jido.Signal.Bus.publish(:test_bus, [signal])

    # Assert state change received
    assert_receive {:signal, state_change}, 1000
    assert state_change.type == "desktop_ui.state.changed"
    assert state_change.data.new_state.count == 1
  end

  test "rendering coordinator subscribes to state changes" do
    # Test coordinator triggers render on state change
  end

  test "runtime bridges SDL events to signals" do
    # Test event bridge functionality
  end
end
```

## Migration Path

### Files to Modify

| File | Action |
|------|--------|
| `mix.exs` | Add Jido dependencies |
| `lib/desktop_ui/elm.ex` | Add Jido.Agent integration, signal helpers |
| `lib/desktop_ui/widget.ex` | No changes needed (pure data) |
| `lib/desktop_ui/runtime.ex` | Rewrite as bootstrap/event bridge |
| `lib/desktop_ui/signals.ex` | **NEW** - Signal type definitions |
| `lib/desktop_ui/rendering_coordinator.ex` | **NEW** - Rendering agent |

### Files to Create

| File | Purpose |
|------|---------|
| `lib/desktop_ui/signals.ex` | UI signal definitions |
| `lib/desktop_ui/rendering_coordinator.ex` | Rendering coordination agent |
| `lib/desktop_ui/examples/counter_agent.ex` | Revised counter example |

## Benefits of Jido-First Architecture

1. **Fault Isolation** - Each component is a supervised agent
2. **Distributed State** - No single point of failure or bottleneck
3. **Decoupled Communication** - Signals enable flexible routing
4. **Observable** - All state changes are published as signals
5. **Testable** - Components can be tested in isolation with signal assertions
6. **Scalable** - Easy to add inter-component communication
7. **Hot Reloadable** - Jido agents support hot code reloading
8. **AI-Ready** - Natural integration with AI agents via Jido

## Success Criteria

1. All Jido dependencies added and compiling
2. DesktopUI.Elm integrates with Jido.Agent
3. RenderingCoordinator successfully subscribes and renders
4. Counter component works with new architecture
5. Integration tests pass
6. Signal flow is observable and traceable
7. Example demonstrates full event flow: click → signal → update → render

## Open Questions

1. **Performance** - Signal overhead for high-frequency UI events?
2. **Ordering** - Guaranteed delivery order for state changes?
3. **Backpressure** - Handling rapid state changes?
4. **SDL Integration** - How to poll SDL events in agent model?

## Timeline

- Phase 1: Foundation (2-3 tasks)
- Phase 2: Component Examples (1-2 tasks)
- Phase 3: Testing (2-3 tasks)
- Total: ~5-8 tasks

## References

- Jido Documentation: https://hexdocs.pm/jido/
- Jido.Signal Documentation: https://hexdocs.pm/jido_signal/
- Jido.Action Documentation: https://hexdocs.pm/jido_action/
- Component Architecture Research: `notes/research/1.01-foundation/1.01.4-component-architecture.md`
