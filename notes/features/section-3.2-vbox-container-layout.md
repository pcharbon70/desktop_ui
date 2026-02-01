# Section 3.2: VBox Container Layout

**Feature Branch:** `feature/section-3.2-vbox-container-layout`
**Status:** Complete
**Created:** 2025-01-26
**Last Updated:** 2025-01-26

## Overview

Implement vertical box layout (VBox) for stacking widgets. The VBox layout algorithm positions child widgets vertically, stacking them from top to bottom with configurable spacing, padding, and alignment. This is a fundamental container layout pattern used in almost all UI applications.

## Problem Statement

Section 3.1 implemented the foundation (Layout struct, Context, Calculate module) but container layout is still a placeholder. Currently, containers return only the intrinsic size (max of children) without any actual positioning logic. This prevents:

1. **Vertical Composition**: Cannot stack widgets vertically (e.g., buttons below labels)
2. **Spacing Control**: Cannot add gaps between widgets
3. **Container Padding**: Cannot add margins around container contents
4. **Alignment**: Cannot align children to left, center, or right
5. **Overflow Handling**: Content that exceeds available space has no defined behavior

We need a VBox layout algorithm that:
- Stacks children vertically (y accumulates, x stays same)
- Applies spacing between children (not before first or after last)
- Applies padding around all children
- Aligns children horizontally (:left, :center, :right)
- Handles overflow (clip content that exceeds bounds)

## Solution Overview

Extend the `DesktopUI.Layout.Calculate` module with VBox-specific layout logic:

1. **Update `layout_container/3`**: Detect `:vbox` containers and delegate to `layout_vbox/3`
2. **Implement `layout_vbox/3`**: Calculate positions for all children in vertical stack
3. **Handle Spacing**: Add gaps between children (configurable via `:spacing` prop)
4. **Handle Padding**: Add margins around container contents (via `:padding` prop)
5. **Handle Alignment**: Position children horizontally based on `:align` prop
6. **Handle Overflow**: Clip content when children exceed available space

### Key Design Decisions

- **Intrinsic Height**: Sum of all children heights plus spacing between them
- **Intrinsic Width**: Maximum width of all children (container expands to fit widest child)
- **Spacing**: Applies between children only, not before first or after last
- **Padding**: Reduces available space for children by the padding amount on all sides
- **Alignment**: Controls horizontal positioning of children within available width
- **Overflow**: Clip children that extend beyond container bounds (simplest approach)

## Technical Details

### File Locations

**Modified Files:**
- `lib/desktop_ui/layout/calculate.ex` - Add VBox layout logic

**New Files:**
- `test/desktop_ui/layout/vbox_test.exs` - VBox-specific unit tests

### Data Structures

#### Container Props

VBox containers use these props from the Widget DSL:

```elixir
Widget.container(:vbox, [
  # Spacing between children (default: 0)
  spacing: 5,
  # Padding around all children (default: 0)
  padding: 10,
  # Horizontal alignment (:left, :center, :right) (default: :left)
  align: :center,
  # Children widgets
  # ...
])
```

#### Layout Algorithm

```
1. Calculate intrinsic size for all children
2. Calculate total height: sum(child_heights) + spacing * (child_count - 1)
3. Calculate intrinsic width: max(child_widths)
4. Apply constraints (min, max, fixed) to get final container size
5. For each child:
   a. Calculate child's layout with available width/height
   b. Calculate x position based on alignment
      - :left  -> x = padding_left
      - :center -> x = padding_left + (available_width - child_width) / 2
      - :right -> x = padding_left + (available_width - child_width)
   c. Calculate y position = padding_top + previous_children_height + spacing_used
   d. Create child's Layout struct with calculated bounds
6. Return container Layout with nested child Layouts
```

### Module Structure

```
DesktopUI.Layout.Calculate
├── calculate/3 (existing)
│   └── Delegates containers to layout_container/3
├── layout_container/3 (existing, to be extended)
│   ├── Detects :vbox containers
│   └── Delegates to layout_vbox/3
└── layout_vbox/3 (new)
    ├── Calculate intrinsic size from children
    ├── Apply padding to available bounds
    ├── Layout each child with spacing
    ├── Apply alignment for x positioning
    └── Return container layout with nested child layouts
```

## Success Criteria

1. **VBox Detection**: `:vbox` containers are detected and routed to `layout_vbox/3`
2. **Vertical Stacking**: Children are positioned vertically (y increases for each child)
3. **Spacing**: Gaps appear between children (not before first or after last)
4. **Padding**: Children are inset from container edges by padding amount
5. **Alignment**: Children are positioned horizontally according to `:align` prop
6. **Intrinsic Size**: Container size reflects children plus spacing and padding
7. **Tests Pass**: All 7 unit tests pass

## Implementation Plan

### Task 3.2.1: Implement `layout_vbox/3` - children, available bounds, props

**File:** `lib/desktop_ui/layout/calculate.ex`

Add the `layout_vbox/3` function:

```elixir
defp layout_vbox(%Widget{children: children, props: props}, available_bounds, context) do
  spacing = Keyword.get(props, :spacing, 0)
  padding = Keyword.get(props, :padding, 0)
  align = Keyword.get(props, :align, :left)

  # Calculate intrinsic size from children
  # Apply padding to available space
  # Layout each child
  # Return container layout
end
```

**Tests:**
- Verify function exists and handles empty children list
- Verify function extracts spacing, padding, align from props

### Task 3.2.2: Calculate total height required for all children

**File:** `lib/desktop_ui/layout/calculate.ex`

Implement intrinsic height calculation:

```elixir
defp calculate_vbox_intrinsic_height(children, spacing, context) do
  {total_height, _child_count} =
    Enum.reduce(children, {0, 0}, fn child, {acc_height, count} ->
      case intrinsic_size(child, context) do
        {:ok, %{height: h}} -> {acc_height + h, count + 1}
        _ -> {acc_height, count}
      end
    end)

  # Add spacing between children (not after last)
  spacing_height = spacing * max(child_count - 1, 0)
  total_height + spacing_height
end
```

**Tests:**
- Verify two children sum their heights
- Verify spacing is added between children
- Verify no spacing added for single child
- Verify no spacing added for empty container

### Task 3.2.3: Distribute available space among children

**File:** `lib/desktop_ui/layout/calculate.ex`

Calculate available width for children (after padding):

```elixir
defp calculate_child_available_width(available_width, padding) do
  max(available_width - 2 * padding, 0)
end

defp calculate_child_available_height(available_height, padding, total_content_height) do
  max(available_height - 2 * padding, 0)
end
```

**Tests:**
- Verify available width is reduced by 2x padding
- Verify available width is never negative (clamped to 0)
- Verify children get same available width

### Task 3.2.4: Handle `:spacing` prop for gaps between widgets

**File:** `lib/desktop_ui/layout/calculate.ex`

Calculate y positions with spacing:

```elixir
defp layout_vbox_children(children, spacing, padding, available_width, available_height, align, context) do
  {layouts, _y_offset} =
    Enum.map_reduce(children, padding, fn child, y_offset ->
      # Calculate child layout
      {:ok, child_layout} = calculate(child, %{width: available_width, height: remaining_height}, child_context)

      # Position child at current y_offset
      x_offset = calculate_x_alignment(child_layout.width, available_width, align, padding)
      positioned_layout = %{child_layout | x: x_offset, y: y_offset}

      # Next y position = current y + child height + spacing
      new_y_offset = y_offset + child_layout.height + spacing

      {positioned_layout, new_y_offset}
    end)

  layouts
end
```

**Tests:**
- Verify spacing creates gaps between children
- Verify no spacing before first child
- Verify no spacing after last child

### Task 3.2.5: Handle `:padding` prop for container margins

**File:** `lib/desktop_ui/layout/calculate.ex`

Apply padding to reduce available space:

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

### Task 3.2.6: Support `:align` prop (:left, :center, :right)

**File:** `lib/desktop_ui/layout/calculate.ex`

Calculate x position based on alignment:

```elixir
defp calculate_x_alignment(child_width, available_width, :left, padding) do
  padding
end

defp calculate_x_alignment(child_width, available_width, :center, padding) do
  padding + div(available_width - child_width, 2)
end

defp calculate_x_alignment(child_width, available_width, :right, padding) do
  padding + (available_width - child_width)
end
```

**Tests:**
- Verify :left alignment positions at padding offset
- Verify :center alignment positions at center of available space
- Verify :right alignment positions at right edge minus child width

### Task 3.2.7: Handle overflow when children exceed available space

**File:** `lib/desktop_ui/layout/calculate.ex`

For now, overflow is implicit - children that extend beyond available bounds will be clipped by the renderer. The layout engine:

1. Calculates intrinsic size (may exceed available)
2. Applies constraints (may clamp to available)
3. Positions children (may extend beyond container bottom)

**Tests:**
- Verify children that exceed available height are still positioned
- Verify container height is clamped to available if constrained

## Unit Tests Required

**File:** `test/desktop_ui/layout/vbox_test.exs`

### Test Structure

```elixir
defmodule DesktopUI.Layout.VBoxTest do
  use ExUnit.Case
  alias DesktopUI.{Layout, Layout.Context, Widget}

  describe "VBox intrinsic size" do
    test "calculates height as sum of children"
    test "calculates width as max of children"
    test "adds spacing between children"
    test "adds padding to all sides"
    test "returns zero size for empty container"
  end

  describe "VBox child positioning" do
    test "stacks children vertically"
    test "positions first child at padding offset"
    test "adds spacing between children"
    test "does not add spacing after last child"
  end

  describe "VBox alignment" do
    test ":left aligns children to left edge"
    test ":center centers children horizontally"
    test ":right aligns children to right edge"
  end

  describe "VBox padding" do
    test "insets children from container edges"
    test "reduces available space for children"
    test "works with all alignment options"
  end

  describe "VBox overflow" do
    test "handles children exceeding available height"
    test "clamps container to available bounds when constrained"
  end

  describe "VBox with constraints" do
    test "respects min_width constraint"
    test "respects max_width constraint"
    test "respects fixed_width constraint"
  end
end
```

