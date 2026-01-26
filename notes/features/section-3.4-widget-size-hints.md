# Section 3.4: Widget Size Hints

**Feature Branch:** `feature/section-3.4-widget-size-hints`
**Status:** Complete
**Created:** 2025-01-26
**Last Updated:** 2025-01-26

## Overview

Add widget-level size hints that allow widgets to override or modify their intrinsic size calculation. This includes explicit width/height props, min/max constraints, and an expand property for flexible sizing.

## Problem Statement

Sections 3.1-3.3 implemented intrinsic size calculation for labels, buttons, and containers. However, widgets cannot currently override their intrinsic size with explicit dimensions or request flexible sizing.

This prevents:
1. **Fixed-size widgets**: Cannot set a widget to exact pixel dimensions
2. **Minimum sizes**: Cannot ensure widgets don't shrink below a certain size
3. **Maximum sizes**: Cannot prevent widgets from growing too large
4. **Flexible sizing**: Cannot make widgets expand to fill available space (e.g., for stretchy buttons in an HBox)

We need to add widget-level size props that integrate with the existing constraint system.

## Solution Overview

Extend the widget system with size-related properties that integrate with the existing layout constraint system:

1. **Width/Height Props**: Allow explicit sizing to override intrinsic size
2. **Min/Max Props**: Set bounds on widget size
3. **Expand Prop**: Request widget to fill available space (for stretchy children)
4. **Integration**: These props convert to layout constraints during layout calculation

### Key Design Decisions

- **Reuse Constraint System**: Widget props convert to Context constraints during layout
- **Precedence**: explicit size > min/max > intrinsic
- **Expand**: Sets fixed size to available space (e.g., for HBox stretchy children)
- **Backward Compatible**: All props are optional; existing code continues to work

## Technical Details

### File Locations

**Modified Files:**
- `lib/desktop_ui/widget.ex` - Add size-related props to widget constructors
- `lib/desktop_ui/layout/calculate.ex` - Extract widget size props and convert to constraints

### Widget Props to Add

#### All Widgets
```elixir
Widget.label("Text",
  width: 100,           # Explicit width
  height: 50,           # Explicit height
  min_width: 80,        # Minimum width
  min_height: 30,       # Minimum height
  max_width: 200,       # Maximum width
  max_height: 100,      # Maximum height
  expand: :width        # Expand to fill available width
)
```

#### Containers
```elixir
Widget.container(:vbox, children,
  spacing: 10,
  padding: 20,
  width: 400,
  height: 300,
  expand: true  # Fill all available space
)
```

### Prop to Constraint Mapping

Widget props are extracted during layout calculation and converted to Context constraints:

| Widget Prop | Context Constraint |
|------------|-------------------|
| `width` | `fixed_width` |
| `height` | `fixed_height` |
| `min_width` | `min_width` |
| `min_height` | `min_height` |
| `max_width` | `max_width` |
| `max_height` | `max_height` |
| `expand` | Sets fixed size to available space |

## Success Criteria

1. **Width/Height Props**: Widgets can use explicit size to override intrinsic
2. **Min/Max Props**: Widgets have size bounds enforced during layout
3. **Expand Prop**: Widgets can request to fill available space
4. **Integration**: Props integrate with existing constraint system
5. **Backward Compatible**: Existing widget code continues to work
6. **Tests Pass**: All unit tests pass

## Implementation Plan

### Task 3.4.1-3.4.3: Already Complete

The intrinsic size calculation for labels, buttons, and containers was implemented in Sections 3.1-3.3:

- **Labels**: Character count × 8px width, 16px height
- **Buttons**: Text size + (20px width, 10px height) padding
- **Containers**: Calculated from children (VBox sums heights, HBox sums widths)

No changes needed to intrinsic_size/2 functions.

### Task 3.4.4: Support `:width` and `:height` props to override intrinsic

**File:** `lib/desktop_ui/widget.ex`

Add width, height, min_width, min_height, max_width, max_height, expand props to widget constructors.

**Files:** `lib/desktop_ui/layout/calculate.ex`

Extract widget props and convert to Context constraints during layout calculation.

