# Section 3.6: Hit Testing with Layout - Implementation Summary

**Feature Branch:** `feature/section-3.6-hit-testing-with-layout`
**Status:** Complete
**Date:** 2025-01-26

## Overview

Successfully implemented Section 3.6 of Phase 3: First Real Widget. The hit testing system now allows the framework to determine which widget was clicked at a given screen coordinate using the calculated layout tree from Section 3.5. This enables interactive UI components like buttons.

## Completed Tasks

### Task 3.6.1: Create `hit_test/3` function in Layout module

Added `hit_test/3` to `lib/desktop_ui/layout.ex`:

```elixir
@spec hit_test(t(), non_neg_integer(), non_neg_integer()) ::
  {:ok, %{widget_id: atom(), on_click: term()}} | nil
def hit_test(%__MODULE__{} = layout, x, y) do
  hit_test_recursive(layout, x, y)
end
```

The function traverses the layout tree recursively to find which widget contains the given point.

### Task 3.6.2: Return widget ID and on_click message

Created `button_widget_info/1` helper to extract widget metadata:

```elixir
defp button_widget_info(%Widget{id: id, props: props}) do
  on_click = Keyword.get(props, :on_click)

  if on_click != nil and id != nil do
    {:ok, %{widget_id: id, on_click: on_click}}
  else
    nil
  end
end
```

Returns `{:ok, %{widget_id: id, on_click: message}}` for buttons with both id and on_click, or nil otherwise.

### Task 3.6.3: Handle nested containers correctly

Created recursive search functions:
- `search_children_for_hit/2` - Searches children of containers with type: :container
- `search_synthetic_children/2` - Handles nested container layouts (type: nil from layout calculation)

Handles:
- VBox containing HBox
- HBox containing VBox
- Deeply nested containers

### Task 3.6.4: Return nil for clicks outside any widget

Uses existing `contains?/3` function for point-in-rect testing:

```elixir
defp hit_test_recursive(%__MODULE__{} = layout, x, y) do
  if contains?(layout, x, y) do
    # Search this layout
  else
    nil
  end
end
```

### Task 3.6.5: Handle overlapping widgets (topmost wins)

Children are searched in reverse order:

```elixir
children
|> Enum.reverse()
|> Enum.reduce_while(nil, fn child_layout, _acc ->
  case hit_test_recursive(child_layout, x, y) do
    nil -> {:cont, nil}
    result -> {:halt, result}
  end
end)
```

Topmost widget (last in children list) is checked first and wins for overlaps.

### Task 3.6.6: Store current layout in RenderingCoordinator

**File:** `lib/desktop_ui/rendering_coordinator.ex`

Changes:
- Added `@layouts_table :desktop_ui_rendering_coordinator_layouts`
- Updated `ensure_ets_tables/0` to create layouts table
- Modified `render_component/4` to calculate and store layout before rendering
- Added `get_available_bounds/0` helper (uses 1920x1080 default, to be improved)

Layout is stored with key `{component_id, "current"}` in ETS.

### Task 3.6.7: Add hit_test API to RenderingCoordinator

Added public API:

```elixir
@spec hit_test(String.t(), non_neg_integer(), non_neg_integer()) ::
  {:ok, %{widget_id: atom(), on_click: term()}} | nil
def hit_test(component_id, x, y) do
  ensure_ets_tables()

  case :ets.lookup(@layouts_table, {component_id, "current"}) do
    [{{_key, "current"}, layout}] ->
      Layout.hit_test(layout, x, y)

    [] ->
      nil
  end
end
```

## Files Modified

### `lib/desktop_ui/layout.ex`

**Changes:**
- Added `hit_test/3` public function
- Added `hit_test_recursive/3` private function
- Added `search_children_for_hit/2` private function
- Added `search_synthetic_children/2` private function
- Added `button_widget_info/1` private function
- Added `container_widget_info/1` private function
- Added `Widget` alias for hit testing code

**Net change:** ~95 lines added

### `lib/desktop_ui/rendering_coordinator.ex`

**Changes:**
- Added `@layouts_table` module attribute
- Added `Layout` to aliases
- Updated `ensure_ets_tables/0` to create layouts table
- Modified `render_component/4` to calculate and store layout
- Added `get_available_bounds/0` private helper
- Added public `hit_test/3` API function

**Net change:** ~55 lines added

### `test/desktop_ui/layout/hit_test_test.exs`

**New file:** ~240 lines

