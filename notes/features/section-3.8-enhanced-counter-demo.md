# Section 3.8: Enhanced Counter Demo - Feature Planning Document

**Feature Branch:** `feature/section-3.8-enhanced-counter-demo`
**Status:** Complete
**Created:** 2025-01-27
**Last Updated:** 2025-01-27

## 1. Problem Statement

The current Counter component (`lib/desktop_ui/examples/counter.ex`) demonstrates basic Elm Architecture and layout capabilities, but lacks the polish needed for a proper demo. The component should showcase all the layout features implemented in Phase 3 (VBox, HBox, spacing, padding, alignment) and provide a visually appealing demonstration of the DesktopUI framework.

### Current State Analysis

Looking at the existing Counter component:
- ✅ Uses VBox for main vertical arrangement
- ✅ Uses HBox for button row
- ✅ Has increment, decrement, and reset buttons
- ✅ Handles Clicked signals via `on_signal/2`
- ❌ No quit button to close the application
- ❌ No visual differentiation between button types
- ❌ Limited use of spacing and padding for visual appeal
- ❌ No alignment options demonstrated
- ❌ No color/style variation (not yet supported by renderer, but can be prepared)

### Goals

Create a polished Counter demo that:
1. Demonstrates all layout capabilities (VBox, HBox, spacing, padding, alignment)
2. Shows proper UI composition patterns
3. Includes all common button types (increment, decrement, reset, quit)
4. Serves as a reference implementation for DesktopUI components

## 2. Solution Overview

Enhance the existing Counter component to be a complete, polished demo:

### Design Decisions

1. **Keep Logic Simple** - Focus on demonstrating layout, not complex state management
2. **Add Quit Functionality** - Include a quit button that terminates the application
3. **Improve Visual Hierarchy** - Use spacing and padding to create visual separation
4. **Demonstrate Alignment** - Add center-aligned elements
5. **Semantic Button IDs** - Use descriptive IDs for all interactive elements
6. **Comment Layout Choices** - Document why specific layout values were chosen

### Component Structure

```
VBox (main container, spacing: 16, padding: 24)
├── Label "DesktopUI Counter" (title, larger font effect via multiple labels or styling)
├── Label "Current: 0" (count display)
├── HBox (button row, spacing: 8, padding: 8, align: :center)
│   ├── Button "-" (decrement)
│   ├── Button "+" (increment, primary action)
│   ├── Button "Reset" (reset)
│   └── Button "Quit" (quit)
└── Label "Use +/- to change count" (instructions)
```

## 3. Agent Consultations Performed

No external agent consultations required. This is an enhancement to existing code based on:
- Current Counter component implementation
- Widget API from `lib/desktop_ui/widget.ex`
- Layout capabilities from Sections 3.1-3.7
- Signal handling patterns from existing code

## 4. Technical Details

### File Locations

**Primary File to Modify:**
- `lib/desktop_ui/examples/counter.ex` - Enhance the Counter component (~50-80 lines modified)

**Supporting Files to Review:**
- `lib/desktop_ui/widget.ex` - Widget constructors and props
- `lib/desktop_ui/elm.ex` - Elm behaviour for component pattern
- `lib/desktop_ui/signals.ex` - Signal types for quit handling

### Signal Handling

The quit button will need to handle application shutdown. Options:
1. **Send a special signal** - Component publishes `:quit` signal that Runtime handles
2. **Direct System.stop** - Component calls `System.stop(0)` directly
3. **Signal to Runtime** - Component sends signal to Runtime to trigger shutdown

**Chosen Approach:** Send a special signal that the Runtime can handle. This keeps the component pure and lets the Runtime control shutdown.

### Widget Tree Structure

```elixir
DesktopUI.Widget.container(:vbox, [
  # Title section
  DesktopUI.Widget.label("DesktopUI Counter", id: :title),

  # Count display (large, prominent)
  DesktopUI.Widget.label("0", id: :count_display),

  # Button row
  DesktopUI.Widget.container(:hbox, [
    DesktopUI.Widget.button("-", :decrement, id: :btn_decrement),
    DesktopUI.Widget.button("+", :increment, id: :btn_increment),
    DesktopUI.Widget.button("Reset", :reset, id: :btn_reset),
    DesktopUI.Widget.button("Quit", :quit, id: :btn_quit)
  ], spacing: 8, padding: 8),

  # Instructions
  DesktopUI.Widget.label("Press + to increment, - to decrement", id: :instructions)
], spacing: 16, padding: 24)
```