```elixir
defp extract_widget_constraints(%Widget{} = widget, available_bounds) do
  fixed_width = Keyword.get(widget.props, :width)
  fixed_height = Keyword.get(widget.props, :height)
  min_width = Keyword.get(widget.props, :min_width)
  min_height = Keyword.get(widget.props, :min_height)
  max_width = Keyword.get(widget.props, :max_width, :infinity)
  max_height = Keyword.get(widget.props, :max_height, :infinity)
  expand = Keyword.get(widget.props, :expand, false)

  # Handle expand prop
  {fixed_width, max_width} = case expand do
    :width -> {available_bounds.width, available_bounds.width}
    :height -> {fixed_height, available_bounds.height}
    true -> {available_bounds.width, available_bounds.height}
    false -> {fixed_width, max_width}
  end

  constraints = %{}
  |> maybe_put(fixed_width, :fixed_width)
  |> maybe_put(fixed_height, :fixed_height)
  |> maybe_put(min_width, :min_width)
  |> maybe_put(min_height, :min_height)
  |> maybe_put(max_width, :max_width)
  |> maybe_put(max_height, :max_height)

  constraints
end

defp maybe_put(constraints, nil, _key), do: constraints
defp maybe_put(constraints, value, key), do: Map.put(constraints, key, value)
```

**Tests:**
- Verify explicit width/height overrides intrinsic size
- Verify explicit width/height works for labels, buttons, containers
- Verify expand prop sets size to available space

### Task 3.4.5: Support `:min_width`, `:min_height` constraints

Already implemented via Context constraint system. Just need to extract from widget props.

**Tests:**
- Verify min_width is enforced
- Verify min_height is enforced
- Verify min constraint works with explicit size (min is ignored if explicit size is smaller)

### Task 3.4.6: Support `:max_width`, `:max_height` constraints

Already implemented via Context constraint system. Just need to extract from widget props.

**Tests:**
- Verify max_width is enforced
- Verify max_height is enforced
- Verify max constraint works with explicit size (max is ignored if explicit size is larger)

### Task 3.4.7: Add `:expand` prop for flexible sizing

The expand prop allows widgets to fill available space. This is useful for:
- "Stretchy" buttons in HBox that should share available space equally
- Containers that should fill their parent

```elixir
expand: :width   # Expand horizontally (fill available width)
expand: :height  # Expand vertically (fill available height)
expand: true     # Expand both directions
```

When expand is set, the widget's fixed size is set to the available space.

**Tests:**
- Verify expand :width fills available width
- Verify expand :height fills available height
- Verify expand true fills both directions
- Verify multiple expanded widgets in HBox share space
- Verify expand works with VBox

## Unit Tests Required

**File:** `test/desktop_ui/size_hints_test.exs` (or extend existing test files)

### Test Structure

```elixir
defmodule DesktopUI.SizeHintsTest do
  use ExUnit.Case
  alias DesktopUI.{Layout, Widget}

  describe "explicit width/height" do
    test "overrides label intrinsic size"
    test "overrides button intrinsic size"
    test "overrides container intrinsic size"
  end

  describe "min constraints" do
    test "enforces min_width on small widgets"
    test "enforces min_height on small widgets"
    test "min constraints ignored if explicit size is smaller"
  end

  describe "max constraints" do
    test "enforces max_width on large widgets"
    test "enforces max_height on large widgets"
    test "max constraints ignored if explicit size is larger"
  end

  describe "expand prop" do
    test "expand :width fills available width"
    test "expand :height fills available height"
    test "expand true fills both directions"
    test "multiple expanded widgets in HBox"
    test "expanded widget in VBox"
  end

  describe "widget constructor updates" do
    test "label accepts size props"
    test "button accepts size props"
    test "container accepts size props"
  end
end
```

**Target:** ~20 tests covering all size hint functionality

## Progress Log

### 2025-01-26 - Implementation Complete

All tasks completed successfully:

**Task 3.4.1-3.4.3**: Already complete (intrinsic_size implemented in sections 3.1-3.3)

