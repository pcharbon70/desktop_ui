# Section 3.5: Renderer with Layout

**Feature Branch:** `feature/section-3.5-renderer-with-layout`
**Status:** Complete
**Created:** 2025-01-26
**Last Updated:** 2025-01-26

## Overview

Update the SDL2 renderer to use the calculated layout positions from the Layout engine, removing the hardcoded positioning logic that currently exists in the renderer. This separates concerns: layout calculation happens in one pass, then rendering simply uses the calculated bounds.

## Problem Statement

Currently, the SDL2 renderer has its own `calculate_layout/8` function that handles positioning logic. This is problematic because:

1. **Duplication**: Layout logic exists in both `DesktopUI.Layout.Calculate` and the renderer
2. **Inconsistency**: Different layout algorithms could produce different results
3. **Maintainability**: Changes to layout behavior require updates in multiple places
4. **Hit Testing**: The renderer's layout isn't stored for use by the hit testing system
5. **Coupling**: Renderer is tightly coupled to specific layout behavior

We need the renderer to accept a pre-calculated layout tree and simply render widgets at their specified positions.

## Solution Overview

Refactor the SDL2 renderer to:

1. **Accept Layout Trees**: The `render/2` function should accept a `DesktopUI.Layout` struct instead of raw `Widget` trees
2. **Remove Hardcoded Layout**: Delete the `calculate_layout/8` function from the renderer
3. **Simplify Rendering**: Render each widget using the bounds from the layout tree
4. **Preserve Widget Reference**: Keep the widget reference in layout for accessing widget properties during rendering
5. **Handle Errors**: Gracefully handle layout errors and invalid input

### Key Design Decisions

- **Two-Phase Rendering**: Layout calculation is separate from rendering
- **Layout Tree Structure**: Layout structs contain nested child layouts, mirroring the widget tree structure
- **Renderer Simplicity**: Renderer only draws, doesn't calculate positions
- **Error Handling**: Layout errors propagate to the caller; renderer handles gracefully
- **Backward Compatibility**: Keep the old `render/2` API as a convenience wrapper that calculates layout first

## Technical Details

### File Locations

**Modified Files:**
- `lib/desktop_ui/renderer/sdl2.ex` - Update to use layout trees

**New Files:**
- `test/desktop_ui/renderer/layout_render_test.exs` - Tests for layout-based rendering

### Current Renderer Structure

```elixir
# Current API - Widget tree
def render(%__MODULE__{} = renderer, %Widget{} = widget) do
  # 1. Clear window
  # 2. render_widget with hardcoded layout calculation
  # 3. Present window
end

# Problem: render_widget has embedded layout logic
defp render_container(renderer, widget, x, y, w, h) do
  child_layouts = calculate_layout(...)  # <-- TO BE REMOVED
  Enum.reduce_while(child_layouts, :ok, fn child, acc -> ... end)
end
```

### Target Renderer Structure

```elixir
# New API - Layout tree
def render(%__MODULE__{} = renderer, %Layout{} = layout) do
  # 1. Clear window
  # 2. render_layout (no calculation, just drawing)
  # 3. Present window
end

# Convenience wrapper for backward compatibility
def render(%__MODULE__{} = renderer, %Widget{} = widget) do
  available_bounds = %{width: renderer.window_width, height: renderer.window_height}
  case Layout.calculate(widget, available_bounds) do
    {:ok, layout} -> render(renderer, layout)
    {:error, _reason} = error -> error
  end
end

# Simple layout-based rendering
defp render_layout(renderer, %Layout{widget: widget, x: x, y: y, width: w, height: h}) do
  case widget.type do
    :label -> render_label_at(renderer, widget, x, y, w, h)
    :button -> render_button_at(renderer, widget, x, y, w, h)
    :container -> render_container_layout(renderer, layout)
  end
end
```

### Layout Tree Structure

The Layout struct contains nested child layouts for containers:

```elixir
%Layout{
  x: 0,
  y: 0,
  width: 800,
  height: 600,
  widget: %Widget{type: :container, ...},
  # For containers, widget.children is the list of child Layout structs
  children: [
    %Layout{x: 10, y: 10, width: 100, height: 30, widget: %Widget{type: :label}},
    %Layout{x: 10, y: 50, width: 80, height: 40, widget: %Widget{type: :button}}
  ]
}
```

## Success Criteria

1. **Renderer Accepts Layout**: The `render/2` function accepts `DesktopUI.Layout` structs
2. **No Hardcoded Layout**: The `calculate_layout/8` function is removed from renderer
3. **Backward Compatible**: Existing `render(renderer, widget)` calls still work via wrapper
4. **Nested Layouts Work**: Containers render their children at calculated positions
5. **Spacing Visible**: spacing prop creates visible gaps between widgets
6. **Padding Visible**: padding prop creates visible margins
7. **Alignment Visible**: align prop positions children correctly
8. **Tests Pass**: All new and existing tests pass

## Implementation Plan

