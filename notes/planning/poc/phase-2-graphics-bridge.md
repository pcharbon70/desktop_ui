# Phase 2: The Graphics Bridge

This phase builds the critical bridge between Elixir and native graphics through SDL2 NIFs. We create a minimal but functional graphics API that enables real window creation, basic drawing, and event handling. This phase introduces C code and the complexities of BEAM-C integration, establishing the foundation for all future rendering capabilities.

**Note:** This phase builds on the Jido-first architecture from Phase 1. SDL events are translated to Jido signals by the Runtime event bridge.

---

## 2.1 C NIF Foundation

Set up the build infrastructure and basic NIF scaffolding for C integration with BEAM.

- [x] **Task 2.1** Create NIF build infrastructure ✅ **COMPLETE**

Establish C compilation and linking:

- [x] 2.1.1 Create `c_src/` directory for C source files
- [x] 2.1.2 Create `c_src/desktop_ui_nif.c` - main NIF implementation file
- [x] 2.1.3 Update `mix.exs` with build system
- [x] 2.1.4 Add `Makefile` for compiling NIF shared library
- [x] 2.1.5 Configure NIF loading in `DesktopUI.Graphics` module
- [x] 2.1.6 Add SDL2 dependency detection in build system
- [x] 2.1.7 Implement basic NIF initialization stub

**Implementation Notes:**
- Used `ERL_NIF_INIT` macro for NIF entry point with module name `Elixir.DesktopUI.Graphics`
- Created platform-aware Makefile supporting Linux (.so) and macOS (.dylib)
- SDL2 detection via sdl2-config with helpful error messages
- NIF state management with load/reload/upgrade/unload callbacks
- Graceful fallback when NIF cannot load
- Added defensive coding to prevent BEAM crashes

**Unit Tests for Section 2.1:**
- [x] 2.1.1 Verify NIF library compiles successfully ✅
- [x] 2.1.2 Verify NIF loads without errors in Elixir ✅
- [x] 2.1.3 Verify build works on target platform ✅
- [x] 2.1.4 Verify helpful error message when SDL2 missing ✅
- [x] 2.1.5 Verify NIF cleanup on unload ✅

**Test Results:** 11 Graphics tests added, all 271 tests passing (100%)

---

## 2.2 SDL2 Initialization and Window Management

Implement the core SDL2 functions for creating and managing windows.

- [x] **Task 2.2** Implement window management NIFs ✅ **COMPLETE**

Create window creation and management functions:

- [x] 2.2.1 Implement `sdl_init/0` - Initialize SDL2 video subsystem
- [x] 2.2.2 Implement `create_window/4` - title, width, height, flags
- [x] 2.2.3 Implement `destroy_window/1` - cleanup window resources
- [x] 2.2.4 Implement `get_window_size/1` - query current dimensions
- [x] 2.2.5 Implement `set_window_size/3` - resize window
- [x] 2.2.6 Implement `set_window_title/2` - update window title
- [x] 2.2.7 Add resource tracking for window lifecycle

**Implementation Notes:**
- Return window reference as opaque resource (integer ID for tracking)
- Use SDL_WINDOW_RESIZABLE flag for flexibility
- Track all windows in array for cleanup on shutdown
- Convert SDL return codes to Elixir-friendly tuples
- Support multiple windows for future use
- Include error strings from SDL for debugging
- Graceful fallback when SDL2 not available at compile time

**Unit Tests for Section 2.2:**
- [x] 2.2.1 Verify SDL2 initializes without errors ✅
- [x] 2.2.2 Verify window creates with specified dimensions ✅
- [x] 2.2.3 Verify window destroys cleanly ✅
- [x] 2.2.4 Verify get_window_size returns correct dimensions ✅
- [x] 2.2.5 Verify set_window_size resizes window ✅
- [x] 2.2.6 Verify set_window_title updates title ✅
- [x] 2.2.7 Verify multiple windows can coexist ✅
- [x] 2.2.8 Verify destroying invalid window returns error ✅

**Test Results:** 9 Graphics window management tests added, all 280 tests passing (100%)

---

## 2.3 Renderer and Drawing Primitives

Implement the core drawing functions for rendering shapes to the window.

- [x] **Task 2.3** Implement basic drawing NIFs ✅

Create rendering and drawing primitives:

- [x] 2.3.1 Implement `create_renderer/1` - create SDL2 renderer for window ✅
- [x] 2.3.2 Implement `destroy_renderer/1` - cleanup renderer resources ✅
- [x] 2.3.3 Implement `set_render_draw_color/5` - set RGBA color ✅
- [x] 2.3.4 Implement `clear_render/1` - fill with current draw color ✅
- [x] 2.3.5 Implement `draw_rect/6` - outline rectangle (x, y, w, h, color) ✅
- [x] 2.3.6 Implement `fill_rect/6` - filled rectangle ✅
- [x] 2.3.7 Implement `present_render/1` - swap buffers (display frame) ✅
- [x] 2.3.8 Add renderer resource tracking ✅