### Data Structures

State remains simple:
```elixir
%{count: integer()}
```

Messages:
- `:increment` - Increase count by 1
- `:decrement` - Decrease count by 1
- `:reset` - Set count to 0
- `:quit` - Signal intent to quit (will be handled by Runtime or callback)

## 5. Success Criteria

1. **Component Renders Without Errors** - The Counter component builds a valid widget tree
2. **Layout Structure Matches Plan** - VBox with HBox children, correct spacing/padding
3. **All Buttons Function** - Increment, decrement, reset all work correctly
4. **Quit Button Included** - Component has quit button that sends quit signal
5. **Spacing is Visible** - Layout props create visual separation
6. **Alignment Demonstrated** - Center alignment used where appropriate
7. **Tests Pass** - All component tests pass

## 6. Implementation Plan

### Task 3.8.1: Use VBox for main vertical arrangement

**Status:** Already implemented, verify and enhance
**File:** `lib/desktop_ui/examples/counter.ex`

**Current Implementation:**
```elixir
container(:vbox, [
  label("Counter Demo", id: :title),
  label("Current: #{count}", id: :count_label),
  container(:hbox, [
    button("+", :increment, id: :btn_increment),
    button("-", :decrement, id: :btn_decrement),
    button("Reset", :reset, id: :btn_reset)
  ], spacing: 4)
], spacing: 8, padding: 16)
```

**Enhancement:**
- Increase spacing from 8 to 16 for better visual separation
- Increase padding from 16 to 24 for more breathing room
- Keep VBox structure

### Task 3.8.2: Use HBox for button row

**Status:** Already implemented, verify spacing
**File:** `lib/desktop_ui/examples/counter.ex`

**Current Implementation:**
- HBox with increment, decrement, reset buttons
- Spacing of 4 between buttons

**Enhancement:**
- Increase spacing from 4 to 8 for better touch targets
- Consider adding padding around the button row
- Add quit button

### Task 3.8.3: Add spacing and padding for visual polish

**Status:** Needs implementation
**File:** `lib/desktop_ui/examples/counter.ex`

**Changes:**
- Main VBox: `spacing: 16, padding: 24`
- Button HBox: `spacing: 8, padding: 8`
- Consider separate spacing between sections

### Task 3.8.4: Add window title and sensible dimensions

**Status:** Needs implementation (this is for demo runner, not component)
**Note:** Window configuration is typically in the Runtime start_link options

**Demo Configuration (for documentation or test helper):**
```elixir
DesktopUI.Runtime.start_link(
  root_component: DesktopUI.Examples.Counter,
  window_title: "DesktopUI Counter Demo",
  window_width: 400,
  window_height: 500,
  renderer: DesktopUI.Renderer.SDL2
)
```

### Task 3.8.5: Add center alignment for better appearance

**Status:** Needs verification
**File:** `lib/desktop_ui/examples/counter.ex`

**Implementation:**
- Add `align: :center` to button HBox
- This centers buttons horizontally within the available space

**Note:** Alignment support may need to be verified in Layout module

### Task 3.8.6: Include quit button

**Status:** Needs implementation
**File:** `lib/desktop_ui/examples/counter.ex`

**Implementation:**
1. Add quit button to button row HBox
2. Add `:quit` message handler in `update/2`
3. The quit handler will:
   - Option A: Return a command to signal shutdown
   - Option B: Publish a signal that Runtime handles
   - Option C: Call System.stop/0 directly

**Chosen Approach:** Publish a `desktop_ui.application.quit` signal that the Runtime can handle

### Task 3.8.7: Add visual feedback (different button colors)

**Status:** Placeholder for future styling system
**Note:** The renderer doesn't currently support button colors. This task is for documentation only.

