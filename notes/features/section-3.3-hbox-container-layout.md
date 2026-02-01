# Section 3.3: HBox Container Layout

**Feature Branch:** `feature/section-3.3-hbox-container-layout`
**Status:** Complete
**Created:** 2025-01-26
**Last Updated:** 2025-01-26

## Overview

Implement horizontal box layout (HBox) for arranging widgets side-by-side. The HBox layout algorithm positions child widgets horizontally, arranging them from left to right with configurable spacing, padding, and vertical alignment. This mirrors the VBox implementation but for the horizontal axis.

## Problem Statement

Section 3.2 implemented VBox layout for vertical stacking. We now need HBox for horizontal arrangement. Currently, HBox containers fall back to the placeholder layout which doesn't properly position children horizontally.

This prevents:
1. **Horizontal Composition**: Cannot arrange widgets side-by-side (e.g., button rows)
2. **Spacing Control**: Cannot add gaps between horizontally-arranged widgets
3. **Container Padding**: Cannot add margins around horizontal container contents
4. **Alignment**: Cannot align children vertically (:top, :center, :bottom)
5. **Overflow Handling**: Content that exceeds available width has no defined behavior

We need an HBox layout algorithm that:
- Arranges children horizontally (x accumulates, y stays same)
- Applies spacing between children (not before first or after last)
- Applies padding around all children
- Aligns children vertically (:top, :center, :bottom)
- Handles overflow (clip content that exceeds bounds)

## Solution Overview

Extend the `DesktopUI.Layout.Calculate` module with HBox-specific layout logic, mirroring the VBox implementation:

1. **Update `layout_container/3`**: Route `:hbox` containers to `layout_hbox/3`
2. **Implement `layout_hbox/3`**: Calculate positions for all children horizontally
3. **Handle Spacing**: Add gaps between children (configurable via `:spacing` prop)
4. **Handle Padding**: Add margins around container contents (via `:padding` prop)
5. **Handle Alignment**: Position children vertically based on `:align` prop
6. **Handle Overflow**: Clip children that extend beyond container width

### Key Design Decisions

- **Intrinsic Width**: Sum of all children widths plus spacing between them
- **Intrinsic Height**: Maximum height of all children (container expands to fit tallest child)
- **Spacing**: Applies between children only, not before first or after last
- **Padding**: Reduces available space for children by the padding amount on all sides
- **Alignment**: Controls vertical positioning of children within available height
- **Overflow**: Clip children that extend beyond container bounds (simplest approach)
- **Implementation**: Mirror VBox logic, swapping x/y and width/height

## Technical Details

### File Locations

**Modified Files:**
- `lib/desktop_ui/layout/calculate.ex` - Add HBox layout logic

**New Files:**
- `test/desktop_ui/layout/hbox_test.exs` - HBox-specific unit tests

### Data Structures

#### Container Props

HBox containers use these props from the Widget DSL:

```elixir
Widget.container(:hbox, [
  # Spacing between children (default: 0)
  spacing: 5,
  # Padding around all children (default: 0)
  padding: 10,
  # Vertical alignment (:top, :center, :bottom) (default: :top)
  align: :center,
  # Children widgets
  # ...
])
```

#### Layout Algorithm (Mirror of VBox)

```
1. Calculate intrinsic size for all children
2. Calculate total width: sum(child_widths) + spacing * (child_count - 1)
3. Calculate intrinsic height: max(child_heights)
4. Apply constraints (min, max, fixed) to get final container size
5. For each child:
   a. Calculate child's layout with available width/height
   b. Calculate x position = previous_children_width + spacing_used
   c. Calculate y position based on alignment
      - :top  -> y = padding_top
      - :center -> y = padding_top + (available_height - child_height) / 2
      - :bottom -> y = padding_top + (available_height - child_height)
   d. Create child's Layout struct with calculated bounds
6. Return container Layout with nested child Layouts
```

### Module Structure