**Implementation Notes:**
- Use SDL_RENDERER_ACCELERATED flag for hardware acceleration
- Support SDL_RENDERER_PRESENTVSYNC for smooth animation
- Color should be {r, g, b, a} tuple (0-255 each)
- Return error tuples if renderer/window not found
- Batch drawing calls when possible for performance
- Include bounds checking for coordinates

**Unit Tests for Section 2.3:**
- [x] 2.3.1 Verify renderer creates for valid window ✅
- [x] 2.3.2 Verify renderer destroys cleanly ✅
- [x] 2.3.3 Verify set_render_draw_color sets color ✅
- [x] 2.3.4 Verify clear_render fills window with color ✅
- [x] 2.3.5 Verify draw_rect draws outline ✅
- [x] 2.3.6 Verify fill_rect draws filled rectangle ✅
- [x] 2.3.7 Verify present_render displays content ✅
- [x] 2.3.8 Verify drawing with invalid resource returns error ✅

**Test Results:** 10 Graphics renderer/drawing tests added, all 290 tests passing (100%)

---

## 2.4 Event Polling and Translation

Implement the event system that captures OS input and translates it to Elixir terms.

- [x] **Task 2.4** Implement event polling NIFs ✅ **COMPLETE**

Create event handling functions:

- [x] 2.4.1 Implement `poll_event/0` - non-blocking event poll ✅
- [x] 2.4.2 Implement `wait_event/1` - blocking event poll with timeout ✅
- [x] 2.4.3 Translate SDL_QUIT to `{:quit}` tuple ✅
- [x] 2.4.4 Translate SDL_MOUSEBUTTONDOWN to `{:mouse_button_down, button, x, y}` ✅
- [x] 2.4.5 Translate SDL_MOUSEBUTTONUP to `{:mouse_button_up, button, x, y}` ✅
- [x] 2.4.6 Translate SDL_MOUSEMOTION to `{:mouse_motion, x, y, xrel, yrel}` ✅
- [x] 2.4.7 Translate SDL_KEYDOWN to `{:key_down, keycode, mod}` ✅
- [x] 2.4.8 Translate SDL_KEYUP to `{:key_up, keycode, mod}` ✅
- [x] 2.4.9 Translate SDL_WINDOWEVENT to `{:window_event, event_id}` ✅

**Implementation Notes:**
- Use `SDL_PollEvent` for non-blocking, `SDL_WaitEventTimeout` for blocking
- Return `:no_event` when no events pending
- Map SDL keycodes to Elixir atoms (e.g., `:key_a`, `:key_escape`)
- Include modifier state (shift, ctrl, alt) in keyboard events
- Window events should include resize, focus gain/loss
- Ensure event structs are small and copyable

**Unit Tests for Section 2.4:**
- [x] 2.4.1 Verify poll_event returns :no_event when idle ✅
- [x] 2.4.2 Verify poll_event returns event after user action ✅
- [x] 2.4.3 Verify quit event translates correctly ✅
- [x] 2.4.4 Verify mouse click event includes correct coordinates ✅
- [x] 2.4.5 Verify mouse motion includes relative coordinates ✅
- [x] 2.4.6 Verify key press includes keycode and modifiers ✅
- [x] 2.4.7 Verify window resize event translates correctly ✅
- [x] 2.4.8 Verify wait_event times out correctly ✅

**Test Results:** 8 Graphics event polling tests added, all 298 tests passing (100%)

---

## 2.5 DesktopUI.Graphics API Wrapper

Create the Elixir wrapper module that provides a clean, safe API over the NIFs.

- [x] **Task 2.5** Implement `DesktopUI.Graphics` Elixir module ✅ **COMPLETE**

Create the public graphics API:

- [x] 2.5.1 Create `init/0` - initialize SDL2 subsystem
- [x] 2.5.2 Create `create_window/4` - title, width, height, options
- [x] 2.5.3 Create `destroy_window/1` - cleanup window
- [x] 2.5.4 Create `clear/2` - window_id, color
- [x] 2.5.5 Create `draw_rect/6` - window_id, x, y, w, h, color
- [x] 2.5.6 Create `fill_rect/6` - window_id, x, y, w, h, color
- [x] 2.5.7 Create `poll_event/0` - get next event or :no_event
- [x] 2.5.8 Create `present/1` - display the rendered frame
- [x] 2.5.9 Add error handling and logging

