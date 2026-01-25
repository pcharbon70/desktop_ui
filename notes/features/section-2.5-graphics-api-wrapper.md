# Section 2.5: DesktopUI.Graphics API Wrapper - Feature Planning Document

**Feature Branch:** `feature/section-2.5-graphics-api-wrapper`
**Status:** Pending
**Created:** 2026-01-24
**Planning Document:** `notes/planning/poc/phase-2-graphics-bridge.md`

## Overview

This feature creates a higher-level, more ergonomic Elixir API wrapper around the raw SDL2 NIF functions. The current `DesktopUI.Graphics` module exposes raw NIF functions that require manual renderer management and use low-level color tuples. Section 2.5 will add convenience functions that abstract away renderer lifecycle management and provide a more developer-friendly interface.

**Important Note:** After analyzing the current code, this section is primarily about adding **convenience wrapper functions** to the existing `DesktopUI.Graphics` module, not replacing existing functionality. The raw NIF functions will remain available for advanced use cases, while new wrapper functions will provide a simplified API for common operations.

## Problem Statement

The current `DesktopUI.Graphics` API requires developers to:

1. **Manually manage renderer lifecycle** - Create, track, and destroy renderers for each window
2. **Use low-level color tuples** - Pass `{r, g, b, a}` tuples to every drawing function
3. **Understand renderer/window relationship** - Must know which renderer belongs to which window
4. **Handle boilerplate** - Repeat the same initialization and cleanup code

This creates friction for common use cases where developers just want to:
- Create a window and start drawing
- Use intuitive color specifications (maps, named colors, hex values)
- Let the system manage renderer resources automatically
- Focus on what to draw, not how to manage SDL2 resources

**Example of Current API (Verbose):**
```elixir
# Current approach requires manual renderer management
{:ok, window_id} = DesktopUI.Graphics.create_window("My App", 800, 600)
{:ok, renderer_id} = DesktopUI.Graphics.create_renderer(window_id)
DesktopUI.Graphics.set_render_draw_color(renderer_id, 0, 0, 0, 255)
DesktopUI.Graphics.clear_render(renderer_id)
DesktopUI.Graphics.fill_rect(renderer_id, 10, 10, 100, 50, {255, 0, 0, 255})
DesktopUI.Graphics.present_render(renderer_id)
# Must remember to cleanup:
DesktopUI.Graphics.destroy_renderer(renderer_id)
DesktopUI.Graphics.destroy_window(window_id)
```

**Desired API (Ergonomic):**
```elixir
# New approach with automatic renderer management
{:ok, window_id} = DesktopUI.Graphics.create_window("My App", 800, 600)
DesktopUI.Graphics.clear(window_id, :black)
DesktopUI.Graphics.fill_rect(window_id, 10, 10, 100, 50, :red)
DesktopUI.Graphics.present(window_id)
# Cleanup happens automatically or with single call
DesktopUI.Graphics.destroy_window(window_id)
```

## Solution Overview

We will add **new convenience wrapper functions** to `DesktopUI.Graphics` that:

1. **Automatically manage renderers** - Track window-to-renderer mappings internally
2. **Accept flexible color formats** - Support maps, atoms (named colors), hex strings, and tuples
3. **Simplify common operations** - Combine multi-step operations into single functions
4. **Maintain backward compatibility** - Keep all existing NIF functions available

### Key Design Decisions

#### Decision 1: Automatic Renderer Management
**Question:** Should wrapper functions automatically create/destroy renderers?

**Answer:** **Yes**, for convenience functions:
- First drawing operation on a window auto-creates its renderer
- Renderer is cached per window for subsequent operations
- Renderer is destroyed when window is destroyed

**Rationale:**
- Reduces boilerplate for common use cases
- Most windows only need one renderer anyway
- Advanced users can still use raw NIF functions for multiple renderers per window

#### Decision 2: Color Format Flexibility
**Question:** What color formats should be supported?

**Answer:** Support multiple formats for flexibility:
- **Map:** `%{r: 255, g: 0, b: 0, a: 255}` (most readable)
- **Tuple:** `{255, 0, 0, 255}` (existing format, still supported)
- **Named colors:** `:red`, `:blue`, `:green`, etc. (convenience)
- **Hex string:** `"#FF0000"` (web developer friendly)

