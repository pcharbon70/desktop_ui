# Section 1.8: Example Counter Component (Jido Agent) - Feature Document

**Feature Branch:** `feature/section-1.8-counter-component`
**Status:** Complete
**Created:** 2025-01-24
**Completed:** 2025-01-24
**Planning Document:** `notes/planning/poc/phase-1-architecture-validation.md`

## Overview

Create a complete working example component (`DesktopUI.Examples.Counter`) demonstrating the agent-based architecture. This component serves as both a demonstration and a reference implementation for building UI components using the Elm Architecture pattern with Jido agents.

## Tasks

### 1.8.1 Define component with `use DesktopUI.Elm`
- [x] Create `lib/desktop_ui/examples/counter.ex`
- [x] Use `DesktopUI.Elm` with component name and description
- [x] Define component state schema with count field

### 1.8.2 Implement `init/1` returning initial count of 0
- [x] Return initial state with count: 0
- [x] Return empty commands list
- [x] Handle optional init opts

### 1.8.3 Implement `update/2` handling messages
- [x] Handle `:increment` - increase count by 1
- [x] Handle `:decrement` - decrease count by 1
- [x] Handle `:reset` - set count to 0
- [x] Return {new_state, []} for all messages

### 1.8.4 Implement `view/1` returning UI tree
- [x] Display current count in a label
- [x] Create increment button with on_click: :increment
- [x] Create decrement button with on_click: :decrement
- [x] Create reset button with on_click: :reset
- [x] Use nested containers (vbox with hbox for buttons)
- [x] Add spacing and padding props

### 1.8.5 Implement `on_signal/2` for Clicked signal handling
- [x] Match on `Clicked` signals
- [x] Extract target_id from signal data
- [x] Map button IDs to messages (:increment, :decrement, :reset)
- [x] Call update/2 with the mapped message

### 1.8.6 Demonstrate proper widget structure
- [x] Use container(:vbox) as root
- [x] Use container(:hbox) for button row
- [x] Add spacing: 8, padding: 16 to vbox
- [x] Add spacing: 4 to hbox
- [x] Set descriptive IDs on buttons

## Files to Create

| File | Purpose | Status |
|------|---------|--------|
| `lib/desktop_ui/examples/counter.ex` | Counter component module | Complete |
| `test/desktop_ui/examples/counter_test.exs` | Counter component tests | Complete |

## Files to Modify

| File | Changes | Status |
|------|---------|--------|
| None anticipated | N/A | N/A |

## Design Decisions

### Component Structure

The Counter component will be a simple but complete example:

```
Counter UI Layout:
┌─────────────────────────┐
│                         │
│  Counter Demo           │  <- Label (title)
│                         │
│  Current: 0             │  <- Label (count display)
│                         │
│  [+]  [-]  [Reset]      │  <- HBox with buttons
│                         │
└─────────────────────────┘
```

### State Schema

```elixir
%{
  count: integer()  # Current counter value
}
```

### Message Handling

```elixir
# Direct messages (for testing or external control)
:increment  # Increase count by 1
:decrement  # Decrease count by 1
:reset      # Set count to 0

# Signal-based messages (from on_signal/2)
{:clicked, :btn_increment}  # From increment button
{:clicked, :btn_decrement}  # From decrement button
{:clicked, :btn_reset}      # From reset button
```

### Button IDs

```elixir
:btn_increment  # Increment button
:btn_decrement  # Decrement button
:btn_reset      # Reset button
```

## Widget Tree Structure

```elixir
Widget.container(:vbox, [
  Widget.label("Counter Demo", id: :title),
  Widget.label("Current: #{count}", id: :count_label),
  Widget.container(:hbox, [
    Widget.button("+", :increment, id: :btn_increment),
    Widget.button("-", :decrement, id: :btn_decrement),
    Widget.button("Reset", :reset, id: :btn_reset)
  ], spacing: 4)
], spacing: 8, padding: 16)
```

## on_signal/2 Implementation

The component will handle Clicked signals by extracting the target_id and mapping to the appropriate message:

```elixir
@impl true
def on_signal(%Jido.Signal{type: "desktop_ui.ui.clicked", data: data}, state) do
  target_id = Map.get(data, :target_id)

  message = case target_id do
    :btn_increment -> :increment
    :btn_decrement -> :decrement
    :btn_reset -> :reset
    _ -> nil
  end

  if message do
    {new_state, []} = update(message, state)
    {:noreply, new_state}
  else
    {:noreply, state}
  end
end

def on_signal(_signal, state), do: {:noreply, state}
```

Note: StateChanged signals are automatically published by the DesktopUI.Elm behavior
after update/2 returns, so we don't need to publish them manually.

## Module Location

The component will be placed in `lib/desktop_ui/examples/` to indicate it's an example/reference implementation:

```
lib/desktop_ui/
└── examples/
    └── counter.ex
```

## Usage Example

```elixir
# Start via Runtime
{:ok, _runtime} = DesktopUI.Runtime.start_link(
  root_component: DesktopUI.Examples.Counter,
  renderer: DesktopUI.Renderer.Mock,
  bus: :desktop_ui
)

# Or start directly as an agent
{:ok, pid} = Jido.Agent.Server.start_link(
  agent: DesktopUI.Examples.Counter,
  name: :counter
)

# Send messages directly
Jido.Agent.Server.send_signal(pid, :increment)

# Or bridge click events
DesktopUI.Runtime.bridge_event(
  {:sdl_mouseup, x: 100, y: 50, button: :left, target_id: :btn_increment}
)
```

## Status

**Current State:** Complete

## Progress

### 2025-01-24
- [x] Created feature branch `feature/section-1.8-counter-component`
- [x] Created feature tracking document
- [x] Read existing code (Elm, Widget, Signals) for reference
- [x] Implemented DesktopUI.Examples.Counter module (125 lines)
- [x] Created comprehensive test suite (23 tests, all passing)
- [x] Created summary document
- [x] Updated planning document with completed tasks