**Future Enhancement:**
- Primary button (increment) could be highlighted
- Destructive button (reset) could be red
- Quit button could be neutral/secondary

**Current Workaround:**
- Use button position to indicate importance (increment in middle)
- Document intent for future styling system

## 7. Unit Tests

### Task 3.8.1: Verify Counter component renders without errors

**Test:** `test/desktop_ui/examples/counter_test.exs`
- Verify widget tree is valid
- Verify all required widgets are present
- Verify widget structure matches expected layout

### Task 3.8.2: Verify buttons are clickable

**Test:** `test/desktop_ui/examples/counter_test.exs`
- Verify each button has correct `on_click` message
- Verify all buttons have unique IDs
- Verify `on_signal/2` handles Clicked signals correctly

### Task 3.8.3: Verify layout matches expected structure

**Test:** `test/desktop_ui/examples/counter_test.exs`
- Verify main container is VBox
- Verify button row is HBox
- Verify spacing and padding props are set
- Verify all children are present

### Task 3.8.4: Verify spacing is visible

**Test:** Integration test with MockRenderer
- Verify layout calculation includes spacing
- Verify children have expected positions

### Task 3.8.5: Verify all buttons function correctly

**Test:** `test/desktop_ui/examples/counter_test.exs`
- Test increment increases count
- Test decrement decreases count
- Test reset sets count to 0
- Test quit sends quit signal

### Task 3.8.6: Verify quit button terminates application

**Test:** Integration test
- Verify quit button sends quit signal
- Verify signal can be handled by Runtime
- Note: Actual termination may be tested in integration tests

## Task Checklist

- [x] 3.8.1 Use VBox for main vertical arrangement (verify and enhance)
- [x] 3.8.2 Use HBox for button row (verify spacing)
- [x] 3.8.3 Add spacing and padding for visual polish
- [x] 3.8.4 Add window title and sensible dimensions (document demo config)
- [x] 3.8.5 Add center alignment for better appearance
- [x] 3.8.6 Include quit button
- [x] 3.8.7 Add visual feedback (placeholder for future styling)

## 8. Dependencies

**Requires:**
- Section 3.1 - Layout Engine Foundation
- Section 3.2 - VBox Container Layout
- Section 3.3 - HBox Container Layout
- Section 3.4 - Widget Size Hints
- Section 3.5 - Renderer with Layout
- Section 3.6 - Hit Testing with Layout
- Section 3.7 - RenderingCoordinator Layout Integration

**Enables:**
- Section 3.9 - Phase 3 Integration Tests
- Future sections on styling and theming

## 9. Notes and Considerations

### Quit Handling

The quit button needs to communicate with the Runtime. Since components are isolated, we'll use a signal-based approach:

```elixir
# In Counter component
def update(:quit, state) do
  {state, [{:publish_signal, "desktop_ui.application.quit"}]}
end

# Or in on_signal
def on_signal(agent, %Jido.Signal{type: "desktop_ui.ui.clicked", data: %{target_id: :btn_quit}}) do
  # Publish quit signal
  {:ok, _signal} = Jido.Signal.Bus.publish(
    :desktop_ui,
    Jido.Signal.new!("desktop_ui.application.quit", %{})
  )
  {:ok, agent}
end
```

### Color/Styling Limitations

The current SDL2 renderer doesn't support per-widget colors. All widgets render with default colors. Task 3.8.7 is a placeholder for future work.

### Alignment Support

Need to verify that the Layout module supports alignment props. If not, we may need to adjust this task or add alignment support first.

### Demo Entry Point

Consider creating a demo script or mix task for running the Counter demo:

```elixir
# lib/mix/tasks/desktop_ui/demo.counter.ex
defmodule Mix.Tasks.DesktopUI.Demo.Counter do
  use Mix.Task

  def run(_) do
    Application.put_all_env([desktop_ui: [runtime: [log_level: :info]]])
    {:ok, _} = DesktopUI.Runtime.start_link(
      root_component: DesktopUI.Examples.Counter,
      window_title: "DesktopUI Counter Demo"
    )
    Process.sleep(:infinity)
  end
end
```

Usage: `mix desktop_ui.demo.counter`