```
DesktopUI.Layout.Calculate
├── calculate/3 (existing)
│   └── Delegates containers to layout_container/3
├── layout_container/3 (extended)
│   ├── Detects :vbox containers → layout_vbox/3 (existing)
│   └── Detects :hbox containers → layout_hbox/3 (new)
└── layout_hbox/3 (new)
    ├── Calculate intrinsic size from children
    ├── Apply padding to available bounds
    ├── Layout each child with spacing
    ├── Apply alignment for y positioning
    └── Return container layout with nested child layouts
```

## Success Criteria

1. **HBox Detection**: `:hbox` containers are detected and routed to `layout_hbox/3`
2. **Horizontal Arrangement**: Children are positioned horizontally (x increases for each child)
3. **Spacing**: Gaps appear between children (not before first or after last)
4. **Padding**: Children are inset from container edges by padding amount
5. **Alignment**: Children are positioned vertically according to `:align` prop
6. **Intrinsic Size**: Container size reflects children plus spacing and padding
7. **Tests Pass**: All 7 unit tests pass

## Implementation Plan

### Task 3.3.1: Implement `layout_hbox/3` - children, available bounds, props

**File:** `lib/desktop_ui/layout/calculate.ex`

Add the `layout_hbox/3` function mirroring `layout_vbox/3`:

```elixir
defp layout_hbox(%Widget{children: children, props: props}, available_bounds, context) do
  spacing = Keyword.get(props, :spacing, 0)
  padding = Keyword.get(props, :padding, 0)
  align = Keyword.get(props, :align, :top)

  # Calculate intrinsic size from children
  # Apply padding to available space
  # Layout each child
  # Return container layout
end
```

**Tests:**
- Verify function exists and handles empty children list
- Verify function extracts spacing, padding, align from props

### Task 3.3.2: Calculate total width required for all children

**File:** `lib/desktop_ui/layout/calculate.ex`

Implement intrinsic width calculation:

```elixir
defp calculate_hbox_intrinsic_width(children, spacing, context) do
  {total_width, _child_count} =
    Enum.reduce(children, {0, 0}, fn child, {acc_width, count} ->
      case intrinsic_size(child, context) do
        {:ok, %{width: w}} -> {acc_width + w, count + 1}
        _ -> {acc_width, count}
      end
    end)

  # Add spacing between children (not after last)
  spacing_width = spacing * max(child_count - 1, 0)
  total_width + spacing_width
end
```

**Tests:**
- Verify two children sum their widths
- Verify spacing is added between children
- Verify no spacing added for single child
- Verify no spacing added for empty container

### Task 3.3.3: Distribute available space horizontally

**File:** `lib/desktop_ui/layout/calculate.ex`

Calculate available height for children (after padding):

```elixir
defp calculate_child_available_height(available_height, padding) do
  max(available_height - 2 * padding, 0)
end

defp calculate_child_available_width(available_width, padding, total_content_width) do
  max(available_width - 2 * padding, 0)
end
```

**Tests:**
- Verify available height is reduced by 2x padding
- Verify available height is never negative (clamped to 0)
- Verify children get same available height

### Task 3.3.4: Handle `:spacing` prop for horizontal gaps

**File:** `lib/desktop_ui/layout/calculate.ex`

Calculate x positions with spacing:

```elixir
defp layout_hbox_children(children, spacing, padding, available_width, available_height, align, context) do
  {layouts, _x_offset} =
    Enum.map_reduce(children, padding, fn child, x_offset ->
      # Calculate child layout
      {:ok, child_layout} = calculate(child, child_available_bounds, child_context)

      # Position child at current x_offset
      y_offset = calculate_y_alignment(child_layout.height, available_height, align, padding)
      positioned_layout = %{child_layout | x: x_offset, y: y_offset}

      # Next x position = current x + child width + spacing
      new_x_offset = x_offset + child_layout.width + spacing

      {positioned_layout, new_x_offset}
    end)

  layouts
end
```

**Tests:**
- Verify spacing creates gaps between children
- Verify no spacing before first child
- Verify no spacing after last child

### Task 3.3.5: Handle `:padding` prop for container margins

**File:** `lib/desktop_ui/layout/calculate.ex`

Apply padding to reduce available space (same as VBox):

