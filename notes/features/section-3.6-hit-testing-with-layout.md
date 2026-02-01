# Section 3.6: Hit Testing with Layout

**Feature Branch:** `feature/section-3.6-hit-testing-with-layout`
**Status:** Complete
**Created:** 2025-01-26
**Last Updated:** 2025-01-26

## Overview

Implement hit testing using the calculated layout tree from Section 3.5. Hit testing determines which widget was clicked at a given screen coordinate, enabling interactive UI components.

## Problem Statement

Currently, the DesktopUI framework can render widget trees using calculated layouts, but cannot determine which widget was clicked. To support interactive components (like buttons), we need:

1. **Hit Testing**: Traverse the layout tree to find which widget contains a given point (x, y)
2. **Widget ID Return**: Return the widget's ID and on_click message for clicked widgets
3. **Nested Container Support**: Correctly handle clicks on widgets within nested containers
4. **Nil for Outside Clicks**: Return nil when clicking outside any widget
5. **Topmost Widget**: Handle overlapping widgets (topmost/last in tree wins)
6. **Coordinator Integration**: Store current layout in RenderingCoordinator for hit testing

### Current Architecture Gaps

- No hit_test function exists
- RenderingCoordinator doesn't store layout after rendering
- Runtime cannot enrich Clicked signals with target widget information
- No way to determine which button was clicked

## Solution Overview

Create a hit testing system that:

1. **Adds `hit_test/3` to Layout module**: Traverse layout tree to find widget at position
2. **Returns widget metadata**: `{widget_id, on_click_message}` tuple for interactive widgets
3. **Handles nested layouts**: Recursively search children in containers
4. **Integrates with RenderingCoordinator**: Store and retrieve layout for hit testing
5. **Provides Runtime API**: Runtime can call coordinator to get target widget

### Key Design Decisions

- **Layout-First**: Hit testing uses calculated layout bounds, not widget trees
- **Z-Order**: Last widget in tree (topmost) wins for overlaps
- **Container Handling**: Containers don't receive clicks (unless explicitly enabled later)
- **Stored Layout**: Coordinator stores latest layout tree in ETS table
- **Separation of Concerns**: Layout module owns hit_test logic, Coordinator manages storage

## Technical Details

### File Locations

**New Files:**
- `lib/desktop_ui/layout/hit_test.ex` - Hit testing module (or add to layout.ex)

**Modified Files:**
- `lib/desktop_ui/layout.ex` - Add hit_test/3 function
- `lib/desktop_ui/rendering_coordinator.ex` - Store layout, add hit_test API
- `test/desktop_ui/layout/hit_test_test.exs` - Hit testing tests
- `test/desktop_ui/rendering_coordinator_test.exs` - Coordinator hit test integration tests

### Data Structures

#### Hit Test Result

```elixir
# Successful hit on interactive widget
{:ok, %{widget_id: atom(), on_click: term()}}

# Hit on non-interactive widget (label, container without on_click)
{:hit, widget_id: atom()}

# No widget at position
nil
```

#### Layout Storage in Coordinator

```elixir
# ETS table: :desktop_ui_rendering_coordinator_layouts
# Key: {component_id, "current"}
# Value: layout_tree

:ets.insert(:desktop_ui_rendering_coordinator_layouts,
  {{"counter_123", "current"}, layout_tree})
```

### Current Layout Structure (from Section 3.5)

```elixir
%Layout{
  x: 0, y: 0, width: 800, height: 600,
  widget: %Widget{type: :container, children: child_layouts},
  # For containers, widget.children contains nested Layout structs
  children: [
    %Layout{x: 10, y: 10, width: 100, height: 30,
      widget: %Widget{type: :label, ...}},
    %Layout{x: 10, y: 50, width: 80, height: 40,
      widget: %Widget{type: :button, props: [on_click: :clicked], ...}}
  ]
}
```

**Note**: The layout calculation stores child layouts in `widget.children` (not directly on Layout struct).

## Success Criteria

