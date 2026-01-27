# Section 3.7: RenderingCoordinator Layout Integration - Feature Planning Document

**Feature Branch:** `feature/section-3.7-rendering-coordinator-layout-integration`
**Status:** Implementation
**Created:** 2025-01-27
**Last Updated:** 2025-01-27

## 1. Problem Statement

The DesktopUI framework currently has a disconnect between layout calculation and the rendering pipeline. The RenderingCoordinator calls `view/1` to get the widget tree and passes it to the renderer, which then performs its own layout calculation. While the renderer was updated in Section 3.5 to accept pre-calculated layouts, the coordinator does not yet:

1. **Calculate layout after view/1** - Layout should happen in the coordinator, not the renderer
2. **Store current layout tree** - Layout must be stored for Runtime hit testing
3. **Trigger layout recalculation on UI changes** - State changes and window resize events need layout updates
4. **Optimize layout calculation** - Skip layout when UI tree is unchanged
5. **Pass layout to renderer** - Use the pre-calculated layout instead of having renderer recalculate

### Current Architecture Gaps

- Layout calculation happens in both coordinator (for hit testing) and renderer (for rendering)
- No UI tree version tracking to detect changes for layout optimization
- Window resize events (WindowResized signal) are not handled by coordinator
- No mechanism to get window bounds for layout calculation
- Layout recalculation is triggered but not optimized

## 2. Solution Overview

Integrate layout calculation into the RenderingCoordinator rendering pipeline:

1. **Layout Pass After view/1**: Calculate layout immediately after getting the widget tree
2. **Store Layout in ETS**: Keep the layout tree available for Runtime hit testing
3. **Window Resize Handling**: Subscribe to WindowResized signals and trigger layout recalculation
4. **UI Tree Version Tracking**: Detect unchanged UI trees to skip layout calculation
5. **Pass Layout to Renderer**: Modify renderer call to use pre-calculated layout
6. **Metrics Tracking**: Add timing metrics for layout calculation performance

### Key Design Decisions

- **Coordinator-Owned Layout**: Layout is calculated once in coordinator, stored, and passed to renderer
- **ETS Storage**: Use existing ETS table (`@layouts_table`) for layout storage
- **Version Tracking**: Add `ui_tree_version` to component info to detect changes
- **Signal-Based Resize**: WindowResized signals trigger layout recalculation
- **Metrics Collection**: Track layout calculation time for performance analysis
- **Graceful Degradation**: If layout fails, still render widget tree (existing behavior)

## 3. Agent Consultations Performed

No external agent consultations required. This is an internal refactoring based on:
- Existing code in `lib/desktop_ui/rendering_coordinator.ex`
- Layout module API in `lib/desktop_ui/layout.ex`
- Renderer interface in `lib/desktop_ui/renderer/sdl2.ex`
- Signal definitions in `lib/desktop_ui/signals.ex`
- EventLoop implementation in `lib/desktop_ui/runtime/event_loop.ex`

## 4. Technical Details

### File Locations

**Primary Files to Modify:**
- `lib/desktop_ui/rendering_coordinator.ex` - Core implementation (~150 lines modified/added)

**Supporting Files to Modify:**
- `lib/desktop_ui/runtime/event_loop.ex` - May need update for hit testing integration
- `lib/desktop_ui/renderer/sdl2.ex` - May need update to accept layout from coordinator

**Test Files to Extend:**
- `test/desktop_ui/rendering_coordinator_test.exs` - Add layout integration tests (~200 lines)
- `test/integration/phase_3_integration_test.exs` - Add end-to-end tests (~150 lines)

### Data Structures

#### Component Info with UI Tree Version

```elixir
%{
  module: module(),
  pid: pid() | nil,
  registered_at: DateTime.t(),
  last_rendered: DateTime.t() | nil,
  ui_tree_version: non_neg_integer()  # NEW: Track widget tree changes
}
```

#### Layout ETS Storage (Existing from 3.6)

```elixir
# Table: :desktop_ui_rendering_coordinator_layouts
# Key: {component_id, "current"}
# Value: DesktopUI.Layout.t()

:ets.insert(@layouts_table, {{component_id, "current"}, layout})
```