**Rationale:**
- Different contexts prefer different formats
- Map format is most Elixir-idiomatic
- Named colors improve code readability
- Hex strings familiar to web developers

#### Decision 3: Function Naming
**Question:** Should we rename functions or add new ones?

**Answer:** **Add new functions** with different signatures:
- Keep `clear_render/1`, `draw_rect/6`, `fill_rect/6` (existing, take renderer_id)
- Add `clear/2`, `draw_rect/6`, `fill_rect/6` (new, take window_id and flexible colors)
- Add `present/1` as alias for `present_render/1` with window_id

**Rationale:**
- Maintains backward compatibility
- Allows gradual migration
- Clear distinction between low-level and high-level API
- Function overloading by arity prevents confusion

#### Decision 4: State Management Approach
**Question:** How should we track window-to-renderer mappings?

**Answer:** Use an ETS table for process-independent state:
- ETS table `:desktop_ui_renderers` stores `{window_id, renderer_id}` mappings
- Public functions check ETS table before creating new renderer
- Table is created on module initialization and cleaned up on application stop

**Rationale:**
- ETS is process-independent (survives process crashes)
- Allows multiple processes to share renderer references
- Fast lookups for common operations
- No need for GenServer overhead (simpler architecture)

**Alternative Considered:** GenServer-based registry
- **Pros:** More explicit lifecycle management
- **Cons:** Single point of contention, more complex
- **Decision:** ETS is sufficient for this use case

## Technical Details

### Module Structure

```
DesktopUI.Graphics (enhanced)
├── NIF Functions (existing)
│   ├── nif_create_window/4
│   ├── nif_destroy_window/1
│   ├── nif_create_renderer/1
│   ├── nif_destroy_renderer/1
│   ├── nif_set_render_draw_color/5
│   ├── nif_clear_render/1
│   ├── nif_draw_rect/6
│   ├── nif_fill_rect/6
│   └── nif_present_render/1
│
├── Public API (existing)
│   ├── create_window/4
│   ├── destroy_window/1
│   ├── create_renderer/1
│   ├── destroy_renderer/1
│   ├── set_render_draw_color/5
│   ├── clear_render/1
│   ├── draw_rect/6
│   ├── fill_rect/6
│   └── present_render/1
│
├── Convenience Wrapper Functions (NEW)
│   ├── init/0 (alias for sdl_init/0)
│   ├── clear/2 (window_id, color)
│   ├── draw_rect/6 (window_id, x, y, w, h, color)
│   ├── fill_rect/6 (window_id, x, y, w, h, color)
│   ├── present/1 (window_id)
│   └── destroy_window/1 (enhanced to cleanup renderer)
│
└── Helper Functions (NEW)
    ├── ensure_renderer/1 (auto-create renderer for window)
    ├── normalize_color/1 (convert any color format to RGBA tuple)
    ├── get_renderer_for_window/1 (lookup in ETS)
    ├── cache_renderer/2 (store mapping in ETS)
    ├── remove_renderer_cache/1 (cleanup mapping)
    └── named_color_to_rgba/1 (convert :red, :blue, etc.)
```

### File Structure

```
desktop_ui/
├── lib/desktop_ui/
│   └── graphics.ex              # Enhanced with wrapper functions
├── test/desktop_ui/
│   └── graphics_test.exs        # Extended with wrapper tests
└── notes/features/
    └── section-2.5-graphics-api-wrapper.md  # This document
```

### Color Format Implementation

```elixir
# Color normalization function (private)
defp normalize_color(color) when is_map(color) do
  # %{r: 255, g: 0, b: 0, a: 255}
  {color.r, color.g, color.b, color.a}
end

defp normalize_color(color) when is_tuple(color) do
  # {255, 0, 0, 255} - already normalized
  color
end

defp normalize_color(color) when is_atom(color) do
  # :red, :blue, :green, etc.
  named_color_to_rgba(color)
end

defp normalize_color(color) when is_binary(color) do
  # "#FF0000" or "#FF0000FF"
  parse_hex_color(color)
end

# Named colors (subset of CSS colors)
@named_colors %{
  black: {0, 0, 0, 255},
  white: {255, 255, 255, 255},
  red: {255, 0, 0, 255},
  green: {0, 255, 0, 255},
  blue: {0, 0, 255, 255},
  yellow: {255, 255, 0, 255},
  cyan: {0, 255, 255, 255},
  magenta: {255, 0, 255, 255},
  transparent: {0, 0, 0, 0},
  gray: {128, 128, 128, 255},
  dark_gray: {64, 64, 64, 255},
  light_gray: {192, 192, 192, 255}
}
```