```elixir
defp apply_padding_to_bounds(available_bounds, padding) do
  %{
    width: max(available_bounds.width - 2 * padding, 0),
    height: max(available_bounds.height - 2 * padding, 0)
  }
end
```

**Tests:**
- Verify padding reduces available space
- Verify padding is applied on all sides
- Verify double padding is subtracted (left + right, top + bottom)

### Task 3.3.6: Support `:align` prop (:top, :center, :bottom)

**File:** `lib/desktop_ui/layout/calculate.ex`

Calculate y position based on alignment:

```elixir
defp calculate_hbox_y_alignment(_child_height, _available_height, :top, padding) do
  padding
end

defp calculate_hbox_y_alignment(child_height, available_height, :center, padding) do
  padding + div(available_height - child_height, 2)
end

defp calculate_hbox_y_alignment(child_height, available_height, :bottom, padding) do
  padding + (available_height - child_height)
end
```

**Tests:**
- Verify :top alignment positions at padding offset
- Verify :center alignment positions at center of available space
- Verify :bottom alignment positions at bottom edge minus child height

### Task 3.3.7: Handle overflow when children exceed available space

**File:** `lib/desktop_ui/layout/calculate.ex`

For now, overflow is implicit - children that extend beyond available bounds will be clipped by the renderer. The layout engine:

1. Calculates intrinsic size (may exceed available)
2. Applies constraints (may clamp to available)
3. Positions children (may extend beyond container right edge)

**Tests:**
- Verify children that exceed available width are still positioned
- Verify container width is clamped to available if constrained

## Unit Tests Required

**File:** `test/desktop_ui/layout/hbox_test.exs`

### Test Structure

```elixir
defmodule DesktopUI.Layout.HBoxTest do
  use ExUnit.Case
  alias DesktopUI.{Layout, Layout.Context, Widget}

  describe "HBox intrinsic size" do
    test "calculates width as sum of children"
    test "calculates height as max of children"
    test "adds spacing between children"
    test "adds padding to all sides"
    test "returns zero size for empty container"
  end

  describe "HBox child positioning" do
    test "arranges children horizontally"
    test "positions first child at padding offset"
    test "adds spacing between children"
    test "does not add spacing after last child"
  end

  describe "HBox alignment" do
    test ":top aligns children to top edge"
    test ":center centers children vertically"
    test ":bottom aligns children to bottom edge"
  end

  describe "HBox padding" do
    test "insets children from container edges"
    test "reduces available space for children"
    test "works with all alignment options"
  end

  describe "HBox overflow" do
    test "handles children exceeding available width"
    test "clamps container to available bounds when constrained"
  end

  describe "HBox with constraints" do
    test "respects min_width constraint"
    test "respects max_width constraint"
    test "respects fixed_width constraint"
  end

  describe "HBox nested containers" do
    test "handles hbox containing vbox"
    test "calculates correct size for nested hbox"
  end

  describe "HBox edge cases" do
    test "handles single child"
    test "handles zero spacing"
    test "handles zero padding"
    test "defaults to top alignment"
  end
end
```

**Target:** ~35 tests covering all HBox functionality

## Progress Log

### 2025-01-26 - Planning Complete
- Created feature planning document
- Identified required functions (layout_hbox/3, helpers)
- Mapped out implementation tasks (3.3.1 - 3.3.7)
- Defined unit test requirements
- Created todo list for tracking

### 2025-01-26 - Implementation Complete
All tasks completed successfully:

**Task 3.3.1 - layout_hbox/3**: Implemented in `lib/desktop_ui/layout/calculate.ex`:
- Main HBox layout algorithm function
- Extracts spacing, padding, align from props
- Calculates available space for children (minus padding)
- Delegates to helper functions

**Task 3.3.2 - Total Width Calculation**: Implemented intrinsic size calculation:
- Sums all children widths
- Adds spacing between children (not before first or after last)
- Container intrinsic width = sum + spacing + padding

**Task 3.3.3 - Available Space Distribution**: Proper space allocation:
- Child available height = container height - 2 * padding
- Children can use full width needed (10000px for calculation)
- Container clamps to final available bounds