**Task 3.4.4**: Support `:width` and `:height` props to override intrinsic
- Modified `layout_leaf/3` to extract widget constraints
- Modified `layout_container/3` to extract widget constraints
- Widget constraints merge with context constraints

**Task 3.4.5**: Support `:min_width`, `:min_height` constraints
- Extracted from widget props and converted to constraints

**Task 3.4.6**: Support `:max_width`, `:max_height` constraints
- Extracted from widget props and converted to constraints
- `:infinity` values are excluded from constraints map

**Task 3.4.7**: Add `:expand` prop for flexible sizing
- `:width` - Expands horizontally to fill available width
- `:height` - Expands vertically to fill available height
- `true` - Expands in both directions
- Sets fixed size to available bounds

**Unit Tests**: Created `test/desktop_ui/size_hints_test.exs`
- 40 comprehensive tests covering all size hint functionality
- All tests passing

**Documentation**: Updated widget.ex documentation
- Added size options to Common Props section
- Updated label, button, and container function docs

## Notes and Considerations

### Design Questions

1. **Expand Behavior**: When multiple widgets have expand, how do they share space?
   - For now: Each expands to full available space (they overlap)
   - Future: Proportional sharing based on expand weights

2. **Prop Priority**: What if widget has both width and min_width?
   - Explicit width takes precedence (fixed_size overrides constraints)
   - This is already handled by the constraint system

3. **Container Expand**: Should expand on containers make them fill space?
   - Yes, container expands its bounds to available space
   - Children are then laid out within expanded container

4. **Infinity Values**: max_width/max_height can be :infinity
   - Means no maximum limit
   - Already handled by constraint system

### Already Implemented

The following intrinsic size calculations were implemented in earlier sections:

**Section 3.1 (Layout Engine Foundation):**
- Labels: Character count × 8px width, 16px height
- Buttons: Text size + (20px width, 10px height) padding
- Constraint system: min, max, fixed size enforcement

**Section 3.2 (VBox):**
- VBox containers: Sum of children heights + spacing + padding

**Section 3.3 (HBox):**
- HBox containers: Sum of children widths + spacing + padding

### Implementation Strategy

Since intrinsic_size is already complete, Section 3.4 focuses on:

1. **Widget Module**: Add size props to Widget constructors (optional parameters)
2. **Layout Module**: Extract widget props and convert to Context constraints
3. **Expand Logic**: Handle expand prop by setting fixed size to available bounds

### Future Work

- Proportional expand (weights for sharing available space)
- Aspect ratio constraints
- Content-based sizing (e.g., wrap_content, match_parent)
- Priority-based layout (some widgets expand more than others)

### Dependencies

- Requires: Section 3.1 (Layout Engine Foundation) - for constraint system
- Requires: Section 3.2 (VBox) - for container layout
- Requires: Section 3.3 (HBox) - for container layout
- Enables: More flexible UI layouts with stretchy widgets

## Integration Considerations

### Widget DSL Usage

```elixir
# Fixed size button
Widget.button("Click", :clicked, width: 100, height: 50)

# Stretchy button in HBox
Widget.container(:hbox, [
  Widget.button("Cancel", :cancel),
  Widget.button("OK", :ok, expand: :width)
], spacing: 10)

# Container with min/max bounds
Widget.container(:vbox, children,
  min_width: 200,
  max_width: 800,
  min_height: 100
)
```

### Layout Integration

Widget props are extracted during layout calculation:

```elixir
def calculate(%Widget{} = widget, available_bounds, context) do
  # Extract size props from widget
  widget_constraints = extract_widget_constraints(widget, available_bounds)

  # Merge widget constraints with context constraints
  merged_constraints = Map.merge(context.constraints, widget_constraints)

  # Use merged constraints for layout
  updated_context = %{context | constraints: merged_constraints}

  # ... rest of layout calculation
end
```

## Files Created (When Complete)

- `lib/desktop_ui/widget.ex` - Modified with updated documentation for size props
- `lib/desktop_ui/layout/calculate.ex` - Modified with widget constraint extraction (~80 lines added)
- `test/desktop_ui/size_hints_test.exs` - Size hints unit tests (467 lines, 40 tests)