### Renderer Cache Implementation

```elixir
# Module attributes for ETS table
@renderer_table :desktop_ui_renderers

# Initialize ETS table on module load (in load_nif callback)
defp init_renderer_cache do
  try do
    :ets.new(@renderer_table, [:named_table, :public, :set])
    :ok
  rescue
    ArgumentError -> :already_exists  # Table already created
  end
end

# Get renderer for window (auto-create if needed)
defp ensure_renderer(window_id) do
  case get_renderer_for_window(window_id) do
    {:ok, renderer_id} ->
      {:ok, renderer_id}

    :error ->
      # Auto-create renderer
      case create_renderer(window_id) do
        {:ok, renderer_id} ->
          cache_renderer(window_id, renderer_id)
          {:ok, renderer_id}

        {:error, reason} ->
          {:error, reason}
      end
  end
end

# Lookup in ETS
defp get_renderer_for_window(window_id) do
  case :ets.lookup(@renderer_table, window_id) do
    [{^window_id, renderer_id}] -> {:ok, renderer_id}
    [] -> :error
  end
end

# Store in ETS
defp cache_renderer(window_id, renderer_id) do
  :ets.insert(@renderer_table, {window_id, renderer_id})
  :ok
end

# Remove from ETS (called on window destroy)
defp remove_renderer_cache(window_id) do
  case get_renderer_for_window(window_id) do
    {:ok, renderer_id} ->
      :ets.delete(@renderer_table, window_id)
      destroy_renderer(renderer_id)
      :ok

    :error ->
      :ok
  end
end
```

### Enhanced destroy_window Implementation

```elixir
# Enhanced destroy_window to auto-cleanup renderer
def destroy_window(window_id) when is_integer(window_id) do
  # Cleanup renderer cache first
  remove_renderer_cache(window_id)

  # Then destroy window
  nif_destroy_window(window_id)
end
```

## Implementation Tasks

### Task 2.5.1: Create init/0 wrapper
**Status:** Pending
**Description:** Create `init/0` as ergonomic alias for `sdl_init/0`
**Files:** `lib/desktop_ui/graphics.ex` (modify)
**Function Signature:**
```elixir
@spec init() :: {:ok, map()} | {:error, String.t()}
def init, do: sdl_init()
```

### Task 2.5.2: Implement color normalization
**Status:** Pending
**Description:** Create `normalize_color/1` to handle multiple color formats
**Files:** `lib/desktop_ui/graphics.ex` (modify)
**Functions:**
- `normalize_color/1` - Main dispatcher
- `named_color_to_rgba/1` - Convert atoms to RGBA tuples
- `parse_hex_color/1` - Parse hex strings like "#FF0000"
- Define `@named_colors` module attribute with common colors

**Supported Formats:**
- Map: `%{r: 255, g: 0, b: 0, a: 255}`
- Tuple: `{255, 0, 0, 255}` (pass-through)
- Atom: `:red`, `:blue`, `:green`, etc.
- Binary: `"#FF0000"` or `"#FF0000FF"`

### Task 2.5.3: Implement renderer cache infrastructure
**Status:** Pending
**Description:** Create ETS table and helper functions for renderer management
**Files:** `lib/desktop_ui/graphics.ex` (modify)
**Functions:**
- `init_renderer_cache/0` - Create ETS table (called in load_nif)
- `ensure_renderer/1` - Get or create renderer for window
- `get_renderer_for_window/1` - Lookup renderer in ETS
- `cache_renderer/2` - Store window-to-renderer mapping
- `remove_renderer_cache/1` - Cleanup renderer and remove from ETS

**ETS Table:**
- Name: `:desktop_ui_renderers`
- Type: `:set`
- Access: `:public` (allow cross-process access)