1. **Hit Test Function**: `Layout.hit_test/3` finds widget at (x, y) in layout tree
2. **Nested Containers**: Correctly finds widgets in deeply nested containers
3. **Widget ID Return**: Returns widget_id and on_click for interactive widgets
4. **Outside Clicks**: Returns nil for clicks outside any widget
5. **Overlapping Widgets**: Topmost widget (last in children list) wins
6. **Coordinator Storage**: RenderingCoordinator stores layout after rendering
7. **Coordinator API**: Coordinator.hit_test/2 retrieves widget by position
8. **All Tests Pass**: Unit and integration tests pass

## Implementation Plan

### Task 3.6.1: Create `hit_test/3` function in Layout module

**File:** `lib/desktop_ui/layout.ex` or `lib/desktop_ui/layout/hit_test.ex`

Create hit testing function:

```elixir
@doc """
Hit test the layout tree to find the widget at the given position.

Returns {:ok, %{widget_id: id, on_click: message}} for interactive widgets,
{:hit, widget_id: id} for non-interactive widgets, or nil if no widget found.

## Parameters

- `layout` - The layout tree to search
- `x` - X coordinate to test
- `y` - Y coordinate to test

## Examples

    layout = Layout.calculate(widget, bounds)
    Layout.hit_test(layout, 100, 50)
    #=> {:ok, %{widget_id: :btn_click, on_click: :clicked}}

"""
@spec hit_test(t(), non_neg_integer(), non_neg_integer()) ::
  {:ok, %{widget_id: atom(), on_click: term()}} |
  {:hit, widget_id: atom()} |
  nil
def hit_test(%__MODULE__{} = layout, x, y) do
  # Implementation
end
```

**Implementation Notes:**
- Use existing `contains?/3` function for point-in-rect test
- Search children first (reverse order for z-order: topmost first)
- For containers, recursively search children in `widget.children`
- Return widget metadata if found, nil otherwise

### Task 3.6.2: Return widget ID and on_click message

Extract widget metadata from the hit widget:

```elixir
defp hit_widget_info(%Widget{id: id, props: props, type: type}) do
  on_click = Keyword.get(props, :on_click)

  cond do
    on_click != nil and id != nil ->
      {:ok, %{widget_id: id, on_click: on_click}}

    id != nil ->
      {:hit, widget_id: id}

    true ->
      nil
  end
end
```

**Considerations:**
- Buttons with on_click return {:ok, %{widget_id:, on_click:}}
- Labels without on_click return {:hit, widget_id:} or nil
- Containers typically return nil (no interaction)
- Widgets without id return nil

### Task 3.6.3: Handle nested containers correctly

Recursively search nested container layouts:

```elixir
defp hit_test_layout_recursive(%__MODULE__{widget: %Widget{type: :container}} = layout, x, y) do
  # Search children first (reverse for z-order)
  children = get_layout_children(layout)

  Enum.reduce_while(Enum.reverse(children), nil, fn child_layout, _acc ->
    case hit_test_layout_recursive(child_layout, x, y) do
      nil -> {:cont, nil}
      result -> {:halt, result}
    end
  end)
end
```

**Helper function to get children from container layout:**

```elixir
defp get_layout_children(%__MODULE__{widget: %Widget{children: children}}) when is_list(children) do
  children
end
defp get_layout_children(_), do: []
```

### Task 3.6.4: Return nil for clicks outside any widget

The base case - point not in this layout's bounds:

```elixir
defp hit_test_layout_recursive(%__MODULE__{} = layout, x, y) do
  if contains?(layout, x, y) do
    # Point is in this layout, check if it's a leaf or search children
    hit_widget_or_children(layout, x, y)
  else
    # Point is outside this layout
    nil
  end
end
```

### Task 3.6.5: Handle overlapping widgets (topmost wins)

Search children in reverse order:

```elixir
# Reverse children list so last (topmost) is checked first
Enum.reduce_while(Enum.reverse(children), nil, fn child_layout, _acc ->
  case hit_test_layout_recursive(child_layout, x, y) do
    nil -> {:cont, nil}  # Continue searching
    result -> {:halt, result}  # Found! Stop searching
  end
end)
```

