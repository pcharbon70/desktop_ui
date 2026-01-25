# Section 2.6: SDL2 Renderer Implementation - Feature Planning Document

**Feature Branch:** `feature/section-2.6-sdl2-renderer`
**Status:** Pending
**Created:** 2026-01-24
**Planning Document:** `notes/planning/poc/phase-2-graphics-bridge.md`
**Dependencies:** Section 2.5 (DesktopUI.Graphics API Wrapper)

## 1. Problem Statement

DesktopUI currently has a complete Graphics API with SDL2 bindings and a Mock renderer for testing. However, there is no real renderer that can actually draw widget trees to an SDL2 window. Developers can:

- Create SDL2 windows via `DesktopUI.Graphics.create_window/4`
- Draw rectangles via `DesktopUI.Graphics.fill_rect_on_window/6`
- Define widget trees via `DesktopUI.Widget.label/2`, `DesktopUI.Widget.button/3`, `DesktopUI.Widget.container/3`

But they cannot:
- Render a widget tree directly to a window
- See their UI components displayed in a real window
- Build a functional desktop application with visual output

The missing piece is `DesktopUI.Renderer.SDL2`, a module that traverses widget trees and uses the Graphics API to render each widget type.

## 2. Solution Overview

Implement `DesktopUI.Renderer.SDL2` module that:

1. **Initializes with a window_id** - Stores window reference for rendering
2. **Renders widget trees** - Traverses the tree and draws each widget
3. **Handles layout** - Calculates positions for children based on container type (vbox/hbox)
4. **Uses placeholder rendering** - Draws colored rectangles for each widget type (text rendering comes later)
5. **Implements resource cleanup** - Properly releases any allocated resources

### Widget Rendering Strategy

| Widget Type | Visual Representation |
|-------------|----------------------|
| **Label** | Filled rectangle (light blue: `{173, 216, 230, 255}`) |
| **Button** | Outlined rectangle (gray outline `{100, 100, 100, 255}`, lighter fill `{220, 220, 220, 255}`) |
| **Container (vbox)** | No visual, arranges children vertically with spacing/padding |
| **Container (hbox)** | No visual, arranges children horizontally with spacing/padding |

### Architecture

```
DesktopUI.Renderer.SDL2
├── init/1          # Initialize with window_id
├── render/2        # Main render entry point
├── cleanup/1       # Resource cleanup
└── Private
    ├── render_widget/4    # Dispatch to widget-specific renderer
    ├── render_label/4     # Draw label as colored rect
    ├── render_button/4    # Draw button as outlined rect
    ├── render_container/4 # Layout and draw children
    ├── calculate_layout/4 # Compute bounds for container children
    └── clip_to_bounds/4   # Ensure drawing stays within window
```

## 3. Technical Details

### 3.1 Module Structure

```elixir
defmodule DesktopUI.Renderer.SDL2 do
  @moduledoc """
  Real SDL2 renderer that draws widget trees to SDL2 windows.

  Uses DesktopUI.Graphics API for actual drawing operations.
  For now, renders widgets as colored rectangles without text.
  """

  defstruct [:window_id, :window_width, :window_height]

  @type t :: %__MODULE__{
    window_id: non_neg_integer(),
    window_width: pos_integer(),
    window_height: pos_integer()
  }

  # Public API functions...
end
```

### 3.2 Public API

```elixir
# Initialize renderer with window
{:ok, renderer} = DesktopUI.Renderer.SDL2.init(window_id)

# Render a widget tree
:ok = DesktopUI.Renderer.SDL2.render(renderer, widget)

# Cleanup resources
:ok = DesktopUI.Renderer.SDL2.cleanup(renderer)
```

### 3.3 Layout Algorithm

The renderer must calculate actual pixel positions for each widget based on:

1. **Container padding** - Space added at container edges
2. **Container spacing** - Space added between children
3. **Layout direction** - Vertical (vbox) or horizontal (hbox)
4. **Available space** - Window dimensions minus parent constraints