### Task 3.5.1: Update `render/2` to accept layout tree

**File:** `lib/desktop_ui/renderer/sdl2.ex`

Create a new `render/2` clause that accepts a `DesktopUI.Layout` struct:

```elixir
@spec render(t(), DesktopUI.Layout.t()) :: :ok | {:error, String.t()}
def render(%__MODULE__{} = renderer, %DesktopUI.Layout{} = layout) do
  with :ok <- Graphics.clear_window(renderer.window_id, @background_color),
       :ok <- render_layout(renderer, layout),
       :ok <- Graphics.present_window(renderer.window_id) do
    :ok
  end
end
```

Keep the existing `render/2` for widgets as a convenience wrapper.

### Task 3.5.2: Use calculated bounds from layout for each widget

**File:** `lib/desktop_ui/renderer/sdl2.ex`

Create `render_layout/2` that renders widgets using layout bounds:

```elixir
defp render_layout(renderer, %DesktopUI.Layout{widget: widget} = layout) do
  case widget.type do
    :label -> render_label_at(renderer, widget, layout.x, layout.y, layout.width, layout.height)
    :button -> render_button_at(renderer, widget, layout.x, layout.y, layout.width, layout.height)
    :container -> render_container_layout(renderer, layout)
  end
end
```

Create simplified rendering functions that use explicit bounds:

```elixir
defp render_label_at(renderer, widget, x, y, width, height) do
  {draw_x, draw_y, draw_w, draw_h} = clip_to_bounds(x, y, width, height, renderer.window_width, renderer.window_height)
  Graphics.fill_rect_on_window(renderer.window_id, draw_x, draw_y, draw_w, draw_h, @label_color)
end
```

### Task 3.5.3: Remove hardcoded positioning from renderer

**File:** `lib/desktop_ui/renderer/sdl2.ex`

Delete the `calculate_layout/8` function (lines ~346-400).

Update `render_widget` to no longer calculate positions—positions come from the layout tree.

### Task 3.5.4: Pass layout results through render pipeline

**File:** `lib/desktop_ui/renderer/sdl2.ex`

Ensure nested layouts are rendered correctly:

```elixir
defp render_container_layout(renderer, %DesktopUI.Layout{widget: %Widget{children: children}}) do
  Enum.reduce_while(children, :ok, fn child_layout, _acc ->
    case render_layout(renderer, child_layout) do
      :ok -> {:cont, :ok}
      error -> {:halt, error}
    end
  end)
end
```

Note: The layout tree's `widget.children` field contains the nested child Layout structs.

### Task 3.5.5: Support nested layouts correctly

Verify that nested containers (vbox in hbox, etc.) render correctly with proper positioning.

The layout engine already creates nested layout structures—we just need to traverse them correctly.

### Task 3.5.6: Handle layout errors gracefully

**File:** `lib/desktop_ui/renderer/sdl2.ex`

The convenience wrapper should handle layout calculation errors:

```elixir
def render(%__MODULE__{} = renderer, %Widget{} = widget) do
  available_bounds = %{width: renderer.window_width, height: renderer.window_height}

  case Layout.calculate(widget, available_bounds) do
    {:ok, layout} -> render(renderer, layout)
    {:error, reason} -> {:error, "Layout calculation failed: #{reason}"}
  end
end
```

## Unit Tests Required

**File:** `test/desktop_ui/renderer/layout_render_test.exs`

### Test Structure

```elixir
defmodule DesktopUI.Renderer.LayoutRenderTest do
  use ExUnit.Case
  alias DesktopUI.{Layout, Renderer.SDL2, Widget}

  describe "render/2 with layout" do
    test "renders single label layout"
    test "renders single button layout"
    test "renders vbox container layout"
    test "renders hbox container layout"
  end

  describe "backward compatibility" do
    test "render/2 with widget still works"
    test "layout calculation errors are handled"
  end

  describe "positioning" do
    test "widgets render at calculated x positions"
    test "widgets render at calculated y positions"
    test "widgets render with calculated widths"
    test "widgets render with calculated heights"
  end

  describe "spacing" do
    test "spacing creates visible gaps between widgets"
    test "spacing works in vbox"
    test "spacing works in hbox"
  end

  describe "padding" do
    test "padding creates margins in container"
    test "padding insets all children"
  end

  describe "alignment" do
    test "left alignment positions at left"
    test "center alignment positions in center"
    test "right alignment positions at right"
    test "top alignment positions at top"
    test "bottom alignment positions at bottom"
  end

  describe "nested layouts" do
    test "vbox containing hbox renders correctly"
    test "hbox containing vbox renders correctly"
    test "deeply nested containers render correctly"
  end

  describe "error handling" do
    test "invalid widget returns error"
    test "layout calculation failure returns error"
  end
end
```

**Target:** ~20-25 tests covering layout-based rendering

## Progress Log

### 2025-01-26 - Implementation Complete

All tasks completed successfully:

**Task 3.5.1**: Updated `render/2` to accept layout tree
- Added new `render(renderer, %Layout{})` clause
- Updated moduledoc with layout-based usage examples
- Returns `:ok` or `{:error, reason}`

**Task 3.5.2**: Use calculated bounds from layout
- Created `render_layout/2` to dispatch based on widget type
- Created `render_label_at/2`, `render_button_at/2` for leaf widgets
- Created `render_container_layout/2` for containers
- All rendering uses x, y, width, height from layout struct

**Task 3.5.3**: Removed hardcoded positioning
- Deleted `calculate_layout/8` function (~55 lines)
- Deleted `get_widget_width/2`, `get_widget_height/2` helpers (~30 lines)
- Removed unused default dimension constants
- Removed unused Integer import

**Task 3.5.4**: Pass layout results through pipeline
- Layout tree structure: `widget.children` contains nested Layout structs
- Container rendering recursively calls `render_layout/2` for children
- No position calculation in renderer—all from layout

**Task 3.5.5**: Support nested layouts
- Nested containers (vbox in hbox, etc.) render correctly
- Layout tree already contains nested structures from layout calculation
- Recursive `render_layout/2` traverses correctly

**Task 3.5.6**: Handle layout errors gracefully
- Widget-based `render/2` wraps `Layout.calculate` with error handling
- Returns `{:error, "Layout calculation failed: #{reason}"}` on failure
- Direct layout-based render assumes layout is valid

**Unit Tests**: Added 10 new layout-based tests to `sdl2_test.exs`
- All 25 renderer tests passing
- Tests cover: layout rendering, backward compatibility, positioning, hbox/vbox, error handling

## Notes and Considerations

### Design Questions

1. **Backward Compatibility**: Should we keep the widget-based `render/2` API?
   - Yes, as a convenience wrapper. It calls `Layout.calculate` then `render(renderer, layout)`.

2. **Layout Tree Structure**: How are child layouts stored?
   - In the `widget.children` field of the Layout struct's widget reference.
   - The layout engine populates this with nested Layout structs.

3. **Error Handling**: What if layout calculation fails?
   - Return `{:error, reason}` from the convenience wrapper.
   - Direct layout-based rendering assumes layout is already valid.

4. **Performance**: Is there a performance cost to the wrapper?
   - Minimal: just one function call to `Layout.calculate`.
   - Layout calculation is O(n) where n is widget count.

### Current Renderer Issues

The SDL2 renderer has these problems to address:

1. **`calculate_layout/8` Function**: Duplicate layout logic (~50 lines)
2. **`render_widget` with Position Args**: Passes x, y, width, height explicitly
3. **Hardcoded Defaults**: `@default_label_width`, etc., no longer needed
4. **Widget Props in Renderer**: Reads `:width` and `:height` props—layout already calculated these

### Integration with RenderingCoordinator

The RenderingCoordinator currently calls:
```elixir
DesktopUI.Renderer.SDL2.render(component_id, widget, :coordinator_name)
```

This will continue to work via the convenience wrapper. In the future, the coordinator could:
1. Calculate layout once per state change
2. Store the layout tree
3. Pass layout to renderer directly (avoids recalculation)

### Future Work

- **Section 3.6**: Use stored layout tree for hit testing
- **Optimization**: Cache layout trees to avoid recalculation
- **Dirty Regions**: Only re-render changed widgets
- **Z-Order**: Support for z-index and overlapping widgets

## Dependencies

- Requires: Section 3.1 (Layout Engine Foundation) - for Layout.calculate
- Requires: Section 3.2 (VBox) - for container layout calculation
- Requires: Section 3.3 (HBox) - for container layout calculation
- Requires: Section 3.4 (Widget Size Hints) - for size constraints
- Enables: Section 3.6 (Hit Testing with Layout)

## Integration Considerations

### Render Pipeline Flow

```
Widget Tree
    ↓
Layout.calculate(widget, available_bounds)
    ↓
Layout Tree (with x, y, width, height for each widget)
    ↓
SDL2.render(renderer, layout)
    ↓
Graphics operations (draw rectangles at calculated positions)
    ↓
Present window
```

### Stored Layout for Hit Testing

After rendering, the layout tree should be stored for hit testing:

```elixir
# In RenderingCoordinator or Runtime
defp render_and_store_layout(widget, window_id) do
  available_bounds = get_window_bounds(window_id)

  case Layout.calculate(widget, available_bounds) do
    {:ok, layout} ->
      :ok = SDL2.Renderer.render(@renderer_name, layout)
      :ets.insert(:layout_cache, {current_layout, layout})
      :ok

    {:error, _reason} = error ->
      error
  end
end
```

This will be implemented in Section 3.6.

## Files Created (When Complete)

- `lib/desktop_ui/renderer/sdl2.ex` - Modified (~85 lines removed, ~75 lines added, net ~10 lines)
- `test/desktop_ui/renderer/sdl2_test.exs` - Extended with 10 new layout-based tests (added ~400 lines)
