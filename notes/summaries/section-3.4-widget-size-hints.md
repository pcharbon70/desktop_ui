# Section 3.4: Widget Size Hints - Implementation Summary

**Feature Branch:** `feature/section-3.4-widget-size-hints`
**Status:** Complete
**Date:** 2025-01-26

## Overview

Successfully implemented Section 3.4 of Phase 3: First Real Widget. This section adds widget-level size hints that allow widgets to override or modify their intrinsic size calculation, including explicit width/height props, min/max constraints, and an expand property for flexible sizing.

## Completed Tasks

### Task 3.4.1-3.4.3: Intrinsic Size Calculation (Already Complete)

The intrinsic size calculation for labels, buttons, and containers was implemented in Sections 3.1-3.3:
- **Labels**: Character count × 8px width, 16px height
- **Buttons**: Text size + (20px width, 10px height) padding
- **Containers**: Calculated from children (VBox sums heights, HBox sums widths)

### Task 3.4.4: Support `:width` and `:height` Props

Added widget-level size props that override intrinsic size:

**File:** `lib/desktop_ui/layout/calculate.ex`

Modified `layout_leaf/3` and `layout_container/3` to:
1. Extract widget constraints via `extract_widget_constraints/2`
2. Merge widget constraints with context constraints
3. Use merged constraints for layout calculation

```elixir
defp layout_leaf(%Widget{} = widget, available_bounds, context) do
  # Extract size props from widget and merge with context constraints
  widget_constraints = extract_widget_constraints(widget, available_bounds)
  merged_constraints = Map.merge(context.constraints, widget_constraints)
  updated_context = %{context | constraints: merged_constraints}
  # ... rest of layout calculation
end
```

### Task 3.4.5: Support `:min_width`, `:min_height` Constraints

Min constraints are extracted from widget props and converted to Context constraints:
- `:min_width` - Minimum width in pixels
- `:min_height` - Minimum height in pixels

### Task 3.4.6: Support `:max_width`, `:max_height` Constraints

Max constraints are extracted from widget props and converted to Context constraints:
- `:max_width` - Maximum width in pixels (or `:infinity`)
- `:max_height` - Maximum height in pixels (or `:infinity`)

`:infinity` values are excluded from the constraints map to avoid clutter.

### Task 3.4.7: Add `:expand` Prop for Flexible Sizing

The expand prop allows widgets to fill available space:

- `expand: :width` - Expand horizontally (fill available width)
- `expand: :height` - Expand vertically (fill available height)
- `expand: true` - Expand in both directions

When expand is set, the widget's fixed size is set to the available space.

## Files Modified

### `lib/desktop_ui/widget.ex`

Updated documentation for all widget constructors:
- Added size options to Common Props section
- Updated `label/2` documentation with size options
- Updated `button/3` documentation with size options
- Updated `container/3` documentation with size options

The widget constructors already accepted arbitrary keyword options, so no code changes were needed—only documentation updates.

### `lib/desktop_ui/layout/calculate.ex`

Added ~80 lines of new functionality:

**New Function:**
- `extract_widget_constraints/2` - Extracts size props from widgets and converts to constraints
- `maybe_put_constraint/3,4` - Helper functions for building constraints map

**Modified Functions:**
- `layout_leaf/3` - Now extracts and merges widget constraints
- `layout_container/3` - Now extracts and merges widget constraints

### `test/desktop_ui/size_hints_test.exs` (NEW - 467 lines, 40 tests)

Comprehensive test coverage:

1. **Explicit width/height** (5 tests)
   - Overrides label intrinsic size
   - Overrides button intrinsic size
   - Overrides container intrinsic size
   - Width only uses intrinsic height
   - Height only uses intrinsic width

2. **Min constraints** (5 tests)
   - Enforces min_width on small widgets
   - Enforces min_height on small widgets
   - Min constraint ignored if intrinsic is larger
   - Min constraint ignored if explicit size is smaller
   - Min_width and min_height work together

3. **Max constraints** (6 tests)
   - Enforces max_width on large widgets
   - Enforces max_height on tall widgets
   - Max constraint ignored if intrinsic is smaller
   - Max constraint ignored if explicit size is larger
   - Max_width and max_height work together
   - Max_width :infinity allows any width

4. **Expand prop** (5 tests)
   - Expand :width fills available width
   - Expand :height fills available height
   - Expand true fills both directions
   - Expand with explicit width uses explicit for non-expand direction
   - Expand with explicit height uses explicit for non-expand direction

5. **Expand in containers** (3 tests)
   - Expanded widget in HBox fills available width
   - Expanded widget in VBox fills available height
   - Container with expand true fills available space

6. **Widget constructor updates** (3 tests)
   - Label accepts size props
   - Button accepts size props
   - Container accepts size props

7. **extract_widget_constraints/2** (7 tests)
   - Extracts width and height as fixed constraints
   - Extracts min and max constraints
   - Extracts expand :width as fixed_width constraint
   - Extracts expand :height as fixed_height constraint
   - Extracts expand true as both fixed constraints
   - Returns empty map for widget with no size props
   - Expand with explicit width combines correctly

8. **Combined size hints** (3 tests)
   - Width with min_width on container
   - Min and max constraints create a range
   - All size props together

9. **Backward compatibility** (3 tests)
   - Widgets without size props still work
   - Existing container layouts still work
   - Buttons without size props use intrinsic size