### Task 2.5.4: Implement clear/2 wrapper
**Status:** Pending
**Description:** Create `clear/2` that takes window_id and flexible color
**Files:** `lib/desktop_ui/graphics.ex` (modify)
**Function Signature:**
```elixir
@spec clear(non_neg_integer(), color()) :: :ok | {:error, String.t()}
      when color: %{r: 0..255, g: 0..255, b: 0..255, a: 0..255} |
                    {0..255, 0..255, 0..255, 0..255} |
                    atom() |
                    String.t()
def clear(window_id, color) do
  with {:ok, renderer_id} <- ensure_renderer(window_id),
       {r, g, b, a} = normalize_color(color),
       :ok <- set_render_draw_color(renderer_id, r, g, b, a),
       do: clear_render(renderer_id)
end
```

### Task 2.5.5: Implement draw_rect/6 wrapper
**Status:** Pending
**Description:** Create `draw_rect/6` that takes window_id and flexible color
**Files:** `lib/desktop_ui/graphics.ex` (modify)
**Function Signature:**
```elixir
@spec draw_rect(non_neg_integer(), integer(), integer(), integer(), integer(), color()) ::
        :ok | {:error, String.t()}
def draw_rect(window_id, x, y, w, h, color) do
  with {:ok, renderer_id} <- ensure_renderer(window_id),
       {r, g, b, a} = normalize_color(color),
       do: nif_draw_rect(renderer_id, x, y, w, h, {r, g, b, a})
end
```

### Task 2.5.6: Implement fill_rect/6 wrapper
**Status:** Pending
**Description:** Create `fill_rect/6` that takes window_id and flexible color
**Files:** `lib/desktop_ui/graphics.ex` (modify)
**Function Signature:**
```elixir
@spec fill_rect(non_neg_integer(), integer(), integer(), integer(), integer(), color()) ::
        :ok | {:error, String.t()}
def fill_rect(window_id, x, y, w, h, color) do
  with {:ok, renderer_id} <- ensure_renderer(window_id),
       {r, g, b, a} = normalize_color(color),
       do: nif_fill_rect(renderer_id, x, y, w, h, {r, g, b, a})
end
```

### Task 2.5.7: Implement present/1 wrapper
**Status:** Pending
**Description:** Create `present/1` that takes window_id instead of renderer_id
**Files:** `lib/desktop_ui/graphics.ex` (modify)
**Function Signature:**
```elixir
@spec present(non_neg_integer()) :: :ok | {:error, String.t()}
def present(window_id) do
  with {:ok, renderer_id} <- ensure_renderer(window_id),
       do: present_render(renderer_id)
end
```

### Task 2.5.8: Enhance destroy_window/1
**Status:** Pending
**Description:** Modify `destroy_window/1` to auto-cleanup renderer cache
**Files:** `lib/desktop_ui/graphics.ex` (modify)
**Implementation:** Add call to `remove_renderer_cache/1` before destroying window

### Task 2.5.9: Add error handling and logging
**Status:** Pending
**Description:** Enhance error messages and add appropriate logging
**Files:** `lib/desktop_ui/graphics.ex` (modify)
**Implementation:**
- Add descriptive error messages for color format errors
- Add warnings for deprecated operations (if any)
- Add `@doc` documentation examples for new functions
- Document thread safety guarantees

## Testing Strategy

### Unit Tests (9 tests required)

1. **Test init/0** - Verify init calls sdl_init correctly
2. **Test color normalization with map** - Verify `%{r: 255, g: 0, b: 0, a: 255}` converts correctly
3. **Test color normalization with tuple** - Verify tuple passes through unchanged
4. **Test color normalization with atom** - Verify `:red`, `:blue`, etc. convert correctly
5. **Test color normalization with hex** - Verify `"#FF0000"` parses correctly
6. **Test renderer cache** - Verify renderer is created and cached
7. **Test clear/2 with flexible colors** - Verify clear works with all color formats
8. **Test draw/fill_rect wrappers** - Verify wrappers use cached renderer
9. **Test present/1 wrapper** - Verify present uses cached renderer

### Integration Tests (using existing SDL2 tests)

The existing integration tests already cover the underlying NIF functions. The new wrapper functions will be tested by:

1. **Test full rendering lifecycle with wrappers** - Use only new wrapper functions
2. **Test automatic renderer creation** - Verify renderer created on first draw
3. **Test renderer cleanup** - Verify renderer destroyed when window destroyed
4. **Test multiple windows with wrappers** - Verify each window gets separate renderer
5. **Test error propagation** - Verify errors from NIF propagate correctly