**Tests created (15 total):**
1. Returns nil when point is outside all widgets
2. Returns widget info when point is inside a button
3. Returns on_click message for interactive buttons
4. Returns nil for label without on_click
5. Finds widget in nested container (vbox)
6. Finds widget in nested container (hbox)
7. Finds widget in deeply nested containers
8. Returns nil for container with no on_click
9. Topmost widget wins for overlapping widgets
10. Handles empty container layout
11. Handles button without id
12. Handles button with id but no on_click
13. Clicking on padding area returns nil
14. Nested hbox in vbox
15. Nested vbox in hbox

**All 15 tests passing:** ✓

### `notes/features/section-3.6-hit-testing-with-layout.md`

**New file:** Planning document with implementation details

### `notes/summaries/section-3.6-hit-testing-with-layout.md`

**New file:** This summary document

## Key Design Decisions

1. **Layout-First Approach**: Hit testing uses calculated layout bounds, not widget trees
2. **Z-Order**: Last widget in tree (topmost) wins for overlaps via reverse search
3. **Container Handling**: Containers don't receive clicks (unless explicitly enabled later)
4. **ETS Storage**: Layouts stored in ETS table for easy Runtime access without GenServer call
5. **Synthetic Widget Handling**: Nested container layouts have `type: nil`, handled specially
6. **Simplified Result**: Only return interactive widgets (buttons with on_click), nil for everything else

## Before and After Comparison

### Before (No Hit Testing)

```elixir
# No way to determine which widget was clicked
# Runtime receives SDL click events but doesn't know target
```

### After (Hit Testing with Layout)

```elixir
# Layout is stored after rendering
:ets.insert(:desktop_ui_rendering_coordinator_layouts,
  {{"counter_123", "current"}, layout})

# Runtime can hit test
case DesktopUI.RenderingCoordinator.hit_test("counter_123", 100, 50) do
  {:ok, %{widget_id: :btn_inc, on_click: :increment}} ->
    # Enrich click signal with target information
    publish_click_signal(target_id: :btn_inc, on_click: :increment)

  nil ->
    # Click outside any widget
    :ok
end
```

## Test Results

**Hit Testing Tests:** 15 tests, 0 failures

**Overall Test Suite:** 544 tests, 120 failures (pre-existing: 135 failures on poc branch)
- Note: Our changes actually fixed 15 tests compared to poc branch

## Signal Flow

```
SDL Mouse Click → Runtime bridge_event/1
                                ↓
                    Calls RenderingCoordinator.hit_test/3
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

## Benefits

1. **Interactive UI**: Buttons can now respond to clicks
2. **Accurate Targeting**: Hit testing uses precise layout bounds
3. **Nested Support**: Works correctly with nested containers
4. **Performance**: Layout stored once, reused for hit testing
5. **Z-Order**: Correct handling of overlapping widgets
6. **Clean API**: Simple hit_test/3 function for Runtime to use

## Integration Notes

### Runtime Integration (Future)

The Runtime will use hit testing to enrich click events:

```elixir
def handle_sdl_mouse_up(x, y, button, component_id) do
  case DesktopUI.RenderingCoordinator.hit_test(component_id, x, y) do
    {:ok, %{widget_id: target_id, on_click: message}} ->
      # Publish enriched click signal
      Signals.MouseClicked.new(%{
        component_id: component_id,
        target_id: target_id,
        message: message,
        x: x,
        y: y,
        button: button
      })

    nil ->
      # Click outside any widget - publish without target
      Signals.MouseClicked.new(%{
        component_id: component_id,
        x: x,
        y: y,
        button: button
      })
  end
end
```

### Section 3.7 Integration

Section 3.7 (RenderingCoordinator Layout Integration) will improve the layout storage:
- Calculate layout in coordinator after view/1 (not in renderer)
- Store layout in coordinator state
- Use cached layout when widget tree unchanged
- Pass layout to renderer directly

## Dependencies

- Requires: Section 3.1 (Layout Engine Foundation)
- Requires: Section 3.2 (VBox Container Layout)
- Requires: Section 3.3 (HBox Container Layout)
- Requires: Section 3.4 (Widget Size Hints)
- Requires: Section 3.5 (Renderer with Layout)
- Enables: Section 3.7 (RenderingCoordinator Layout Integration)
- Enables: Section 3.8 (Enhanced Counter Demo)

## Next Steps

Section 3.7 will:
1. Improve layout calculation in RenderingCoordinator
2. Store layout more efficiently
3. Cache layout when widget tree unchanged
4. Pass layout directly to renderer