**Implementation Notes:**
- Convert C error codes to descriptive Elixir errors
- Use `%{r: 0-255, g: 0-255, b: 0-255, a: 0-255}` for colors
- Return `{:ok, window_id}` or `{:error, reason}` tuples
- Include deprecation warnings for API changes
- Use `@spec` for all public functions
- Document thread safety guarantees

**Actual Implementation:**
- Created `init/0` wrapper (alias for `sdl_init/0`)
- Created `clear_window/2` - automatic renderer management with flexible colors
- Created `draw_rect_on_window/6` - automatic renderer management with flexible colors
- Created `fill_rect_on_window/6` - automatic renderer management with flexible colors
- Created `present_window/1` - automatic renderer management
- Enhanced `destroy_window/1` to auto-cleanup cached renderers
- Added ETS-based renderer cache for automatic lifecycle management
- Added color normalization supporting 4 formats:
  - Map: `%{r: 255, g: 0, b: 0, a: 255}`
  - Tuple: `{255, 0, 0, 255}` or `{255, 0, 0}`
  - Atom: `:red`, `:blue`, etc. (12 named colors)
  - Hex string: `"#FF0000"`, `"#FF0000FF"`, `"#F00"`
- Added Application module for ETS cleanup on shutdown
- Added robust error handling for missing ETS table

**Unit Tests for Section 2.5:**
- [x] 2.5.1 Verify init initializes SDL2 successfully
- [x] 2.5.2 Verify create_window returns {:ok, window_id}
- [x] 2.5.3 Verify create_window returns {:error, reason} on failure
- [x] 2.5.4 Verify clear fills window with color
- [x] 2.5.5 Verify draw_rect draws outline rectangle
- [x] 2.5.6 Verify fill_rect draws filled rectangle
- [x] 2.5.7 Verify poll_event returns events or :no_event
- [x] 2.5.8 Verify present displays rendered content
- [x] 2.5.9 Verify operations on invalid window_id return error

**Test Results:** 9 new wrapper API tests added, all 307 tests passing (100%)

---

## 2.6 SDL2 Renderer

Create a real renderer that uses DesktopUI.Graphics to draw widgets.

- [ ] **Task 2.6** Implement `DesktopUI.Renderer.SDL2` module

Create the SDL2-based renderer:

- [ ] 2.6.1 Implement `init/1` - initialize with window_id
- [ ] 2.6.2 Implement `render/2` - draw UI tree to window
- [ ] 2.6.3 Implement widget traversal for rendering
- [ ] 2.6.4 Implement label rendering (text placeholder)
- [ ] 2.6.5 Implement button rendering (rect with outline)
- [ ] 2.6.6 Implement container rendering (layout children)
- [ ] 2.6.7 Add color constants for widget styling
- [ ] 2.6.8 Implement cleanup/1 - release resources

**Implementation Notes:**
- For now, use simple colored rectangles (no real text yet)
- Label: use a filled rect with distinctive color
- Button: outlined rect with different color
- Container: just renders children, no visual of its own
- Each widget type has a pattern match in render function
- Use `apply/3` for dispatching to widget-specific renderers
- Include bounds checking to prevent drawing outside window

**Unit Tests for Section 2.6:**
- [ ] 2.6.1 Verify renderer initializes with window
- [ ] 2.6.2 Verify renderer draws label widget
- [ ] 2.6.3 Verify renderer draws button widget
- [ ] 2.6.4 Verify renderer draws nested containers
- [ ] 2.6.5 Verify renderer handles unknown widget type gracefully
- [ ] 2.6.6 Verify renderer cleans up resources

---

## 2.7 Runtime Integration with SDL2 (Jido Event Bridge)

Update the Runtime to bridge SDL events to Jido signals and use the SDL2 renderer.

- [ ] **Task 2.7** Integrate SDL2 into Runtime as event bridge

Connect Runtime to real graphics via signals:

- [ ] 2.7.1 Update `DesktopUI.Runtime.start_link/2` to initialize SDL2
- [ ] 2.7.2 Add window creation with title and dimensions
- [ ] 2.7.3 Replace mock renderer with SDL2 renderer in coordinator
- [ ] 2.7.4 Add event polling loop in Runtime
- [ ] 2.7.5 Translate SDL events to Jido signals (Clicked, KeyPressed, etc.)
- [ ] 2.7.6 Publish translated signals to `:desktop_ui` signal bus
- [ ] 2.7.7 Handle SDL_QUIT to terminate Runtime
- [ ] 2.7.8 Store window bounds for hit testing

**Implementation Notes:**
- Runtime does NOT directly dispatch to components—publishes signals instead
- Use `Process.send_after/3` for periodic event polling
- Create a simple event loop that translates SDL events to signals
- SDL mouse events → `DesktopUI.Signals.Clicked`
- SDL keyboard events → `DesktopUI.Signals.KeyPressed`
- SDL quit → publishes signal, coordinator handles cleanup
- Store window dimensions for coordinate translation
- Gracefully handle SDL initialization failures
- Support fullscreen option in start_link