#### Window Bounds Storage

```elixir
# Table: :desktop_ui_rendering_coordinator_metrics
# Key: :window_bounds
# Value: %{width: pos_integer(), height: pos_integer()}

:ets.insert(@metrics_table, {:window_bounds, %{width: 800, height: 600}})
```

### Signal Flow for Layout Integration

```
┌─────────────────────┐
│  Component State    │
│     Change          │
└──────────┬──────────┘
           │ StateChanged signal
           ↓
┌─────────────────────────────────────────────┐
│       RenderingCoordinator                  │
│  1. Look up component                       │
│  2. Call component.view/1 → widget tree     │
│  3. Calculate UI tree version (hash)        │
│  4. Check if UI tree changed                │
│     └─ If unchanged, skip layout?           │
│  5. Layout.calculate(widget, bounds)        │
│  6. Store layout in ETS                     │
│  7. renderer.render(component_id, layout)   │
└─────────────────────────────────────────────┘
           │
           ↓
┌─────────────────────────────────────────────┐
│         Renderer                            │
│  Render using pre-calculated layout         │
└─────────────────────────────────────────────┘
```

### Window Resize Flow

```
┌─────────────────────┐
│   SDL Window        │
│    Resize Event     │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────────────────────────────┐
│         EventLoop                           │
│  1. Detect resize via SDL                   │
│  2. Get new window size                     │
│  3. Publish WindowResized signal            │
└──────────┬──────────────────────────────────┘
           │ WindowResized signal
           ↓
┌─────────────────────────────────────────────┐
│       RenderingCoordinator                  │
│  1. Receive WindowResized signal            │
│  2. Update stored window bounds             │
│  3. Trigger layout recalculation for all    │
│     registered components                   │
│  4. Publish RenderRequest for each          │
└─────────────────────────────────────────────┘
```

## 5. Success Criteria

1. **Layout After view/1**: Coordinator calculates layout after calling component.view/1
2. **Layout Stored**: Layout tree is stored in ETS table after calculation
3. **Hit Test Works**: Runtime can call coordinator.hit_test/2 to find widgets
4. **Window Resize Handler**: WindowResized signals trigger layout recalculation
5. **Skip Unchanged**: Layout is skipped when UI tree version unchanged
6. **Layout Passed to Renderer**: Renderer receives pre-calculated layout
7. **Full Pipeline Works**: Complete flow from state change to layout to render works
8. **Tests Pass**: All unit and integration tests pass

## 6. Implementation Plan

### Task 3.7.1: Update RenderingCoordinator to calculate layout after view/1

**File:** `lib/desktop_ui/rendering_coordinator.ex`

**Changes Required:**
1. Calculate UI tree version after getting widget (simple hash or struct comparison)
2. Store layout in ETS (already done in 3.6)
3. Ensure layout is always calculated before rendering

**Implementation:**
- Add `calculate_ui_tree_version/1` helper function
- Update `render_component/4` to track UI version
- Store version in component info

### Task 3.7.2: Store current layout tree in coordinator state

**Status:** Already implemented in Section 3.6

**Verify Implementation:**
- ETS table `@layouts_table` exists
- Layout is stored with key `{component_id, "current"}`
- `hit_test/3` function retrieves layout from ETS

### Task 3.7.3: Add hit_test/2 function for use by Runtime

**Status:** Already implemented in Section 3.6

**Verify API:**
```elixir
@spec hit_test(String.t(), non_neg_integer(), non_neg_integer()) ::
  {:ok, %{widget_id: atom(), on_click: term()}} | nil
def hit_test(component_id, x, y)
```

### Task 3.7.4: Trigger layout recalculation when UI tree changes

**Implementation:**
- Compare `new_version` with `current_version` from component info
- Recalculate layout only when versions differ
- Store new version in component info

### Task 3.7.5: Trigger layout recalculation on window resize (via signal)

**Add Signal Handler:**
```elixir
@impl true
def handle_info({:signal, %Jido.Signal{type: "desktop_ui.window.resized"} = signal}, state) do
  # Update window bounds and trigger recalculation
end
```

