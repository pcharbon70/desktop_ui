# Section 3.1: Layout Engine Foundation

**Feature Branch:** `feature/section-3.1-layout-engine-foundation`
**Status:** Complete
**Created:** 2025-01-26
**Last Updated:** 2025-01-26

## Overview

Create the core layout engine that calculates widget positions and sizes within containers. This is the foundation for Phase 3 which will enable accurate hit testing, proper widget positioning, and flexible UI composition.

The layout engine transforms widget trees into positioned layouts, adding explicit bounds (x, y, width, height) to each widget based on its type, properties, constraints, and available space.

## Problem Statement

Currently, the RenderingCoordinator receives widget trees from component `view/1` functions, but these trees lack explicit positioning information. Widgets have semantic properties (spacing, padding, desired sizes) but no calculated bounds. This prevents:

1. **Accurate rendering**: Renderers must guess or hardcode positions
2. **Hit testing**: Cannot determine which widget was clicked without position data
3. **Responsive layouts**: Cannot adapt to window size changes
4. **Complex composition**: Cannot properly nest containers with different layouts

We need a layout engine that:
- Calculates explicit bounds for each widget
- Respects size constraints (min, max, fixed)
- Handles container layouts (vbox, hbox)
- Supports intrinsic size calculation
- Returns error for unsatisfiable constraints

## Solution Overview

Create a `DesktopUI.Layout` module that:

1. **Defines Layout Struct**: Represents calculated bounds (x, y, width, height)
2. **Defines Layout Context**: Available bounds, constraints, and rendering hints
3. **Implements calculate/3**: Main entry point that transforms widget trees into laid-out trees
4. **Calculates Intrinsic Sizes**: Determines natural size for leaf widgets (label, button)
5. **Enforces Constraints**: Applies min/max/fixed size constraints
6. **Handles Overflow**: Defines behavior when content exceeds available space

### Key Design Decisions

- **Box Model**: Content + padding (margin handled by container spacing)
- **Fixed Sizes First**: Start with pixel-based sizes, grow to proportional later
- **Annotated Trees**: Layout results preserve widget structure with added bounds
- **Error Returns**: Use `{:ok, laid_out_tree}` or `{:error, reason}` tuples
- **Separate Pass**: Layout is a distinct phase before rendering

## Technical Details

### File Locations

**New Files:**
- `lib/desktop_ui/layout.ex` - Core layout engine (structs, context, calculate/3)
- `test/desktop_ui/layout_test.exs` - Layout engine unit tests

**Modified Files:**
- None (this is foundational work, integration happens in later sections)

### Data Structures

#### Layout Struct

```elixir
defmodule DesktopUI.Layout do
  defstruct [:x, :y, :width, :height, :widget]

  @type t :: %__MODULE__{
    x: non_neg_integer(),
    y: non_neg_integer(),
    width: pos_integer(),
    height: pos_integer(),
    widget: Widget.t() | nil
  }
end
```

#### Layout Context

```elixir
defmodule DesktopUI.Layout.Context do
  defstruct [:available_width, :available_height, :parent_bounds, :constraints]

  @type t :: %__MODULE__{
    available_width: pos_integer(),
    available_height: pos_integer(),
    parent_bounds: %{x: non_neg_integer(), y: non_neg_integer(), width: pos_integer(), height: pos_integer()},
    constraints: constraints()
  }

  @type constraints :: %{
    optional(:min_width) => pos_integer(),
    optional(:max_width) => pos_integer(),
    optional(:min_height) => pos_integer(),
    optional(:max_height) => pos_integer(),
    optional(:fixed_width) => pos_integer(),
    optional(:fixed_height) => pos_integer()
  }
end
```

#### Size Hints

```elixir
@type size_hint :: %{
  intrinsic: %{width: pos_integer(), height: pos_integer()},
  min: %{width: pos_integer(), height: pos_integer()},
  max: %{width: pos_integer() | :infinity, height: pos_integer() | :infinity}
}
```