**Layout Calculation:**
```elixir
# For vbox: stack children vertically
defp calculate_layout(:vbox, children, x, y, width, spacing, padding) do
  start_y = y + padding
  current_x = x + padding
  available_width = width - (2 * padding)

  {layouts, _} = Enum.map_reduce(children, start_y, fn child, current_y ->
    child_height = get_widget_height(child, available_width)
    child_layout = %{
      widget: child,
      x: current_x,
      y: current_y,
      width: available_width,
      height: child_height
    }
    {child_layout, current_y + child_height + spacing}
  end)

  layouts
end

# For hbox: arrange children horizontally
defp calculate_layout(:hbox, children, x, y, height, spacing, padding) do
  start_x = x + padding
  current_y = y + padding
  available_height = height - (2 * padding)

  {layouts, _} = Enum.map_reduce(children, start_x, fn child, current_x ->
    child_width = get_widget_width(child, available_height)
    child_layout = %{
      widget: child,
      x: current_x,
      y: current_y,
      width: child_width,
      height: available_height
    }
    {child_layout, current_x + child_width + spacing}
  end)

  layouts
end
```

### 3.4 Widget Dimensions

Default dimensions when not specified:
- **Label**: 100x30 pixels
- **Button**: 80x30 pixels
- **Container**: Size of children plus padding/spacing

### 3.5 Rendering Pipeline

```elixir
def render(renderer, widget) do
  # 1. Clear window with background color
  Graphics.clear_window(renderer.window_id, :white)

  # 2. Traverse and render widget tree
  render_widget(renderer, widget, 0, 0, renderer.window_width, renderer.window_height)

  # 3. Present to screen
  Graphics.present_window(renderer.window_id)

  :ok
end

defp render_widget(renderer, %Widget{type: :label} = widget, x, y, w, h) do
  render_label(renderer, widget, x, y, w, h)
end

defp render_widget(renderer, %Widget{type: :button} = widget, x, y, w, h) do
  render_button(renderer, widget, x, y, w, h)
end

defp render_widget(renderer, %Widget{type: :container, props: props} = widget, x, y, w, h) do
  render_container(renderer, widget, x, y, w, h, props)
end
```

### 3.6 Color Constants

```elixir
# Widget colors for placeholder rendering
@label_color {173, 216, 230, 255}      # Light blue
@button_fill_color {220, 220, 220, 255} # Light gray
@button_outline_color {100, 100, 100, 255} # Dark gray
@background_color {255, 255, 255, 255}  # White
@error_color {255, 100, 100, 255}       # Light red (for unknown widgets)
```

### 3.7 Bounds Checking

Prevent drawing operations that extend outside window boundaries:

```elixir
defp clip_to_bounds(x, y, w, h, max_w, max_h) do
  clipped_x = max(0, min(x, max_w))
  clipped_y = max(0, min(y, max_h))
  clipped_w = min(w, max_w - clipped_x)
  clipped_h = min(h, max_h - clipped_y)
  {clipped_x, clipped_y, clipped_w, clipped_h}
end
```

## 4. Success Criteria

1. **Renderer initializes** - Can create renderer with valid window_id
2. **Label renders** - Label widget draws as colored rectangle
3. **Button renders** - Button widget draws as outlined rectangle
4. **Container layouts** - VBox stacks children vertically, HBox arranges horizontally
5. **Nesting works** - Deeply nested containers render correctly
6. **Spacing works** - Container spacing property creates gaps between children
7. **Padding works** - Container padding property creates margins
8. **Unknown widgets handled** - Unknown widget types return error without crashing
9. **Cleanup succeeds** - Resources released properly
10. **All tests pass** - 6 new tests pass, all existing tests still pass

## 5. Implementation Plan