**Note:** In the layout tree, later children in the list are rendered "on top" of earlier children.

### Task 3.6.6: Store current layout in RenderingCoordinator

**File:** `lib/desktop_ui/rendering_coordinator.ex`

Add ETS table for layout storage:

```elixir
@layouts_table :desktop_ui_rendering_coordinator_layouts

# In init/1
defp ensure_ets_tables(opts \\ []) do
  # ... existing tables ...

  # Create layouts table
  case :ets.whereis(@layouts_table) do
    :undefined -> :ets.new(@layouts_table, [:named_table, :public, :set])
    _ -> :already_exists
  end
end
```

Store layout after rendering:

```elix
defp handle_state_change(state, component_id, new_elm_state) do
  # ... existing code to get widget tree ...

  # Store layout for hit testing
  case Layout.calculate(widget, available_bounds) do
    {:ok, layout} ->
      # Store layout
      :ets.insert(@layouts_table, {{component_id, "current"}, layout})

      # Render using layout
      renderer.render(component_id, layout, coordinator_name)

    {:error, _reason} ->
      # Handle error
  end
end
```

**Note:** This refactoring should integrate with Section 3.7 (RenderingCoordinator Layout Integration). For Section 3.6, we may add a simpler version that stores layout after the existing render call.

### Task 3.6.7: Add hit_test API to RenderingCoordinator

Add public API for Runtime to call:

```elixir
@doc """
Hit test for a component's current layout.

Returns {:ok, %{widget_id: id, on_click: message}} for interactive widgets,
or nil if no widget was clicked.

## Parameters

- `component_id` - The component to test
- `x` - X coordinate
- `y` - Y coordinate

## Examples

    DesktopUI.RenderingCoordinator.hit_test("counter_123", 100, 50)
    #=> {:ok, %{widget_id: :btn_inc, on_click: :increment}}

"""
@spec hit_test(String.t(), non_neg_integer(), non_neg_integer()) ::
  {:ok, %{widget_id: atom(), on_click: term()}} | nil
def hit_test(component_id, x, y) do
  case :ets.lookup(@layouts_table, {component_id, "current"}) do
    [{{_key, "current"}, layout}] ->
      Layout.hit_test(layout, x, y)

    [] ->
      nil
  end
end
```

## Unit Tests Required

**File:** `test/desktop_ui/layout/hit_test_test.exs`

### Test Structure

```elixir
defmodule DesktopUI.Layout.HitTestTest do
  use ExUnit.Case
  alias DesktopUI.{Layout, Widget}

  describe "hit_test/3" do
    test "returns nil when point is outside all widgets"
    test "returns widget info when point is inside a button"
    test "returns on_click message for interactive buttons"
    test "returns nil for label without on_click"
    test "finds widget in nested container (vbox in hbox)"
    test "finds widget in deeply nested containers"
    test "returns nil for container with no on_click"
    test "topmost widget wins for overlapping widgets"
    test "handles empty container layout"
    test "handles widget without id"
  end
end
```

**Target:** ~10-12 tests

### Coordinator Integration Tests

**File:** `test/desktop_ui/rendering_coordinator_test.exs` (extend existing)

```elixir
describe "hit testing" do
  test "stores layout after rendering"
  test "hit_test/3 returns widget for valid click"
  test "hit_test/3 returns nil for invalid click"
  test "hit_test/3 returns nil for unknown component"
  test "layout updates when component state changes"
end
```

## Progress Log

### 2025-01-26 - Implementation Complete

All tasks completed successfully:

**Task 3.6.1**: Created `Layout.hit_test/3` function
- Added hit_test/3 to lib/desktop_ui/layout.ex
- Recursive traversal of layout tree
- Returns {:ok, %{widget_id:, on_click:}} for interactive widgets

**Task 3.6.2**: Return widget ID and on_click message
- button_widget_info/1 extracts widget metadata
- Returns {:ok, %{widget_id: id, on_click: message}} for buttons with both id and on_click
- Returns nil for widgets without id or on_click