### Manual Testing Checklist

- [ ] Create window and draw with named colors
- [ ] Create window and draw with hex colors
- [ ] Create window and draw with map colors
- [ ] Verify automatic renderer creation works
- [ ] Verify renderer cleanup on window destroy
- [ ] Test error messages for invalid color formats

## Success Criteria

1. ✅ All 9 new wrapper functions implemented
2. ✅ Color normalization supports 4 formats (map, tuple, atom, hex)
3. ✅ Renderer cache uses ETS table
4. ✅ Automatic renderer creation works transparently
5. ✅ Automatic renderer cleanup happens on window destroy
6. ✅ All existing tests still pass (backward compatibility)
7. ✅ All new tests pass (9 unit tests)
8. ✅ No compiler warnings
9. ✅ Documentation examples for all new functions
10. ✅ Thread-safe renderer cache access

## API Comparison

### Before (Current API)

```elixir
# Requires manual renderer management
{:ok, window_id} = DesktopUI.Graphics.create_window("Demo", 800, 600)
{:ok, renderer_id} = DesktopUI.Graphics.create_renderer(window_id)

# Must use tuple colors
DesktopUI.Graphics.set_render_draw_color(renderer_id, 0, 0, 0, 255)
DesktopUI.Graphics.clear_render(renderer_id)

DesktopUI.Graphics.fill_rect(renderer_id, 10, 10, 100, 50, {255, 0, 0, 255})
DesktopUI.Graphics.draw_rect(renderer_id, 120, 10, 100, 50, {0, 255, 0, 255})

DesktopUI.Graphics.present_render(renderer_id)

# Manual cleanup
DesktopUI.Graphics.destroy_renderer(renderer_id)
DesktopUI.Graphics.destroy_window(window_id)
```

### After (New Wrapper API)

```elixir
# Automatic renderer management
{:ok, window_id} = DesktopUI.Graphics.create_window("Demo", 800, 600)

# Can use named colors, hex, maps, or tuples
DesktopUI.Graphics.clear(window_id, :black)
DesktopUI.Graphics.fill_rect(window_id, 10, 10, 100, 50, :red)
DesktopUI.Graphics.draw_rect(window_id, 120, 10, 100, 50, "#00FF00")
DesktopUI.Graphics.fill_rect(window_id, 230, 10, 100, 50, %{r: 0, g: 0, b: 255, a: 255})

DesktopUI.Graphics.present(window_id)

# Single cleanup (renderer destroyed automatically)
DesktopUI.Graphics.destroy_window(window_id)
```

## Migration Guide

### For Existing Code

**No breaking changes!** All existing code continues to work:

```elixir
# This still works exactly as before
{:ok, window_id} = DesktopUI.Graphics.create_window("App", 800, 600)
{:ok, renderer_id} = DesktopUI.Graphics.create_renderer(window_id)
DesktopUI.Graphics.fill_rect(renderer_id, 10, 10, 100, 50, {255, 0, 0, 255})
DesktopUI.Graphics.present_render(renderer_id)
```

### For New Code

Developers can choose to use the new convenience API:

```elixir
# New simpler approach
{:ok, window_id} = DesktopUI.Graphics.create_window("App", 800, 600)
DesktopUI.Graphics.fill_rect(window_id, 10, 10, 100, 50, :red)
DesktopUI.Graphics.present(window_id)
```

### Gradual Migration

Existing code can be updated incrementally:

```elixir
# Step 1: Keep renderer creation, use new color formats
{:ok, renderer_id} = DesktopUI.Graphics.create_renderer(window_id)
DesktopUI.Graphics.fill_rect(renderer_id, 10, 10, 100, 50, :red)  # New color format!

# Step 2: Switch to window-based API
DesktopUI.Graphics.fill_rect(window_id, 10, 10, 100, 50, :red)  # Auto-manages renderer
```

## Progress

### 2026-01-24
- [x] Analyzed current Graphics module implementation
- [x] Reviewed existing tests (298 tests passing)
- [x] Created feature planning document
- [ ] Implementation pending approval

## Notes/Considerations

### Risk Assessment