### Task 2.6.1: Create module structure and init/1 function
**File:** `lib/desktop_ui/renderer/sdl2.ex`

Create the renderer module with initialization:
- Define struct with `window_id`, `window_width`, `window_height`
- Implement `init/1` that accepts `window_id`
- Fetch window dimensions using `Graphics.get_window_size/1`
- Return `{:ok, renderer}` or `{:error, reason}`

### Task 2.6.2: Implement render/2 function
**File:** `lib/desktop_ui/renderer/sdl2.ex`

Implement main render entry point:
- Clear window with background color
- Traverse widget tree starting at root
- Present rendered content to screen
- Return `:ok` or `{:error, reason}`

### Task 2.6.3: Implement render_label/4 function
**File:** `lib/desktop_ui/renderer/sdl2.ex`

Render label as filled rectangle:
- Use `@label_color` constant
- Get dimensions from props or use defaults
- Apply bounds checking
- Call `Graphics.fill_rect_on_window/6`

### Task 2.6.4: Implement render_button/4 function
**File:** `lib/desktop_ui/renderer/sdl2.ex`

Render button as outlined rectangle:
- Fill with `@button_fill_color`
- Draw outline with `@button_outline_color`
- Get dimensions from props or use defaults
- Apply bounds checking

### Task 2.6.5: Implement render_container/4 with layout
**File:** `lib/desktop_ui/renderer/sdl2.ex`

Render container with child layout:
- Extract `:layout`, `:spacing`, `:padding` from props
- Calculate child positions based on layout type
- Recursively render each child at calculated position
- Track and apply spacing between children
- Apply padding at edges

### Task 2.6.6: Implement calculate_layout/5 helper
**File:** `lib/desktop_ui/renderer/sdl2.ex`

Calculate layout for container children:
- Support `:vbox` layout (vertical stacking)
- Support `:hbox` layout (horizontal arrangement)
- Return list of child layouts with positions
- Handle width/height propagation

### Task 2.6.7: Implement bounds checking
**File:** `lib/desktop_ui/renderer/sdl2.ex`

Add `clip_to_bounds/5` function:
- Ensure coordinates are within window
- Ensure dimensions don't extend beyond window
- Return clipped coordinates and dimensions

### Task 2.6.8: Implement cleanup/1 function
**File:** `lib/desktop_ui/renderer/sdl2.ex`

Implement resource cleanup:
- Currently a no-op (Graphics handles cleanup)
- Return `:ok` for consistency
- Future: clean up any renderer-specific resources

### Task 2.6.9: Handle unknown widget types
**File:** `lib/desktop_ui/renderer/sdl2.ex`

Add error handling for unknown widgets:
- Return `{:error, "unknown widget type: :type"}` for unknown types
- Don't crash on unexpected input

## 6. Testing Strategy

### Unit Tests (6 tests)

**File:** `test/desktop_ui/renderer/sdl2_test.exs`

1. **test_init/1** - Verify renderer initializes with valid window_id
   - Create SDL2 window
   - Initialize renderer
   - Verify struct contains correct window_id and dimensions

2. **test_init_invalid_window/1** - Verify initialization fails with invalid window_id
   - Pass non-existent window_id
   - Verify returns `{:error, reason}`

3. **test_render_label/1** - Verify label widget renders correctly
   - Create label widget
   - Render with SDL2 renderer
   - Verify Graphics.fill_rect_on_window was called with correct params

4. **test_render_button/1** - Verify button widget renders correctly
   - Create button widget
   - Render with SDL2 renderer
   - Verify both fill and outline operations occurred

5. **test_render_nested_containers/1** - Verify nested containers render correctly
   - Create vbox containing labels and hbox
   - Render with SDL2 renderer
   - Verify all children rendered at calculated positions

6. **test_render_unknown_widget/1** - Verify unknown widget types handled gracefully
   - Create widget with invalid type
   - Render with SDL2 renderer
   - Verify returns `{:error, reason}` without crashing