**Target:** ~30 tests covering all VBox functionality

## Progress Log

### 2025-01-26 - Planning Complete
- Created feature planning document
- Identified required functions (layout_vbox/3, helpers)
- Mapped out implementation tasks (3.2.1 - 3.2.7)
- Defined unit test requirements
- Created todo list for tracking

### 2025-01-26 - Implementation Complete
All tasks completed successfully:

**Task 3.2.1 - layout_vbox/3**: Implemented in `lib/desktop_ui/layout/calculate.ex`:
- Main VBox layout algorithm function
- Extracts spacing, padding, align from props
- Calculates available space for children (minus padding)
- Delegates to helper functions

**Task 3.2.2 - Total Height Calculation**: Implemented intrinsic size calculation:
- Sums all children heights
- Adds spacing between children (not before first or after last)
- Container intrinsic height = sum + spacing + padding

**Task 3.2.3 - Available Space Distribution**: Proper space allocation:
- Child available width = container width - 2 * padding
- Children can use full height needed (10000px for calculation)
- Container clamps to final available bounds

**Task 3.2.4 - Spacing Handling**: Implemented spacing prop:
- Spacing applies between children only
- No spacing before first child
- No spacing after last child
- Y offset accumulates: child_height + spacing

**Task 3.2.5 - Padding Handling**: Implemented padding prop:
- Padding reduces available space for children
- Children positioned at padding offset (top-left)
- Padding applied to all four sides

**Task 3.2.6 - Alignment Support**: Implemented align prop:
- :left - children at padding offset
- :center - children centered in available space
- :right - children at right edge minus child width

**Task 3.2.7 - Overflow Handling**: Container clamps to available bounds:
- apply_constraints clamps to available width/height
- Children that exceed bounds are clipped by renderer
- Explicit max_height/max_width constraints also work

**Nested Containers**: Extended intrinsic_size for VBox containers:
- Added vbox_intrinsic_size/3 for proper nested container sizing
- intrinsic_size/2 now detects :vbox layout type
- Nested VBox containers calculate correct intrinsic size

**Unit Tests**: Created `test/desktop_ui/layout/vbox_test.exs`:
- 33 comprehensive tests covering all VBox functionality
- All tests passing (64 layout tests total including existing tests)

## Notes and Considerations

### Design Questions

1. **Padding Representation**: Padding is a single value applied to all sides.
   - Future: Support individual padding (top, right, bottom, left)
   - Current: Single padding value is sufficient for POC

2. **Spacing Units**: Spacing is in pixels (integer).
   - Consistent with rest of layout engine
   - Future: Support proportional spacing (percentages)

3. **Alignment Default**: Default alignment is `:left`.
   - Matches typical UI framework behavior
   - Center alignment is often explicitly chosen

4. **Overflow Behavior**: For now, overflow is implicitly clipped by renderer.
   - Future: Support scrolling, overflow modes (visible, hidden, scroll)
   - Current: Simple clipping is sufficient for POC

### Future Work

- Section 3.3: HBox container layout algorithm (mirrors VBox)
- Section 3.4: Widget size hints refinement
- Section 3.5: Renderer integration with layout
- Section 3.6: Hit testing using layout bounds
- Individual padding values (padding_top, padding_right, etc.)
- Proportional spacing and sizing
- Scroll containers for overflow

### Dependencies

- Requires: Section 3.1 (Layout Engine Foundation)
- Requires: DesktopUI.Widget module for container creation
- Enables: Section 3.3 (HBox), 3.6 (Hit testing)

## Integration Considerations

### Widget DSL Integration

VBox containers are created via the Widget DSL:

```elixir
Widget.container(:vbox, [
  spacing: 10,
  padding: 20,
  align: :center
], [
  Widget.label("Hello"),
  Widget.button("Click", :clicked)
])
```

### Context Propagation

Each child receives a modified context with:
- Reduced available bounds (minus padding)
- Parent position offset (for absolute positioning)
- Inherited constraints (min/max sizes)

### Layout Result Structure

The result of VBox layout is a Layout struct where:
- The container has x, y, width, height
- Each child Layout is nested within the container
- Child positions are relative to container's origin (0, 0)

## Files Created (When Complete)

**Modified Files:**
- `lib/desktop_ui/layout/calculate.ex` - Added VBox layout logic (~150 lines added)
  - layout_container/3 - Detects :vbox and delegates to layout_vbox/3
  - layout_vbox/3 - Main VBox algorithm
  - layout_vbox_children/7 - Child positioning logic
  - calculate_vbox_x_alignment/4 - Alignment calculations
  - vbox_intrinsic_size/3 - Intrinsic size for VBox containers
  - intrinsic_size/2 - Extended to detect :vbox containers

**New Files:**
- `test/desktop_ui/layout/vbox_test.exs` - VBox unit tests (475 lines, 33 tests)