## Test Results

**Size Hints Tests:** 40 tests, 0 failures
**All Layout Tests:** 140 tests (100 existing + 40 new), 0 failures
**All Widget Tests:** 46 tests, 0 failures

## Widget Prop to Constraint Mapping

| Widget Prop  | Context Constraint | Behavior                           |
|-------------|-------------------|-------------------------------------|
| `:width`     | `:fixed_width`    | Exact pixel width                   |
| `:height`    | `:fixed_height`   | Exact pixel height                  |
| `:min_width` | `:min_width`      | Minimum width in pixels             |
| `:min_height`| `:min_height`     | Minimum height in pixels            |
| `:max_width` | `:max_width`      | Maximum width (or `:infinity`)      |
| `:max_height`| `:max_height`     | Maximum height (or `:infinity`)     |
| `:expand`    | Sets fixed size   | `:width`, `:height`, or `true`      |

## Usage Examples

### Fixed Size Widget

```elixir
Widget.label("Hello", width: 200, height: 50)
```

### Min/Max Constraints

```elixir
Widget.button("Click", :clicked,
  min_width: 100,
  max_width: 300,
  min_height: 30
)
```

### Expand (Stretchy Widgets)

```elixir
# Stretchy button in HBox
Widget.container(:hbox, [
  Widget.button("Cancel", :cancel),
  Widget.button("OK", :ok, expand: :width)
], spacing: 10)

# Container that fills available space
Widget.container(:vbox, children, expand: true)
```

### Combined Size Hints

```elixir
Widget.container(:vbox, children,
  min_width: 200,
  max_width: 800,
  min_height: 100,
  height: 500  # Exact height, but width constrained between 200-800
)
```

## Implementation Highlights

### Widget Constraint Extraction

The `extract_widget_constraints/2` function extracts size-related props from widgets and converts them to layout constraints:

```elixir
def extract_widget_constraints(%Widget{props: props}, available_bounds) do
  fixed_width = Keyword.get(props, :width)
  fixed_height = Keyword.get(props, :height)
  min_width = Keyword.get(props, :min_width)
  min_height = Keyword.get(props, :min_height)
  max_width = Keyword.get(props, :max_width)
  max_height = Keyword.get(props, :max_height)
  expand = Keyword.get(props, :expand, false)

  # Handle expand prop - sets fixed size to available space
  {fixed_width, max_width} = case expand do
    :width -> {available_bounds.width, available_bounds.width}
    :height -> {fixed_width, max_width}
    true -> {available_bounds.width, available_bounds.width}
    false -> {fixed_width, max_width}
    nil -> {fixed_width, max_width}
  end

  # ... similar for height

  # Build constraints map, excluding nil and :infinity values
  %{}
  |> maybe_put_constraint(fixed_width, :fixed_width)
  |> maybe_put_constraint(fixed_height, :fixed_height)
  |> maybe_put_constraint(min_width, :min_width)
  |> maybe_put_constraint(min_height, :min_height)
  |> maybe_put_constraint(max_width, :max_width, :infinity)
  |> maybe_put_constraint(max_height, :max_height, :infinity)
end
```

### Integration with Layout Calculation

Widget constraints are extracted and merged with context constraints during layout calculation:

```elixir
# In layout_leaf/3 and layout_container/3:
widget_constraints = extract_widget_constraints(widget, available_bounds)
merged_constraints = Map.merge(context.constraints, widget_constraints)
updated_context = %{context | constraints: merged_constraints}
```

### Constraint Precedence

The constraint system handles precedence correctly:
1. **Fixed size** (`:width`, `:height`) overrides everything
2. **Min/max constraints** clamp the size
3. **Intrinsic size** is used when no constraints apply

## Design Decisions

1. **Reuse Existing Constraint System**: Widget props convert to existing Context constraints rather than creating a new system
2. **Backward Compatible**: All props are optional; existing code continues to work
3. **Infinity Values**: `:infinity` for max_width/max_height is excluded from constraints map (treated as "no limit")
4. **Expand Behavior**: For now, each expanded widget fills full available space (they overlap if multiple expand)
5. **Explicit Takes Precedence**: When both explicit size and min/max are specified, explicit size wins

## Future Work

- Proportional expand (weights for sharing available space between multiple expanded widgets)
- Aspect ratio constraints (e.g., maintain 16:9 ratio)
- Content-based sizing modes (e.g., wrap_content, match_parent from Android)
- Priority-based layout (some widgets expand more than others)

## Dependencies

- Requires: Section 3.1 (Layout Engine Foundation) - for constraint system
- Requires: Section 3.2 (VBox) - for container layout
- Requires: Section 3.3 (HBox) - for container layout
- Enables: More flexible UI layouts with stretchy widgets

## Integration Notes

The widget size hints feature integrates seamlessly with the existing layout engine:

1. **Widgets** accept size props via their existing keyword options
2. **Layout engine** extracts these props and converts to constraints
3. **Constraint system** applies the constraints during size calculation
4. **Result** is widgets that can override intrinsic size or request flexible sizing

This allows for more sophisticated layouts such as:
- Fixed-size buttons for consistent UI
- Stretchy buttons that share available space in toolbars
- Containers with min/max bounds for responsive design
- Widgets that expand to fill their parent's available space