### Module Structure

```
DesktopUI.Layout
├── Layout struct (x, y, width, height, widget)
├── Context struct (bounds, constraints)
├── calculate/3 (widget, bounds, context)
├── intrinsic_size/2 (widget, context)
├── apply_constraints/3 (size, constraints, context)
└── layout_leaf/3 (widget, bounds, context) - for label, button
```

## Success Criteria

1. **Layout Struct**: Properly defined with x, y, width, height fields
2. **Context Struct**: Properly defined with bounds and constraints
3. **Calculate Function**: Returns valid layout tree for simple cases
4. **Intrinsic Sizes**: Labels and buttons return reasonable default sizes
5. **Constraints**: Min/max/fixed sizes properly enforced
6. **Error Handling**: Unsatisfiable constraints return errors
7. **Tests Pass**: All 7 unit tests pass

## Implementation Plan

### Task 3.1.1: Define Layout Struct

**File:** `lib/desktop_ui/layout.ex`

Create the `DesktopUI.Layout` module with the Layout struct:

```elixir
defmodule DesktopUI.Layout do
  @moduledoc """
  Layout structure representing calculated widget bounds.

  Each layout contains the position and size of a widget within
  a container, along with a reference to the original widget.
  """

  defstruct [:x, :y, :width, :height, :widget]

  @type t :: %__MODULE__{
    x: non_neg_integer(),
    y: non_neg_integer(),
    width: pos_integer(),
    height: pos_integer(),
    widget: DesktopUI.Widget.t() | nil
  }

  @doc """
  Creates a new layout with the given bounds.
  """
  def new(x, y, width, height, widget \\ nil)

  @doc """
  Returns true if the given point (x, y) is within this layout's bounds.
  """
  def contains?(%__MODULE__{} = layout, x, y)
end
```

**Tests:**
- Verify Layout struct creation with valid bounds
- Verify `contains?/3` correctly identifies points inside/outside bounds
- Verify zero-width or zero-height layouts are invalid

### Task 3.1.2: Define Layout Context

**File:** `lib/desktop_ui/layout.ex` (same file, nested module or separate)

Create the `DesktopUI.Layout.Context` struct:

```elixir
defmodule DesktopUI.Layout.Context do
  @moduledoc """
  Context for layout calculation.

  Contains the available space, parent bounds, and size constraints
  for layout calculation.
  """

  defstruct [:available_width, :available_height, :parent_bounds, :constraints]

  @type t :: %__MODULE__{
    available_width: pos_integer(),
    available_height: pos_integer(),
    parent_bounds: bounds(),
    constraints: constraints()
  }

  @type bounds :: %{
    x: non_neg_integer(),
    y: non_neg_integer(),
    width: pos_integer(),
    height: pos_integer()
  }

  @type constraints :: %{
    optional(:min_width) => pos_integer(),
    optional(:max_width) => pos_integer(),
    optional(:min_height) => pos_integer(),
    optional(:max_height) => pos_integer(),
    optional(:fixed_width) => pos_integer(),
    optional(:fixed_height) => pos_integer()
  }

  @doc """
  Creates a new layout context.
  """
  def new(available_width, available_height, opts \\ [])

  @doc """
  Adds constraints to the context.
  """
  def with_constraints(%__MODULE__{} = context, constraints)
end
```

**Tests:**
- Verify layout context initializes correctly
- Verify `new/2` creates context with defaults
- Verify `with_constraints/2` merges constraints correctly

### Task 3.1.3: Implement calculate/3

**File:** `lib/desktop_ui/layout.ex`

Main entry point for layout calculation:

```elixir
@doc """
Calculates the layout for a widget tree within the given bounds.

Returns `{:ok, laid_out_tree}` where each widget in the tree has
an associated Layout struct, or `{:error, reason}` if layout fails.

## Parameters
- widget: The widget tree to layout
- available_bounds: %{width, height} of available space
- context: Layout context with constraints

## Examples
    iex> widget = Widget.label("Hello")
    iex> {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})
    iex> layout.width > 0
    true
"""
@spec calculate(Widget.t(), bounds(), Context.t()) :: {:ok, Layout.t()} | {:error, String.t()}
def calculate(widget, available_bounds, context \\ %Context{})
```