**High Risk Items:**
- ETS table lifecycle management (must be cleaned up on app shutdown)
- Thread safety of renderer cache (concurrent access to ETS table)

**Medium Risk Items:**
- Color format parsing errors (invalid hex strings, unknown atoms)
- Memory leaks if renderers not properly cleaned up

**Low Risk Items:**
- Wrapper function implementation (straightforward delegation)
- Backward compatibility (existing functions unchanged)

### Platform Support

**Primary:** Linux (Ubuntu/Debian with `libsdl2-dev`)
- X11 window system
- Wayland window system

**Secondary:** macOS (with SDL2 via Homebrew)
- Cocoa window system

**Future:** Windows (requires different build approach)
- Win32 API

### Thread Safety

**ETS Table Access:**
- ETS tables are thread-safe by design
- Concurrent reads and writes are safe
- No need for additional locking

**Renderer Lifecycle:**
- Renderers are owned by the SDL2 library (not Elixir processes)
- Renderer references can be shared across processes
- Must ensure renderer is not destroyed while in use

**Recommendation:** Document that renderers should not be accessed after their window is destroyed, even from other processes.

### Performance Considerations

**ETS Lookups:**
- O(1) lookup time for renderer cache
- Minimal overhead compared to SDL2 operations
- Negligible performance impact

**Color Normalization:**
- Pattern matching is fast (O(1) dispatch)
- Hex parsing has minimal cost (only for hex strings)
- Named color lookup is O(1) map lookup

**Memory:**
- ETS table stores one entry per window (typically 1-10 entries)
- Memory overhead is negligible (< 1KB per window)

### Future Enhancements (Out of Scope for 2.5)

**Potential future improvements:**
1. **Context-based API** - Use a process-based context to manage window state
2. **Color gradients** - Support gradient fills
3. **Clipping regions** - Add clipping support for partial redraws
4. **Double buffering** - Automatic double buffering for smooth animations
5. **Sprite/texture support** - Add image rendering (planned for Phase 3)

**Why out of scope:**
- Section 2.5 is about API ergonomics, not new graphics features
- Advanced features should be added in Phase 3 or later
- Keep changes minimal and focused for this section

### Documentation Requirements

All new functions must have:
1. **@moduledoc** - Update module documentation to include wrapper API examples
2. **@spec** - Type specs for all public functions
3. **@doc** - Documentation with examples for each function
4. **Color format examples** - Show all supported color formats in documentation

## References

- Planning document: `notes/planning/poc/phase-2-graphics-bridge.md`
- Section 2.1 summary: `notes/summaries/section-2.1-c-nif-foundation.md`
- Section 2.2 summary: `notes/summaries/section-2.2-sdl2-window-management.md`
- Section 2.3 summary: `notes/summaries/section-2.3-renderer-drawing-primitives.md`
- Section 2.4 summary: `notes/summaries/section-2.4-event-polling-translation.md`
- Current implementation: `lib/desktop_ui/graphics.ex`
- Current tests: `test/desktop_ui/graphics_test.exs`
- SDL2 documentation: https://wiki.libsdl.org/
- Erlang ETS documentation: http://erlang.org/doc/man/ets.html
- Branch: `feature/section-2.5-graphics-api-wrapper`
- Target branch: `poc`

## Questions for Developer

1. **Renderer cache scope:** Should renderer cache be per-process or global?
   - **Recommendation:** Global (ETS) for cross-process access

2. **Named color palette:** How many named colors should we support?
   - **Recommendation:** Start with 12 basic colors (CSS subset)

3. **Hex format support:** Should we support both `#RGB` and `#RGBA`?
   - **Recommendation:** Yes, both formats (with alpha defaulting to 255)

4. **Error handling:** Should wrapper functions raise exceptions or return errors?
   - **Recommendation:** Return `{:error, reason}` tuples (consistent with NIF API)

5. **Deprecation warnings:** Should we warn users about the old API?
   - **Recommendation:** No warnings, both APIs are valid for different use cases

6. **Performance monitoring:** Should we add telemetry/benchmarking?
   - **Recommendation:** No, keep it simple for now (add in Phase 3 if needed)

7. **Documentation format:** Should we use literate programming or separate docs?
   - **Recommendation:** Standard ExUnit documentation in @doc attributes