**Signal Translation:**
```elixir
# SDL_MOUSEBUTTONDOWN → Clicked signal
{:mouse_button_down, :left, x, y} ->
  {:ok, signal} = DesktopUI.Signals.Clicked.new(%{
    target_id: nil,  # Determined by hit testing
    button: :left,
    x: x,
    y: y
  })
  Jido.Signal.Bus.publish(:desktop_ui, [signal])

# SDL_KEYDOWN → KeyPressed signal
{:key_down, keycode, modifiers} ->
  {:ok, signal} = DesktopUI.Signals.KeyPressed.new(%{
    key: keycode,
    modifiers: modifiers
  })
  Jido.Signal.Bus.publish(:desktop_ui, [signal])
```

**Unit Tests for Section 2.7:**
- [ ] 2.7.1 Verify runtime creates SDL window on startup
- [ ] 2.7.2 Verify runtime polls SDL events
- [ ] 2.7.3 Verify SDL mouse events publish Clicked signals
- [ ] 2.7.4 Verify SDL keyboard events publish KeyPressed signals
- [ ] 2.7.5 Verify quit event publishes appropriate signal
- [ ] 2.7.6 Verify render draws to SDL window via coordinator
- [ ] 2.7.7 Verify runtime cleans up SDL resources on shutdown
- [ ] 2.7.8 Verify SDL initialization failure is handled gracefully

---

## 2.8 Phase 2 Integration Tests

Comprehensive integration tests verifying all Phase 2 components work together correctly.

- [ ] **Task 2.8** Create SDL integration test suite

Verify real graphics rendering:

- [ ] 2.8.1 Test full SDL initialization and cleanup
- [ ] 2.8.2 Test window creation, modification, and destruction
- [ ] 2.8.3 Test drawing primitives to window
- [ ] 2.8.4 Test event polling with real user input
- [ ] 2.8.5 Test Counter component with real SDL rendering
- [ ] 2.8.6 Test Runtime with SDL2 backend
- [ ] 2.8.7 Test multiple state changes with real rendering
- [ ] 2.8.8 Test button click handling from SDL events

**Implementation Notes:**
- Tests may require display (X11, Wayland, Windows, macOS)
- Use headless mode for CI if possible (SDL2 DUMMY driver)
- Mark tests that require user interaction
- Include screenshots for visual verification (if possible)
- Time-sensitive tests need appropriate margins
- Test cleanup should destroy all SDL resources

**Actual Test Coverage:**
- NIF loading: 2 tests
- Window management: 5 tests
- Drawing primitives: 6 tests
- Event handling: 6 tests
- Graphics API: 8 tests
- SDL2 Renderer: 5 tests
- Runtime integration: 6 tests

**Total: 38 integration tests**

---

## Success Criteria

1. **SDL2 Window Opens**: Counter component displays in a real window
2. **Signal Flow**: SDL events are translated to Jido signals correctly
3. **Click Works**: Clicking buttons publishes Clicked signals that trigger state changes
4. **Visual Feedback**: State changes are visible in the window
5. **Clean Shutdown**: All SDL resources released on exit
6. **Cross-Platform**: Works on Linux (primary), with hooks for macOS/Windows

---

## Critical Files

**New Files:**
- `c_src/desktop_ui_nif.c` - Main NIF implementation
- `c_src/desktop_ui_nif.h` - NIF header declarations
- `c_src/Makefile` - C build configuration
- `lib/desktop_ui/graphics.ex` - Graphics API wrapper
- `lib/desktop_ui/renderer/sdl2.ex` - SDL2 renderer implementation
- `test/desktop_ui/graphics_test.exs` - Graphics API tests
- `test/desktop_ui/renderer/sdl2_test.exs` - SDL2 renderer tests
- `test/integration/phase_2_integration_test.exs` - Integration tests

**Modified Files:**
- `mix.exs` - Add C compilation configuration
- `lib/desktop_ui/runtime.ex` - Integrate SDL2 as event bridge
- `lib/desktop_ui/signals.ex` - Ensure signals support SDL event data

**Dependencies:**
- Phase 1: Jido-First Architecture (Signal infrastructure, Runtime event bridge, Elm behaviour, Widget DSL)
- SDL2 development libraries (system package)

---

## Dependencies

**This phase depends on:**
- Phase 1: Architecture Validation (complete Signal infrastructure, Runtime event bridge, Elm behaviour, Widget system)

**Phases that depend on this phase:**
- Phase 3: First Real Widget (depends on Graphics API, SDL2 renderer, Signal event data)
- Future phases: Text rendering, advanced widgets