Initial implementation:
- Handle leaf widgets (label, button) by calling `layout_leaf/3`
- Handle containers by delegating to placeholder (full implementation in 3.2, 3.3)
- Return errors for invalid widgets or unsatisfiable constraints

**Tests:**
- Verify calculate returns valid layout tree for label
- Verify calculate returns valid layout tree for button
- Verify calculate returns error for invalid widget
- Verify calculate propagates context constraints

### Task 3.1.4: Add Layout Result Type

Define the laid-out UI tree type:

```elixir
@type laid_out_widget :: Layout.t()

@type laid_out_tree :: laid_out_widget()
```

A laid-out tree is a Layout struct where:
- Leaf widgets (label, button) have `widget` field set to the original widget
- Container layouts contain nested `Layout` structs in their metadata
- Each node has explicit x, y, width, height values

**Tests:**
- Verify laid out tree preserves widget structure
- Verify laid out tree has bounds for all nodes
- Verify type specs compile correctly

### Task 3.1.5: Implement Intrinsic Size Calculation

**File:** `lib/desktop_ui/layout.ex`

Calculate natural sizes for widgets:

```elixir
@doc """
Calculates the intrinsic (natural) size for a widget.

For leaf widgets:
- Label: Based on text length (character_count * char_width + padding)
- Button: Text size + button padding (default: 20px horizontal, 10px vertical)

For containers:
- Calculated from children (implemented in 3.2, 3.3)
"""
@spec intrinsic_size(Widget.t(), Context.t()) :: {:ok, %{width: pos_integer(), height: pos_integer()}} | {:error, String.t()}
def intrinsic_size(widget, context)

# Private helpers
defp estimate_text_size(text), do: %{width: String.length(text) * 8, height: 16}
defp button_padding, do: %{width: 20, height: 10}
```

**Tests:**
- Verify intrinsic size calculation for label (text based)
- Verify intrinsic size calculation for button (text + padding)
- Verify empty text returns minimum size
- Verify long text returns larger size

### Task 3.1.6: Add Size Constraints

Implement constraint enforcement:

```elixir
@doc """
Applies size constraints to a calculated size.

Returns the final size after applying:
1. Fixed size (if specified, overrides everything)
2. Min/max constraints (clamps size)
3. Available bounds (clamps to available space)
"""
@spec apply_constraints(%{width: pos_integer(), height: pos_integer()}, Context.constraints(), bounds()) :: %{width: pos_integer(), height: pos_integer()}
def apply_constraints(size, constraints, available_bounds)

# Private helpers
defp clamp_size(size, min, max, available)
```

**Tests:**
- Verify min_width constraint is enforced
- Verify max_width constraint is enforced
- Verify min_height constraint is enforced
- Verify max_height constraint is enforced
- Verify fixed size overrides intrinsic size
- Verify available bounds clamp final size

## Unit Tests Required

**File:** `test/desktop_ui/layout_test.exs`

### Test Structure

```elixir
defmodule DesktopUI.LayoutTest do
  use ExUnit.Case
  alias DesktopUI.Layout
  alias DesktopUI.Layout.Context
  alias DesktopUI.Widget

  describe "Layout struct" do
    test "creates layout with valid bounds"
    test "contains? returns true for points inside bounds"
    test "contains? returns false for points outside bounds"
  end

  describe "Context struct" do
    test "initializes with available bounds"
    test "accepts and stores constraints"
    test "merges constraints with with_constraints/2"
  end

  describe "calculate/3" do
    test "returns layout for label widget"
    test "returns layout for button widget"
    test "returns error for invalid widget"
    test "respects fixed width constraint"
    test "respects fixed height constraint"
  end

  describe "intrinsic_size/2" do
    test "calculates size for label based on text length"
    test "calculates size for button with padding"
    test "returns minimum size for empty text"
  end

  describe "apply_constraints/3" do
    test "enforces min_width constraint"
    test "enforces max_width constraint"
    test "enforces min_height constraint"
    test "enforces max_height constraint"
    test "fixed size overrides intrinsic size"
    test "available bounds clamp final size"
  end
end
```