**Add Helper Functions:**
- `trigger_layout_recalculation/0` - Publishes RenderRequest for all components
- `get_available_bounds/0` - Reads window bounds from ETS
- Initialize bounds on startup from opts

### Task 3.7.6: Optimize to skip layout if UI tree unchanged

**Implementation:**
- Use `ui_tree_version` to detect changes
- Reuse cached layout when version unchanged
- Support `force` flag from RenderRequest signal

### Task 3.7.7: Pass layout to renderer for positioning

**Update render_widget_with_layout:**
- Ensure renderer receives layout struct
- Use `Renderer.render(component_id, layout)` call
- Fallback to widget-based rendering for older renderers

## 7. Notes and Considerations

### Edge Cases

1. **No Layout Cache**: First render has no cached layout - must calculate
2. **Window Resize on Startup**: Initial bounds should be set from opts
3. **Multiple Components**: Window resize triggers recalculation for all
4. **Layout Failure**: If layout calculation fails, fall back to widget rendering
5. **Nil Widget Tree**: Should handle gracefully (validation already covers this)

### Performance Considerations

1. **UI Tree Version Calculation**: Using `:erlang.phash2/1` is O(n) but fast
2. **ETS Read/Write**: ETS operations are fast and lock-free for reads
3. **Layout Calculation**: Most expensive operation - caching saves time

## 8. Dependencies

- **Requires:**
  - Section 3.1 (Layout Engine Foundation) - Layout.calculate/3
  - Section 3.2 (VBox Container Layout) - Container layout
  - Section 3.3 (HBox Container Layout) - Container layout
  - Section 3.4 (Widget Size Hints) - Size constraints
  - Section 3.5 (Renderer with Layout) - Renderer accepts layout
  - Section 3.6 (Hit Testing with Layout) - Layout storage and hit_test API

- **Enables:**
  - Section 3.8 (Enhanced Counter Demo) - Working interactive demo
  - Section 3.9 (Phase 3 Integration Tests) - Full system tests

## Task Checklist

- [x] 3.7.1 Update RenderingCoordinator to calculate layout after view/1
- [x] 3.7.2 Store current layout tree in coordinator state (VERIFY from 3.6)
- [x] 3.7.3 Add hit_test/2 function for use by Runtime (VERIFY from 3.6)
- [x] 3.7.4 Trigger layout recalculation when UI tree changes
- [x] 3.7.5 Trigger layout recalculation on window resize (via signal)
- [x] 3.7.6 Optimize to skip layout if UI tree unchanged
- [x] 3.7.7 Pass layout to renderer for positioning

## Implementation Summary

All tasks completed successfully:

1. **Layout After view/1**: The coordinator now calculates layout immediately after calling component.view/1
2. **Layout Storage**: Layouts are stored in ETS table for hit testing and caching
3. **Hit Test API**: The hit_test/3 function from Section 3.6 is verified working
4. **UI Tree Change Detection**: UI tree version tracking via phash2 for change detection
5. **Window Resize Handling**: WindowResized signals update bounds and trigger recalculation
6. **Layout Caching**: Unchanged UI trees reuse cached layouts for performance
7. **Layout to Renderer**: Pre-calculated layouts are passed to renderer via render_with_layout

## Files Modified

### Primary Implementation
- `lib/desktop_ui/rendering_coordinator.ex` (~150 lines added/modified)
  - Window bounds initialization in init/1
  - WindowResized signal handler
  - UI tree version tracking
  - Layout caching and reuse logic
  - render_widget_with_layout/3 with fallback support

### Test Updates
- `test/desktop_ui/rendering_coordinator_test.exs` (~30 lines modified)
  - Updated MockRenderer to support render_with_layout/3
  - Added layout field verification in tests
  - All 14 tests passing

- `test/integration/phase_3_integration_test.exs` (NEW FILE, ~660 lines)
  - 9 comprehensive integration tests
  - Tests for layout calculation, caching, hit testing
  - Window resize handling tests
  - Full pipeline tests
  - All 9 tests passing

### Library Updates
- `lib/desktop_ui/renderer/mock.ex` (~20 lines added)
  - Added render_with_layout/2 and /3 functions
  - Added handle_call for render_with_layout
  - Stores layout in render map for verification