**Task 3.6.3**: Handle nested containers correctly
- search_children_for_hit/2 recursively searches children
- search_synthetic_children/2 handles nested container layouts (type: nil)
- Handles vbox in hbox, hbox in vbox, and deep nesting

**Task 3.6.4**: Return nil for clicks outside any widget
- contains?/2 used for point-in-rect testing
- Returns nil when point is outside layout bounds

**Task 3.6.5**: Handle overlapping widgets (topmost wins)
- Children searched in reverse order (Enum.reverse)
- Topmost widget (last in children list) is checked first

**Task 3.6.6**: Store current layout in RenderingCoordinator
- Added @layouts_table :desktop_ui_rendering_coordinator_layouts
- Updated ensure_ets_tables/0 to create layouts table
- Modified render_component/4 to calculate and store layout
- Added get_available_bounds/0 helper (uses 1920x1080 default)

**Task 3.6.7**: Add hit_test API to RenderingCoordinator
- Added public hit_test/3 function to RenderingCoordinator
- Retrieves layout from ETS and calls Layout.hit_test/3

**Unit Tests**: Created test/desktop_ui/layout/hit_test_test.exs
- 15 tests covering all hit test scenarios
- All tests passing

## Notes and Considerations

### Design Questions

1. **Hit Test Result Format**: Should we return different results for interactive vs non-interactive widgets?
   - **Decision**: Return {:ok, metadata} for interactive, {:hit, id} for non-interactive with id, nil for nothing

2. **Container Clicks**: Should containers ever receive clicks?
   - **Decision**: For now, containers don't receive clicks. Can add event bubbling later.

3. **Layout Storage**: Where to store layouts - in process state or ETS?
   - **Decision**: ETS table for easy access from Runtime without GenServer call overhead

4. **Layout Versioning**: How to handle stale layouts when component updates?
   - **Decision**: Use "current" key, replaced on each state change. Add version tracking later if needed.

### Signal Flow (Updated)

```
SDL Mouse Click → Runtime bridge_event/1
                                ↓
                    Calls RenderingCoordinator.hit_test/2
                                ↓
                    Layout.hit_test/3 traverses layout tree
                                ↓
                    Returns {:ok, %{widget_id:, on_click:}} or nil
                                ↓
                    Runtime enriches Clicked signal with target_id
                                ↓
                    Component receives signal and updates state
                                ↓
                    StateChanged signal triggers re-render
```

### Integration with Section 3.7

Section 3.7 (RenderingCoordinator Layout Integration) will:
1. Calculate layout in coordinator after view/1 (not in renderer)
2. Store layout in coordinator state
3. Use cached layout when widget tree unchanged
4. Pass layout to renderer directly

For Section 3.6, we add layout storage and hit_test API to enable the Runtime
to enrich click events with target widget information.

### Future Work

- **Event Bubbling**: Propagate clicks to parent containers
- **Multiple Widgets**: Return all widgets under point (for overlays)
- **Scroll Offsets**: Account for scroll position in hit testing
- **Transform Bounds**: Handle rotation/scale transforms
- **Hit Test Caching**: Cache frequent hit test results

## Dependencies

- Requires: Section 3.1 (Layout Engine Foundation)
- Requires: Section 3.2 (VBox Container Layout)
- Requires: Section 3.3 (HBox Container Layout)
- Requires: Section 3.4 (Widget Size Hints)
- Requires: Section 3.5 (Renderer with Layout)
- Enables: Section 3.7 (RenderingCoordinator Layout Integration)
- Enables: Section 3.8 (Enhanced Counter Demo)

## Files Created (When Complete)

- `lib/desktop_ui/layout.ex` - Modified (add hit_test/3)
- `lib/desktop_ui/rendering_coordinator.ex` - Modified (add layout storage, hit_test/3 API)
- `test/desktop_ui/layout/hit_test_test.exs` - New (~300 lines)
- `test/desktop_ui/rendering_coordinator_test.exs` - Extended (~100 lines)