### Integration Tests

**File:** `test/integration/sdl2_rendering_integration_test.exs`

1. **test_full_rendering_pipeline/1** - Complete render cycle
   - Create window
   - Build complex widget tree
   - Render to window
   - Verify no errors

2. **test_spacing_and_padding/1** - Layout properties work
   - Create container with spacing
   - Verify children have gaps
   - Create container with padding
   - Verify children have margins

3. **test_multiple_windows/1** - Renderer handles multiple windows
   - Create two windows
   - Create separate renderer for each
   - Render different widgets
   - Verify no cross-contamination

### Manual Testing Checklist

- [ ] Run with SDL2 display available
- [ ] Verify label displays as blue rectangle
- [ ] Verify button displays as gray outlined rectangle
- [ ] Verify vbox stacks children vertically
- [ ] Verify hbox arranges children horizontally
- [ ] Verify spacing creates gaps between children
- [ ] Verify padding creates margins
- [ ] Verify deeply nested containers (3+ levels)

## 7. File Structure

```
desktop_ui/
├── lib/desktop_ui/renderer/
│   ├── mock.ex          # Existing mock renderer
│   └── sdl2.ex          # NEW: SDL2 renderer implementation
├── test/desktop_ui/renderer/
│   ├── mock_test.exs    # Existing mock renderer tests
│   └── sdl2_test.exs    # NEW: SDL2 renderer tests
└── notes/features/
    └── section-2.6-sdl2-renderer.md  # This document
```

## 8. Dependencies

### Required (Already Complete)
- Section 2.1: C NIF Foundation
- Section 2.2: SDL2 Window Management
- Section 2.3: Renderer and Drawing Primitives
- Section 2.4: Event Polling and Translation
- Section 2.5: Graphics API Wrapper
- DesktopUI.Widget module
- DesktopUI.Graphics module

### External Dependencies
- SDL2 development libraries (`libsdl2-dev` on Ubuntu)

## 9. Risk Assessment

### High Risk
- **Layout calculation bugs**: Off-by-one errors in positioning can cause widgets to overlap or be positioned incorrectly
  - **Mitigation**: Start with simple fixed dimensions, add dynamic layout incrementally

### Medium Risk
- **Window size changes**: Renderer stores window size at init, doesn't handle resize
  - **Mitigation**: Document limitation, add resize handling in future section
- **Deep recursion**: Very deep widget trees could cause stack overflow
  - **Mitigation**: Use tail recursion where possible, document reasonable depth limits

### Low Risk
- **Unknown widget types**: Pattern match will crash without catch-all
  - **Mitigation**: Add catch-all clause returning error tuple

## 10. Future Enhancements (Out of Scope)

- **Text rendering**: Display actual label/button text (requires font loading)
- **Widget styling**: Custom colors, borders, shadows per widget
- **Clipping**: Don't draw children outside container bounds
- **Dirty rectangle rendering**: Only redraw changed regions
- **Widget hit detection**: Return bounds for event handling
- **Dynamic sizing**: Calculate widget size based on text content

---

### Progress Tracking

- [ ] 2.6.1 Create module structure and init/1 function
- [ ] 2.6.2 Implement render/2 function
- [ ] 2.6.3 Implement render_label/4 function
- [ ] 2.6.4 Implement render_button/4 function
- [ ] 2.6.5 Implement render_container/4 with layout
- [ ] 2.6.6 Implement calculate_layout/5 helper
- [ ] 2.6.7 Implement bounds checking
- [ ] 2.6.8 Implement cleanup/1 function
- [ ] 2.6.9 Handle unknown widget types
- [ ] 2.6.10 Write unit tests (6 tests)
- [ ] 2.6.11 Write integration tests
- [ ] 2.6.12 Run tests and fix failures
- [ ] 2.6.13 Update planning document
- [ ] 2.6.14 Write summary document