## Progress Log

### 2025-01-26 - Planning Complete
- Created feature planning document
- Identified required data structures (Layout, Context)
- Mapped out implementation tasks (3.1.1 - 3.1.6)
- Defined unit test requirements
- Created todo list for tracking

### 2025-01-26 - Implementation Complete
All tasks completed successfully:

**Task 3.1.1 - Layout Struct**: Created `lib/desktop_ui/layout.ex` with:
- x, y, width, height, widget fields
- Type specifications with proper guards
- Helper functions: contains?/2, right/1, bottom/1, center/1, area/1, to_bounds/1

**Task 3.1.2 - Layout Context**: Created `lib/desktop_ui/layout/context.ex` with:
- available_width, available_height, parent_bounds, constraints fields
- Constraint types: fixed_width/height, min_width/height, max_width/height
- new/3, with_constraints/2, and accessor functions

**Task 3.1.3 - calculate/3**: Implemented in `lib/desktop_ui/layout/calculate.ex`:
- Main calculate/3 entry point
- Handles leaf widgets (label, button)
- Container layout placeholder (for 3.2/3.3)
- Error returns for invalid widgets

**Task 3.1.4 - Layout Result Type**:
- Defined layout_result type as {:ok, Layout.t()} | {:error, String.t()}
- Type specs added throughout

**Task 3.1.5 - Intrinsic Size Calculation**:
- Label: text length * 8px width, 16px height
- Button: text size + (20px width, 10px height) padding
- Container: max of children's intrinsic sizes (placeholder)

**Task 3.1.6 - Size Constraints**:
- apply_constraints/3 enforces fixed, min, max, and available bounds
- Fixed sizes override everything
- Proper clamping with min/max constraints

**Unit Tests**: Created `test/desktop_ui/layout/layout_test.exs`:
- 31 tests covering all functionality
- All tests passing

## Notes and Considerations

### Design Questions

1. **Text Size Estimation**: Without actual text rendering, we estimate based on character count.
   - Current estimate: 8px per character width, 16px height
   - This is temporary; real text measurement comes later

2. **Overflow Handling**: For now, we'll clip content that exceeds bounds.
   - Future: Support scrolling and overflow modes

3. **Container Layouts**: Containers are placeholders in this section.
   - VBox/HBox algorithms implemented in sections 3.2 and 3.3
   - For now, containers return intrinsic size of children without positioning

4. **Error Handling**: Layout failures should return clear error messages
   - Help developers understand what constraints cannot be satisfied

### Future Work

- Section 3.2: VBox container layout algorithm
- Section 3.3: HBox container layout algorithm
- Section 3.4: Widget size hints refinement
- Section 3.5: Renderer integration with layout
- Section 3.6: Hit testing using layout bounds
- Section 3.7: RenderingCoordinator integration
- Real text measurement (integration with SDL font rendering)

### Dependencies

- Requires: Phase 1 (Jido-first architecture, Widget DSL)
- Requires: Phase 2 (SDL2 graphics, but not directly - layout is pure Elixir)
- Enables: Section 3.2 (VBox), 3.3 (HBox), 3.6 (Hit testing)

## Files Created (When Complete)

- `lib/desktop_ui/layout.ex` - Core layout engine module (184 lines)
- `lib/desktop_ui/layout/context.ex` - Layout context with constraints (172 lines)
- `lib/desktop_ui/layout/calculate.ex` - Layout calculation engine (272 lines)
- `test/desktop_ui/layout/layout_test.exs` - Unit tests (305 lines, 31 tests)