**Task 3.3.4 - Spacing Handling**: Implemented spacing prop:
- Spacing applies between children only
- No spacing before first child
- No spacing after last child
- X offset accumulates: child_width + spacing

**Task 3.3.5 - Padding Handling**: Implemented padding prop:
- Padding reduces available space for children
- Children positioned at padding offset (top-left)
- Padding applied to all four sides

**Task 3.3.6 - Alignment Support**: Implemented align prop:
- :top - children at y = padding
- :center - children centered in available space
- :bottom - children at bottom edge minus child height

**Task 3.3.7 - Overflow Handling**: Container clamps to available bounds:
- apply_constraints clamps to available width/height
- Children that exceed bounds are clipped by renderer
- Explicit max_width/max_height constraints also work

**Nested Containers**: Extended intrinsic_size for HBox containers:
- Added hbox_intrinsic_size/3 for proper nested container sizing
- intrinsic_size/2 now routes :hbox to hbox_intrinsic_size/3
- Nested HBox containers calculate correct intrinsic size

**Unit Tests**: Created `test/desktop_ui/layout/hbox_test.exs`:
- 36 comprehensive tests covering all HBox functionality
- All tests passing (100 layout tests total including existing tests)

## Notes and Considerations

### Design Questions

1. **Padding Representation**: Padding is a single value applied to all sides.
   - Future: Support individual padding (top, right, bottom, left)
   - Current: Single padding value is sufficient for POC

2. **Spacing Units**: Spacing is in pixels (integer).
   - Consistent with VBox layout
   - Future: Support proportional spacing (percentages)

3. **Alignment Default**: Default alignment is `:top`.
   - Matches typical UI framework behavior
   - Center alignment is often explicitly chosen

4. **Overflow Behavior**: For now, overflow is implicitly clipped by renderer.
   - Future: Support scrolling, overflow modes (visible, hidden, scroll)
   - Current: Simple clipping is sufficient for POC

### Implementation Strategy

Since HBox mirrors VBox, the implementation can follow the same pattern:

1. Copy VBox logic structure
2. Swap x/y axes
3. Swap width/height dimensions
4. Change alignment from horizontal (:left, :center, :right) to vertical (:top, :center, :bottom)

### Future Work

- Section 3.4: Widget size hints refinement
- Section 3.5: Renderer integration with layout
- Section 3.6: Hit testing using layout bounds
- Individual padding values (padding_top, padding_right, etc.)
- Proportional spacing and sizing
- Scroll containers for overflow

### Dependencies

- Requires: Section 3.1 (Layout Engine Foundation)
- Requires: Section 3.2 (VBox Container Layout) - for reference pattern
- Enables: Section 3.6 (Hit testing)

## Integration Considerations

### Widget DSL Integration

HBox containers are created via the Widget DSL:

```elixir
Widget.container(:hbox, [
  Widget.button("Yes", :yes),
  Widget.button("No", :no)
], spacing: 8, padding: 16, align: :center)
```

### Context Propagation

Each child receives a modified context with:
- Reduced available bounds (minus padding)
- Parent position offset (for absolute positioning)
- Inherited constraints (min/max sizes)

### Layout Result Structure

The result of HBox layout is a Layout struct where:
- The container has x, y, width, height
- Each child Layout is nested within the container
- Child positions are relative to container's origin (0, 0)

## Files Created (When Complete)

**Modified Files:**
- `lib/desktop_ui/layout/calculate.ex` - Added HBox layout logic (~160 lines added)
  - layout_container/3 - Routes :hbox to layout_hbox/3
  - layout_hbox/3 - Main HBox algorithm
  - layout_hbox_children/7 - Child positioning logic
  - calculate_hbox_y_alignment/4 - Alignment calculations
  - hbox_intrinsic_size/3 - Intrinsic size for HBox containers
  - intrinsic_size/2 - Extended to route :hbox to hbox_intrinsic_size/3

**New Files:**
- `test/desktop_ui/layout/hbox_test.exs` - HBox unit tests (549 lines, 36 tests)
