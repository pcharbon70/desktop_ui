# Phase 2 Review Fixes - Comprehensive Feature Planning Document

**Date:** 2026-01-25
**Based On:** Phase 2 Graphics Bridge Review (notes/reviews/phase-2-graphics-bridge-review.md)
**Status:** Planning
**Priority:** Critical - Must complete before Phase 3

---

## Executive Summary

This document organizes all fixes, improvements, and enhancements identified in the Phase 2 review into a logical implementation plan. The review identified:
- **3 Blockers** (Must Fix)
- **16 Concerns** (Should Address)
- **25 Suggestions** (Nice to Have)

**Total Work Items:** 44 items organized into 9 feature groups

**Implementation Strategy:** Fix blockers first, then address concerns by feature area, finally implement suggestions as time permits.

---

## Implementation Phases Overview

### Phase A: Critical Blockers (Week 1)
**Goal:** Unblock all integration tests and fix production-critical issues
- Fix integration test setup
- Add window dimension bounds
- Fix ETS table ownership

### Phase B: Security Hardening (Week 2)
**Goal:** Address all security concerns
- Buffer overflow protection
- Race condition fixes
- Access control improvements
- Input validation

### Phase C: Architecture Refactoring (Week 3-4)
**Goal:** Improve code organization and reduce coupling
- Split Graphics module
- Decouple EventLoop
- Add Registry-based discovery
- Implement capability discovery

### Phase D: Testing Enhancement (Week 5-6)
**Goal:** Comprehensive test coverage including edge cases
- Visual verification tests
- Concurrent operation tests
- Failure injection tests
- Property-based testing

### Phase E: Code Quality & Tooling (Week 7+)
**Goal:** Long-term maintainability improvements
- Performance benchmarks
- Telemetry integration
- Fuzzing tests
- Developer tooling

---

## Phase A: Critical Blockers (Week 1)

### A1. Fix Integration Tests Setup Bug
**Priority:** CRITICAL
**Complexity:** Low (1-2 hours)
**File:** `test/integration/phase_2_integration_test.exs:29-34`

**Problem:**
```elixir
defp require_sdl2(_context) do
  if sdl2_available?() do
    :ok
  else
    {:skip, "SDL2 not available"}  # Invalid at describe level
  end
end
```

**Solution:**
Replace with ExUnit-compliant skip pattern:
```elixir
setup [:require_sdl2]

defp require_sdl2(context) do
  if sdl2_available?() do
    :ok
  else
    {:skip, "SDL2 not available"}
  end
end
```

Or use module-level tags:
```elixir
@moduletag [skip_if: :sdl2_unavailable]
```

**Testing:**
- Verify all 22 integration tests run when SDL2 available
- Verify proper skip when SDL2 unavailable
- Check test count output

**Dependencies:** None
**Blocks:** All integration test validation

---

### A2. Add Upper Bounds to Window Dimensions
**Priority:** CRITICAL
**Complexity:** Low (2-3 hours)
**File:** `c_src/desktop_ui_nif.c:836-858`

**Problem:**
No maximum validation for window width/height, allowing INT_MAX which causes overflow.

**Solution:**
```c
#define MAX_WINDOW_WIDTH 7680   // 8K resolution
#define MAX_WINDOW_HEIGHT 4320  // 8K resolution

int width;
if (!enif_get_int(env, argv[1], &width)) {
    return enif_make_badarg(env);
}
if (width < 1 || width > MAX_WINDOW_WIDTH) {
    set_last_error(env, "width must be between 1 and %d", MAX_WINDOW_WIDTH);
    return make_error_tuple(env);
}

int height;
if (!enif_get_int(env, argv[2], &height)) {
    return enif_make_badarg(env);
}
if (height < 1 || height > MAX_WINDOW_HEIGHT) {
    set_last_error(env, "height must be between 1 and %d", MAX_WINDOW_HEIGHT);
    return make_error_tuple(env);
}
```

**Testing:**
- Add test for MAX_WINDOW_WIDTH boundary
- Add test for MAX_WINDOW_HEIGHT boundary
- Add test for exceeding bounds returns error
- Add test for INT_MAX input

**Dependencies:** None
**Blocks:** Production deployment

---

### A3. Fix ETS Table Ownership for Hot Reload
**Priority:** CRITICAL
**Complexity:** Medium (4-6 hours)
**Files:** `lib/desktop_ui/graphics.ex:1136-1168`, `lib/desktop_ui/runtime.ex`

**Problem:**
ETS tables created in `@on_load` survive hot reload but references become stale, causing crashes or data corruption.

**Solution:**
Create a GenServer to own and manage ETS tables:

```elixir
defmodule DesktopUI.RendererCache do
  use GenServer
  @table_name :desktop_ui_renderer_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    # Create table with this process as owner
    table = :ets.new(@table_name, [:named_table, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  # API
  def put(key, value) do
    :ets.insert(@table_name, {key, value})
  end

  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :error
    end
  end

  def clear do
    :ets.delete_all_objects(@table_name)
  end

  # Callbacks
  def handle_info({:reload, new_module}, state) do
    # Notify new module that cache is ready
    send(new_module, :cache_ready)
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    # ETS table automatically deleted when owner dies
    :ok
  end
end
```

Update Graphics module:
```elixir
defmodule DesktopUI.Graphics do
  @on_load def load_nif do
    case load_nif_binary() do
      :ok -> :ok
      _ -> :ok  # Allow headless operation
    end
  end

  # Don't create ETS table in @on_load
  # Instead, ensure cache GenServer is started in supervisor
end
```

Add to Runtime supervisor:
```elixir
def init(opts) do
  children = [
    {DesktopUI.RendererCache, []},
    # ... other children
  ]
  Supervisor.init(children, strategy: :one_for_one)
end
```

**Testing:**
- Test hot reload with active renderer cache
- Test cache cleanup on GenServer termination
- Test concurrent cache access during reload
- Integration test: full hot reload cycle

**Dependencies:** None
**Blocks:** Production hot code reloading

---

## Phase B: Security Hardening (Week 2)

### B1. Buffer Overflow Protection in Title Handling
**Priority:** HIGH
**Complexity:** Medium (3-4 hours)
**Files:** `c_src/desktop_ui_nif.c` (window creation)

**Problem:**
No validation against SDL2 internal limits for window titles.

**Solution:**
```c
#define MAX_WINDOW_TITLE_LENGTH 1024  // SDL2 typical limit

static ERL_NIF_TERM create_window_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  char title[MAX_WINDOW_TITLE_LENGTH];

  // Get title with bounds checking
  if (enif_get_string(env, argv[0], title, MAX_WINDOW_TITLE_LENGTH, ERL_NIF_LATIN1) <= 0) {
      set_last_error(env, "title must be a valid string");
      return make_error_tuple(env);
  }

  // Truncate if too long
  if (strlen(title) >= MAX_WINDOW_TITLE_LENGTH - 1) {
      title[MAX_WINDOW_TITLE_LENGTH - 1] = '\0';
  }

  // ... rest of function
}
```

**Testing:**
- Test with title exactly at limit
- Test with title exceeding limit
- Test with empty title
- Test with special characters

**Dependencies:** None
**Related:** A2 (Dimension bounds)

---

### B2. Fix Race Condition in Slot Management
**Priority:** HIGH
**Complexity:** High (6-8 hours)
**File:** `c_src/desktop_ui_nif.c` (window/renderer slot management)

**Problem:**
No atomicity between find_free_slot and mark_used - two concurrent calls could get same slot.

**Solution:**
Use atomic operations with proper locking:

```c
// Add mutex for slot management
static ErlNifMutex* slot_mutex;
static bool window_slots[MAX_WINDOWS];
static bool renderer_slots[MAX_WINDOWS];

// Initialize in load_nif
static int load_nif(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
  // ... existing code

  slot_mutex = enif_mutex_create("desktop_ui_slots");
  if (!slot_mutex) {
      return -1;
  }

  // Initialize slots
  memset(window_slots, 0, sizeof(window_slots));
  memset(renderer_slots, 0, sizeof(renderer_slots));

  return 0;
}

// Atomic slot allocation
static int find_and_allocate_window_slot() {
  enif_mutex_lock(slot_mutex);

  for (int i = 0; i < MAX_WINDOWS; i++) {
    if (!window_slots[i]) {
      window_slots[i] = true;
      enif_mutex_unlock(slot_mutex);
      return i;
    }
  }

  enif_mutex_unlock(slot_mutex);
  return -1;  // No free slot
}

static void free_window_slot(int slot) {
  enif_mutex_lock(slot_mutex);
  if (slot >= 0 && slot < MAX_WINDOWS) {
    window_slots[slot] = false;
  }
  enif_mutex_unlock(slot_mutex);
}

// Cleanup in unload
static void unload_nif(ErlNifEnv* env, void* priv_data) {
  if (slot_mutex) {
    enif_mutex_destroy(slot_mutex);
    slot_mutex = NULL;
  }
  // ... rest of cleanup
}
```

**Testing:**
- Stress test: create 1000 windows concurrently from multiple processes
- Test slot reuse after free
- Test exhaustion (all slots in use)
- Test mutex contention under load

**Dependencies:** None
**Related:** B1 (Buffer protection)

---

### B3. Add Access Control for ETS Tables
**Priority:** HIGH
**Complexity:** Medium (4-5 hours)
**Files:** `lib/desktop_ui/renderer_cache.ex` (new), `lib/desktop_ui/graphics.ex`

**Problem:**
Public ETS table allows any process to modify renderer cache.

**Solution:**
Make table private and provide controlled API:

```elixir
defmodule DesktopUI.RendererCache do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    # Private table - only this process can access
    table = :ets.new(:renderer_cache, [
      :set,
      :protected,  # Only owner can write, others can read
      read_concurrency: true
    ])
    {:ok, %{table: table}}
  end

  # All access through GenServer API (serialized)
  def put(key, value) do
    GenServer.call(__MODULE__, {:put, key, value})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # Handle calls
  def handle_call({:put, key, value}, _from, state) do
    :ets.insert(state.table, {key, value})
    {:reply, :ok, state}
  end

  def handle_call({:get, key}, _from, state) do
    reply = case :ets.lookup(state.table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :error
    end
    {:reply, reply, state}
  end

  def handle_call({:delete, key}, _from, state) do
    :ets.delete(state.table, key)
    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.table)
    {:reply, :ok, state}
  end
end
```

**Testing:**
- Test concurrent cache access
- Test isolation between different renderers
- Test cache consistency under load
- Test access control (external process cannot write directly)

**Dependencies:** A3 (ETS ownership fix)
**Related:** B2 (Race conditions)

---

### B4. Add Poll Interval Validation
**Priority:** MEDIUM
**Complexity:** Low (2-3 hours)
**File:** `lib/desktop_ui/event_loop.ex`

**Problem:**
No min/max validation on poll interval could cause performance issues.

**Solution:**
```elixir
defmodule DesktopUI.EventLoop do
  @min_poll_interval 1    # 1ms minimum
  @max_poll_interval 1000 # 1 second maximum

  def start_link(opts) do
    poll_interval = Keyword.get(opts, :poll_interval, 16)  # Default 60fps

    with :ok <- validate_poll_interval(poll_interval) do
      GenServer.start_link(__MODULE__, [poll_interval: poll_interval], opts)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_poll_interval(interval) when is_integer(interval) do
    cond do
      interval < @min_poll_interval ->
        {:error, "poll_interval must be at least #{@min_poll_interval}ms"}
      interval > @max_poll_interval ->
        {:error, "poll_interval must be at most #{@max_poll_interval}ms"}
      true ->
        :ok
    end
  end
  defp validate_poll_interval(_), do: {:error, "poll_interval must be an integer"}

  @impl true
  def init([poll_interval: interval]) do
    # Schedule first poll
    schedule_poll(interval)
    {:ok, %{poll_interval: interval, events: []}}
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end
end
```

**Testing:**
- Test minimum boundary (1ms)
- Test maximum boundary (1000ms)
- Test default (16ms)
- Test invalid types
- Test negative values

**Dependencies:** None
**Related:** B1 (Input validation)

---

## Phase C: Architecture Refactoring (Week 3-4)

### C1. Split Graphics Module
**Priority:** HIGH
**Complexity:** High (2-3 days)
**Files:** `lib/desktop_ui/graphics.ex` (1,278 lines)

**Problem:**
Graphics module handles too many concerns (NIF wrapper, convenience API, caching, validation).

**Solution:**
Split into focused modules:

```elixir
# lib/desktop_ui/graphics.ex (Core NIF wrapper - ~400 lines)
defmodule DesktopUI.Graphics do
  @moduledoc """
  Low-level SDL2 graphics operations via NIF.
  Thin wrapper around C functions with basic validation.
  """

  # Direct NIF calls only
  def create_window(title, width, height)
  def destroy_window(window_id)
  def create_renderer(window_id)
  def destroy_renderer(renderer_id)
  # ... etc
end

# lib/desktop_ui/graphics/window.ex (Window operations - ~200 lines)
defmodule DesktopUI.Graphics.Window do
  @moduledoc """
  High-level window management API.
  """

  def create(title, width, height, opts \\ [])
  def destroy(window_id)
  def set_title(window_id, title)
  def get_size(window_id)
  def set_size(window_id, width, height)
  # ... etc
end

# lib/desktop_ui/graphics/renderer.ex (Renderer operations - ~300 lines)
defmodule DesktopUI.Graphics.Renderer do
  @moduledoc """
  High-level renderer operations.
  """

  def create(window_id, opts \\ [])
  def destroy(renderer_id)
  def clear(renderer_id, color)
  def present(renderer_id)
  # ... etc
end

# lib/desktop_ui/graphics/drawing.ex (Drawing primitives - ~200 lines)
defmodule DesktopUI.Graphics.Drawing do
  @moduledoc """
  Drawing primitives.
  """

  def draw_rect(renderer_id, rect, color)
  def fill_rect(renderer_id, rect, color)
  def draw_line(renderer_id, start, finish, color)
  # ... etc
end

# lib/desktop_ui/graphics/cache.ex (Caching - ~150 lines)
defmodule DesktopUI.Graphics.Cache do
  @moduledoc """
  Renderer caching and lookup.
  """

  def get_renderer(window_id)
  def cache_renderer(window_id, renderer_id)
  def invalidate(window_id)
  # ... etc
end
```

**Migration Path:**
1. Create new module files
2. Move functions, keeping old API as delegates
3. Update internal calls to use new modules
4. Deprecate old API (keep for compatibility)
5. Update documentation

**Testing:**
- All existing tests must pass
- Add tests for each new module
- Test compatibility layer
- Performance: ensure no regression

**Dependencies:** A3 (ETS ownership)
**Related:** C2, C3

---

### C2. Decouple EventLoop from Renderer
**Priority:** MEDIUM
**Complexity:** Medium (1-2 days)
**Files:** `lib/desktop_ui/event_loop.ex`, `lib/desktop_ui/graphics/cache.ex`

**Problem:**
EventLoop knows about renderer ETS table structure (coupling).

**Solution:**
Use callback/behaviour instead of direct ETS access:

```elixir
defmodule DesktopUI.EventLoop do
  @callback get_renderer() :: {:ok, renderer_id} | :error
  @callback get_window() :: {:ok, window_id} | :error

  def start_link(opts) do
    renderer_module = Keyword.get(opts, :renderer_module, DesktopUI.Graphics.Cache)
    GenServer.start_link(__MODULE__, [renderer_module: renderer_module], opts)
  end

  def init([renderer_module: renderer_module]) do
    state = %{
      renderer_module: renderer_module,
      poll_interval: Keyword.get(opts, :poll_interval, 16)
    }

    case renderer_module.get_renderer() do
      {:ok, _renderer} ->
        schedule_poll(state.poll_interval)
        {:ok, state}
      :error ->
        {:stop, :no_renderer}
    end
  end

  def handle_info(:poll, state) do
    # Poll events via NIF
    events = DesktopUI.Graphics.poll_events()

    # Process events
    # ...

    schedule_poll(state.poll_interval)
    {:noreply, state}
  end
end
```

**Testing:**
- Test with mock renderer module
- Test with different renderer implementations
- Test graceful shutdown when renderer unavailable

**Dependencies:** C1 (Split Graphics)
**Related:** C3

---

### C3. Add Registry-Based Process Discovery
**Priority:** MEDIUM
**Complexity:** Medium (1 day)
**Files:** `lib/desktop_ui/runtime.ex`, `lib/desktop_ui/event_loop.ex`

**Problem:**
Current process discovery via Supervisor is racy and fragile.

**Solution:**
Use Registry for reliable discovery:

```elixir
defmodule DesktopUI.Registry do
  @moduledoc """
  Process registry for DesktopUI components.
  """
  use Registry

  def start_link(_opts) do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  def register_component(name, pid) do
    Registry.register(__MODULE__, {:component, name}, {name, pid})
  end

  def find_component(name) do
    case Registry.lookup(__MODULE__, {:component, name}) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end
end

# In Runtime
def init(opts) do
  children = [
    {DesktopUI.Registry, []},
    {DesktopUI.RendererCache, []},
    {DesktopUI.Graphics.Renderer, [name: :main_renderer]},
    {DesktopUI.EventLoop, [renderer_module: DesktopUI.Graphics.Cache]}
  ]

  Supervisor.init(children, strategy: :one_for_one)
end

# In EventLoop
def get_root_component do
  case DesktopUI.Registry.find_component(:root_component) do
    {:ok, pid} -> {:ok, pid}
    :error -> :error
  end
end
```

**Testing:**
- Test component registration
- Test lookup under concurrent registration
- Test unregistration on process death
- Test with Registry partitioning

**Dependencies:** C2 (Decouple EventLoop)
**Related:** A3 (ETS ownership)

---

### C4. Add Capability Discovery for Renderers
**Priority:** LOW
**Complexity:** Medium (1 day)
**Files:** New: `lib/desktop_ui/renderer_capabilities.ex`

**Problem:**
No way to discover renderer features (hardware acceleration, max texture size, etc.).

**Solution:**
Implement capability query system:

```elixir
defmodule DesktopUI.RendererCapabilities do
  @moduledoc """
  Query renderer capabilities and features.
  """

  @type capability :: :hardware_accelerated | :vsync | :target_texture |
                     :max_texture_size | :renderer_info

  def get_capabilities(renderer_id) do
    %{
      hardware_accelerated?: is_hardware_accelerated(renderer_id),
      vsync_supported?: supports_vsync(renderer_id),
      max_texture_size: get_max_texture_size(renderer_id),
      renderer_info: get_renderer_info(renderer_id)
    }
  end

  def supports?(renderer_id, capability) do
    case capability do
      :hardware_accelerated -> is_hardware_accelerated(renderer_id)
      :vsync -> supports_vsync(renderer_id)
      :target_texture -> supports_target_texture(renderer_id)
      _ -> false
    end
  end

  # NIF calls to query SDL2
  defp is_hardware_accelerated(renderer_id) do
    case DesktopUI.Graphics.get_renderer_info(renderer_id) do
      {:ok, info} -> info.accelerated
      _ -> false
    end
  end
end
```

**Testing:**
- Test capability detection with software renderer
- Test capability detection with hardware renderer
- Test graceful handling of unknown capabilities

**Dependencies:** C1 (Split Graphics)
**Related:** C2

---

### C5. Remove Fixed Array Limits
**Priority:** LOW
**Complexity:** High (2-3 days)
**Files:** `c_src/desktop_ui_nif.c`

**Problem:**
MAX_WINDOWS/MAX_RENDERERS hardcoded to 128, preventing dynamic scaling.

**Solution:**
Use dynamic allocation with hash table:

```c
// Use ErlNifResourceType for dynamic management
static ErlNifResourceType* window_resource_type;

// In load_nif
static int load_nif(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
  ErlNifResourceTypeFlags flags = (ErlNifResourceTypeFlags)(ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER);

  window_resource_type = enif_open_resource_type(
    env,
    "desktop_ui_nif",
    "window_resource",
    window_dtor,
    flags,
    NULL
  );

  if (!window_resource_type) {
    return -1;
  }

  return 0;
}

// Window management
typedef struct {
  SDL_Window* window;
  int id;
} WindowResource;

static void window_dtor(ErlNifEnv* env, void* obj) {
  WindowResource* win = (WindowResource*)obj;
  if (win->window) {
    SDL_DestroyWindow(win->window);
  }
}

// Create returns resource reference
static ERL_NIF_TERM create_window_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  WindowResource* win = enif_alloc_resource(window_resource_type, sizeof(WindowResource));
  win->window = SDL_CreateWindow(title, x, y, width, height, flags);
  win->id = SDL_GetWindowID(win->window);

  ERL_NIF_TERM term = enif_make_resource(env, win);
  enif_release_resource(win);

  return enif_make_tuple2(env, atom_ok, term);
}
```

**Testing:**
- Stress test: create >128 windows
- Test resource cleanup
- Test memory usage with many windows
- Performance test: lookup overhead

**Dependencies:** B2 (Slot management)
**Related:** C1

---

## Phase D: Testing Enhancement (Week 5-6)

### D1. Visual Verification Tests
**Priority:** HIGH
**Complexity:** High (3-4 days)
**Files:** New: `test/desktop_ui/visual_verification_test.exs`

**Problem:**
Tests verify no crashes, but not correct visual output.

**Solution:**
Implement screenshot-based verification:

```elixir
defmodule DesktopUI.VisualVerificationTest do
  use ExUnit.Case, async: false

  @fixtures Path.expand("../../fixtures/screenshots", __DIR__)

  setup do
    {:ok, renderer} = DesktopUI.Graphics.Renderer.create()
    on_exit(fn -> DesktopUI.Graphics.Renderer.destroy(renderer) end)
    {:ok, renderer: renderer}
  end

  test "renders red rectangle correctly", %{renderer: renderer} do
    # Clear to white
    DesktopUI.Graphics.Renderer.clear(renderer, :white)

    # Draw red rectangle
    rect = {10, 10, 100, 100}
    DesktopUI.Graphics.Drawing.fill_rect(renderer, rect, :red)
    DesktopUI.Graphics.Renderer.present(renderer)

    # Capture screenshot
    {:ok, screenshot} = capture_screenshot(renderer)

    # Compare to fixture
    fixture_path = Path.join(@fixtures, "red_rectangle.png")
    assert_images_match(screenshot, fixture_path, tolerance: 0.95)
  end

  defp capture_screenshot(renderer) do
    # NIF to capture renderer output to buffer
    DesktopUI.Graphics.capture_screenshot(renderer)
  end

  defp assert_images_match(actual, expected, opts) do
    tolerance = Keyword.get(opts, :tolerance, 1.0)

    {:ok, actual_data} = read_image(actual)
    {:ok, expected_data} = read_image(expected)

    similarity = calculate_similarity(actual_data, expected_data)
    assert similarity >= tolerance,
      "Images differ by #{100 - similarity * 100}%"
  end
end
```

Add NIF for screenshot capture:
```c
static ERL_NIF_TERM capture_screenshot_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  RendererResource* renderer_res;
  if (!enif_get_resource(env, argv[0], renderer_resource_type, (void**)&renderer_res)) {
    return enif_make_badarg(env);
  }

  SDL_Renderer* renderer = renderer_res->renderer;

  // Get window size
  int width, height;
  SDL_GetWindowSize(renderer_res->window, &width, &height);

  // Create surface
  SDL_Surface* surface = SDL_CreateRGBSurface(0, width, height, 32, 0, 0, 0, 0);
  if (!surface) {
    return make_error_tuple(env);
  }

  // Read pixels
  SDL_RenderReadPixels(renderer, NULL, SDL_PIXELFORMAT_ARGB8888,
                      surface->pixels, surface->pitch);

  // Convert to binary
  ErlNifBinary bin;
  enif_alloc_binary(width * height * 4, &bin);
  memcpy(bin.data, surface->pixels, bin.size);

  SDL_FreeSurface(surface);

  ERL_NIF_TERM result = enif_make_binary(env, &bin);
  return enif_make_tuple2(env, atom_ok, result);
}
```

**Testing:**
- Create fixture images for basic operations
- Test fixture generation
- Test comparison tolerance
- Test visual regression detection

**Dependencies:** A1 (Integration tests)
**Related:** D2, D3

---

### D2. Concurrent Operation Tests
**Priority:** HIGH
**Complexity:** Medium (2 days)
**Files:** New: `test/desktop_ui/concurrent_test.exs`

**Problem:**
No tests for multiple processes operating simultaneously.

**Solution:**
Add comprehensive concurrency tests:

```elixir
defmodule DesktopUI.ConcurrentTest do
  use ExUnit.Case, async: false

  test "concurrent window creation" do
    num_windows = 10
    tasks = for i <- 1..num_windows do
      Task.async(fn ->
        {:ok, window} = DesktopUI.Graphics.create_window("Win#{i}", 640, 480)
        window
      end)
    end

    windows = Task.await_many(tasks, 5000)

    assert length(windows) == num_windows
    assert Enum.uniq(windows) |> length() == num_windows  # All unique

    # Cleanup
    Enum.each(windows, &DesktopUI.Graphics.destroy_window/1)
  end

  test "concurrent rendering to same window" do
    {:ok, window} = DesktopUI.Graphics.create_window("Concurrent", 640, 480)
    {:ok, renderer} = DesktopUI.Graphics.create_renderer(window)

    # Spawn multiple processes rendering different regions
    regions = [
      {0, 0, 320, 240, :red},
      {320, 0, 320, 240, :blue},
      {0, 240, 320, 240, :green},
      {320, 240, 320, 240, :yellow}
    ]

    tasks = Enum.map(regions, fn {x, y, w, h, color} ->
      Task.async(fn ->
        100.times do
          DesktopUI.Graphics.fill_rect(renderer, {x, y, w, h}, color)
          Process.sleep(1)
        end
      end)
    end)

    Task.await_many(tasks, 10_000)

    DesktopUI.Graphics.destroy_renderer(renderer)
    DesktopUI.Graphics.destroy_window(window)
  end

  test "concurrent cache access" do
    {:ok, window} = DesktopUI.Graphics.create_window("Cache Test", 640, 480)
    {:ok, renderer} = DesktopUI.Graphics.create_renderer(window)

    # Many processes accessing cache simultaneously
    tasks = for _ <- 1..100 do
      Task.async(fn ->
        DesktopUI.Graphics.Cache.get_renderer(window.id)
      end)
    end

    results = Task.await_many(tasks, 5000)

    # All should get same renderer
    assert Enum.all?(results, fn
      {:ok, id} -> id == renderer.id
      _ -> false
    end)
  end
end
```

**Testing:**
- Run with `:concurrency` flag
- Test with different scheduler configurations
- Measure contention
- Detect race conditions

**Dependencies:** B2 (Race conditions), B3 (Access control)
**Related:** D3, D4

---

### D3. Failure Injection Tests
**Priority:** HIGH
**Complexity:** Medium (2 days)
**Files:** New: `test/desktop_ui/failure_injection_test.exs`

**Problem:**
No tests for crash scenarios and error recovery.

**Solution:**
Implement chaos testing:

```elixir
defmodule DesktopUI.FailureInjectionTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, runtime} = DesktopUI.Runtime.start_link()
    on_exit(fn -> DesktopUI.Runtime.stop(runtime) end)
    {:ok, runtime: runtime}
  end

  test "runtime recovers from EventLoop crash", %{runtime: runtime} do
    # Get EventLoop PID
    event_loop_pid = DesktopUI.Runtime.get_event_loop(runtime)

    # Kill it abruptly
    Process.exit(event_loop_pid, :kill)

    # Wait for restart
    Process.sleep(100)

    # Verify runtime still functional
    assert Process.alive?(runtime.pid)

    # Get new EventLoop PID
    new_event_loop_pid = DesktopUI.Runtime.get_event_loop(runtime)
    assert new_event_loop_pid != event_loop_pid

    # Verify it works
    assert {:ok, _} = DesktopUI.Runtime.get_root_component(runtime)
  end

  test "renderer cache survives Graphics module reload" do
    {:ok, window} = DesktopUI.Graphics.create_window("Test", 640, 480)
    {:ok, renderer} = DesktopUI.Graphics.create_renderer(window)

    # Cache the renderer
    DesktopUI.Graphics.Cache.cache_renderer(window.id, renderer)

    # Simulate hot reload by clearing module state
    :erlang.purge_module(DesktopUI.Graphics)
    :erlang.delete_module(DesktopUI.Graphics)
    Code.require_file("lib/desktop_ui/graphics.ex")

    # Cache should still be valid (owned by GenServer)
    assert {:ok, ^renderer} = DesktopUI.Graphics.Cache.get_renderer(window.id)
  end

  test "handles SDL2 initialization failure gracefully" do
    # Mock SDL2 failure scenario
    # Set environment to force failure
    System.put_env("DESKTOP_UI_SDL2_MOCK_FAILURE", "init")

    assert {:error, _} = DesktopUI.Runtime.start_link()

    # Cleanup
    System.delete_env("DESKTOP_UI_SDL2_MOCK_FAILURE")
  end

  test "window cleanup on abnormal termination" do
    {:ok, window} = DesktopUI.Graphics.create_window("Test", 640, 480)
    window_id = window.id

    # Kill parent process without cleanup
    parent_pid = self()

    spawn(fn ->
      send(parent_pid, :continue)
      Process.sleep(100)
      exit(:abnormal)
    end)

    receive do
      :continue -> :ok
    end

    Process.sleep(200)

    # Verify window was cleaned up
    assert {:error, _} = DesktopUI.Graphics.get_window(window_id)
  end
end
```

**Testing:**
- Test all crash paths
- Test supervisor restart strategies
- Test state recovery after restart
- Test orphaned resource cleanup

**Dependencies:** A3 (ETS ownership)
**Related:** D2

---

### D4. Property-Based Testing
**Priority:** MEDIUM
**Complexity:** Medium (2 days)
**Files:** New: `test/desktop_ui/properties_test.exs`

**Problem:**
Unit tests use specific examples, edge cases not explored.

**Solution:**
Add property-based tests with StreamData:

```elixir
defmodule DesktopUI.PropertiesTest do
  use ExUnit.Case
  use PropCheck

  property "window size is always set correctly" do
    forall {width, height} in {pos_integer(), pos_integer()} do
      # Constrain to reasonable bounds
      implies width in 1..7680 and height in 1..4320 do
        {:ok, window} = DesktopUI.Graphics.create_window("Test", width, height)

        {:ok, {actual_width, actual_height}} =
          DesktopUI.Graphics.get_window_size(window)

        DesktopUI.Graphics.destroy_window(window)

        actual_width == width and actual_height == height
      end
    end
  end

  property "color components are clamped to 0-255" do
    forall {r, g, b} in {integer(), integer(), integer()} do
      color = DesktopUI.Color.normalize({r, g, b})

      elem(color, 0) in 0..255 and
      elem(color, 1) in 0..255 and
      elem(color, 2) in 0..255
    end
  end

  property "renderer cache is idempotent" do
    forall window_id in pos_integer() do
      cache = DesktopUI.RendererCache

      # Put same value multiple times
      :ok = cache.put(window_id, :renderer_1)
      :ok = cache.put(window_id, :renderer_2)

      # Should always get latest value
      {:ok, :renderer_2} = cache.get(window_id)

      # Cleanup
      cache.delete(window_id)

      true
    end
  end

  property "rect drawing is commutative" do
    forall [
      rect1 in {{integer(), integer()}, {integer(), integer()}},
      rect2 in {{integer(), integer()}, {integer(), integer()}},
      color1 in {byte(), byte(), byte()},
      color2 in {byte(), byte(), byte()}
    ] do
      # Drawing rect1 then rect2 should produce same as rect2 then rect1
      # if they don't overlap
      {:ok, renderer} = setup_renderer()

      {{x1, y1}, {w1, h1}} = rect1
      {{x2, y2}, {w2, h2}} = rect2

      # Ensure no overlap
      implies not overlap?(rect1, rect2) do
        DesktopUI.Graphics.fill_rect(renderer, {x1, y1, w1, h1}, color1)
        DesktopUI.Graphics.fill_rect(renderer, {x2, y2, w2, h2}, color2)

        result1 = capture_pixels(renderer)

        DesktopUI.Graphics.clear(renderer, :black)
        DesktopUI.Graphics.fill_rect(renderer, {x2, y2, w2, h2}, color2)
        DesktopUI.Graphics.fill_rect(renderer, {x1, y1, w1, h1}, color1)

        result2 = capture_pixels(renderer)

        cleanup_renderer(renderer)

        result1 == result2
      end
    end
  end

  defp overlap?({{x1, y1}, {w1, h1}}, {{x2, y2}, {w2, h2}}) do
    not (x1 + w1 < x2 or x2 + w2 < x1 or y1 + h1 < y2 or y2 + h2 < y1)
  end
end
```

**Testing:**
- Run with `mix test --property`
- Generate shrink logs for failures
- Aim for >1000 tests per property

**Dependencies:** C1 (Split Graphics)
**Related:** D1, D2

---

### D5. Replace Process.sleep with Assert Receive
**Priority:** MEDIUM
**Complexity:** Low (1 day)
**Files:** `test/desktop_ui/event_loop_test.exs` and others

**Problem:**
Tests use `Process.sleep` which makes them flaky.

**Solution:**
Use message assertions and synchronization:

```elixir
# Before
test "event loop polls events" do
  {:ok, event_loop} = DesktopUI.EventLoop.start_link()
  Process.sleep(100)  # Hope enough events were polled
  assert_received {:poll, _}
end

# After
test "event loop polls events" do
  {:ok, event_loop} = DesktopUI.EventLoop.start_link(poll_interval: 10)

  # Subscribe to poll events
  Process.monitor(event_loop)
  :sys.statistics(event_loop, true)

  # Wait for at least 5 polls within 200ms
  assert_receive {:poll, _}, 200
  assert_receive {:poll, _}, 200
  assert_receive {:poll, _}, 200
  assert_receive {:poll, _}, 200
  assert_receive {:poll, _}, 200

  # Verify statistics
  {:ok, stats} = :sys.get_statistics(event_loop)
  assert stats.message_queue_len < 10  # Not backing up
end
```

For async operations:
```elixir
test "renderer processes events asynchronously" do
  {:ok, renderer} = DesktopUI.Renderer.start_link()

  # Send draw request
  ref = make_ref()
  send(renderer, {:draw_rect, self(), ref, {0, 0, 100, 100}, :red})

  # Wait for completion with timeout
  assert_receive {:draw_complete, ^ref}, 500
end
```

**Testing:**
- All tests should run faster
- No more flaky tests due to timing
- Verify message queue doesn't back up

**Dependencies:** None
**Related:** D2, D3

---

## Phase E: Code Quality & Tooling (Week 7+)

### E1. Extract Color Module
**Priority:** MEDIUM
**Complexity:** Low (4-6 hours)
**Files:** New: `lib/desktop_ui/color.ex`

**Problem:**
Color normalization logic mixed with graphics operations.

**Solution:**
Create dedicated Color module:

```elixir
defmodule DesktopUI.Color do
  @moduledoc """
  Color manipulation and validation.
  """

  @type color :: {byte(), byte(), byte(), byte()}  # {r, g, b, a}
  @type color_name :: :black | :white | :red | :green | :blue | :yellow | :cyan | :magenta

  # Named colors
  @colors %{
    black: {0, 0, 0, 255},
    white: {255, 255, 255, 255},
    red: {255, 0, 0, 255},
    green: {0, 255, 0, 255},
    blue: {0, 0, 255, 255},
    yellow: {255, 255, 0, 255},
    cyan: {0, 255, 255, 255},
    magenta: {255, 0, 255, 255}
  }

  @doc """
  Normalize color input to {r, g, b, a} tuple.
  """
  @spec normalize(color_name | color | {byte(), byte(), byte()} | byte()) :: color
  def normalize(color) when is_atom(color) do
    Map.get(@colors, color, {0, 0, 0, 255})
  end

  def normalize({r, g, b}) when is_byte(r) and is_byte(g) and is_byte(b) do
    {r, g, b, 255}
  end

  def normalize({r, g, b, a}) when is_byte(r) and is_byte(g) and is_byte(b) and is_byte(a) do
    {r, g, b, a}
  end

  def normalize(gray) when is_byte(gray) do
    {gray, gray, gray, 255}
  end

  def normalize({r, g, b}) do
    {
      clamp(r),
      clamp(g),
      clamp(b),
      255
    }
  end

  def normalize({r, g, b, a}) do
    {
      clamp(r),
      clamp(g),
      clamp(b),
      clamp(a)
    }
  end

  @doc """
  Convert color to SDL2 format (0xRRGGBBAA).
  """
  @spec to_uint32(color) :: non_neg_integer
  def to_uint32({r, g, b, a}) do
    (r <<< 24) + (g <<< 16) + (b <<< 8) + a
  end

  @doc """
  Blend two colors with given alpha (0.0-1.0).
  """
  @spec blend(color, color, float) :: color
  def blend({r1, g1, b1, a1}, {r2, g2, b2, a2}, alpha) when alpha >= 0.0 and alpha <= 1.0 do
    {
      round(r1 * (1 - alpha) + r2 * alpha),
      round(g1 * (1 - alpha) + g2 * alpha),
      round(b1 * (1 - alpha) + b2 * alpha),
      round(a1 * (1 - alpha) + a2 * alpha)
    }
  end

  defp clamp(value) when is_integer(value) do
    value
    |> max(0)
    |> min(255)
  end
end
```

**Testing:**
- Test all named colors
- Test normalization with out-of-bounds values
- Test blending edge cases
- Test to_uint32 conversion

**Dependencies:** C1 (Split Graphics)
**Related:** D4

---

### E2. Improve NIF Error Messages
**Priority:** MEDIUM
**Complexity:** Medium (1 day)
**Files:** `c_src/desktop_ui_nif.c`

**Problem:**
All NIF errors return generic "operation failed" message.

**Solution:**
Add context-specific error messages:

```c
// Error message helper
static void set_error_with_context(ErlNifEnv* env, const char* operation,
                                   const char* reason, int value) {
  char error_buf[256];
  snprintf(error_buf, sizeof(error_buf),
           "%s failed: %s (value: %d)", operation, reason, value);
  set_last_error(env, error_buf);
}

// Usage in create_window_nif
static ERL_NIF_TERM create_window_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  char title[256];
  int width, height;

  if (enif_get_string(env, argv[0], title, sizeof(title), ERL_NIF_LATIN1) <= 0) {
    set_error_with_context(env, "create_window", "invalid title", 0);
    return make_error_tuple(env);
  }

  if (!enif_get_int(env, argv[1], &width)) {
    set_error_with_context(env, "create_window", "invalid width type", 0);
    return make_error_tuple(env);
  }

  if (width < 1 || width > MAX_WINDOW_WIDTH) {
    set_error_with_context(env, "create_window", "width out of bounds", width);
    return make_error_tuple(env);
  }

  // ... rest of function
}
```

**Testing:**
- Test error message for each failure mode
- Verify error messages include context
- Test error message format is parseable

**Dependencies:** None
**Related:** B1 (Input validation)

---

### E3. Add Performance Benchmarks
**Priority:** LOW
**Complexity:** Medium (2 days)
**Files**: New: `bench/desktop_ui_bench.exs`

**Problem:**
No performance baseline to detect regressions.

**Solution:**
Add Benchee benchmarks:

```elixir
defmodule DesktopUI.Bench do
  use Benchee

  setup do
    {:ok, window} = DesktopUI.Graphics.create_window("Bench", 800, 600)
    {:ok, renderer} = DesktopUI.Graphics.create_renderer(window)

    on_exit(fn ->
      DesktopUI.Graphics.destroy_renderer(renderer)
      DesktopUI.Graphics.destroy_window(window)
    end)

    %{renderer: renderer}
  end

  bench "fill_rect [100x100]", context do
    DesktopUI.Graphics.fill_rect(context.renderer, {0, 0, 100, 100}, :red)
  end

  bench "fill_rect [800x600] fullscreen", context do
    DesktopUI.Graphics.fill_rect(context.renderer, {0, 0, 800, 600}, :blue)
  end

  bench "100 fill_rect calls", context do
    Enum.each(1..100, fn i ->
      x = rem(i * 10, 800)
      y = div(i * 10, 800) * 10
      DesktopUI.Graphics.fill_rect(context.renderer, {x, y, 10, 10}, :green)
    end)
  end

  bench "renderer cache lookup", context do
    DesktopUI.Graphics.Cache.get_renderer(1)
  end

  bench "event poll", _context do
    DesktopUI.Graphics.poll_events()
  end
end
```

Run with:
```bash
mix bench
```

**Testing:**
- Establish baseline metrics
- Run benchmarks on each PR
- Track performance over time

**Dependencies:** C1 (Split Graphics)
**Related:** D2

---

### E4. Add Telemetry Integration
**Priority:** LOW
**Complexity:** Medium (2 days)
**Files:** New: `lib/desktop_ui/telemetry.ex`

**Problem:**
No visibility into system behavior in production.

**Solution:**
Integrate `:telemetry` for metrics:

```elixir
defmodule DesktopUI.Telemetry do
  @moduledoc """
  Telemetry event reporting for DesktopUI.
  """

  @events [
    [:desktop_ui, :renderer, :create],
    [:desktop_ui, :renderer, :destroy],
    [:desktop_ui, :window, :create],
    [:desktop_ui, :window, :destroy],
    [:desktop_ui, :event_loop, :poll],
    [:desktop_ui, :draw, :rect],
    [:desktop_ui, :cache, :hit],
    [:desktop_ui, :cache, :miss]
  ]

  @doc """
  Attach default telemetry handlers.
  """
  def attach_handlers do
    :telemetry.attach(
      "desktop_ui-metrics",
      :telemetry.event_count(@events, :timer),
      &handle_event/4,
      nil
    )
  end

  defp handle_event(event_name, measurements, metadata, _config) do
    # Log or forward to metrics system
    IO.inspect("#{inspect(event_name)}: #{inspect(measurements)}")
  end

  # Convenience functions
  def renderer_create(duration, metadata) do
    :telemetry.execute([:desktop_ui, :renderer, :create], %{duration: duration}, metadata)
  end

  def cache_hit(metadata) do
    :telemetry.execute([:desktop_ui, :cache, :hit], %{count: 1}, metadata)
  end

  def cache_miss(metadata) do
    :telemetry.execute([:desktop_ui, :cache, :miss], %{count: 1}, metadata)
  end
end

# Usage in code
def create_renderer(window_id, opts \\ []) do
  start_time = System.monotonic_time()

  case DesktopUI.Graphics.create_renderer(window_id, opts) do
    {:ok, renderer} ->
      duration = System.monotonic_time() - start_time
      DesktopUI.Telemetry.renderer_create(duration, %{window_id: window_id})
      {:ok, renderer}

    error ->
      error
  end
end
```

**Testing:**
- Test telemetry events are emitted
- Test event metadata includes relevant info
- Test performance impact is minimal

**Dependencies:** None
**Related:** E3 (Benchmarks)

---

### E5. Add Fuzzing Tests
**Priority:** LOW
**Complexity:** High (3-4 days)
**Files**: New: `test/fuzzing/`

**Problem:**
NIF boundary not tested with malformed inputs.

**Solution:**
Add fuzzing with property testing:

```elixir
defmodule DesktopUI.FuzzingTest do
  use ExUnit.Case

  @fuzz_iterations 10_000

  test "fuzz create_window with random inputs" do
    # Use StreamData to generate random inputs
    data = StreamData.tuple({
      StreamData.binary(min_length: 0, max_length: 10000),
      StreamData.integer(),
      StreamData.integer()
    })

    data
    |> StreamData.take(@fuzz_iterations)
    |> Enum.each(fn {title, width, height} ->
      # Should never crash, always return ok or error tuple
      result = DesktopUI.Graphics.create_window(title, width, height)

      assert match?({:ok, _}, result) or match?({:error, _}, result),
        "Crashed with input: #{inspect({title, width, height})}"

      case result do
        {:ok, window} -> DesktopUI.Graphics.destroy_window(window)
        _ -> :ok
      end
    end)
  end

  test "fuzz draw_rect with random coordinates" do
    {:ok, window} = DesktopUI.Graphics.create_window("Fuzz", 800, 600)
    {:ok, renderer} = DesktopUI.Graphics.create_renderer(window)

    data = StreamData.tuple({
      StreamData.integer(),
      StreamData.integer(),
      StreamData.integer(),
      StreamData.integer(),
      StreamData.byte(),
      StreamData.byte(),
      StreamData.byte()
    })

    data
    |> StreamData.take(@fuzz_iterations)
    |> Enum.each(fn {x, y, w, h, r, g, b} ->
      # Should never crash
      result = DesktopUI.Graphics.fill_rect(renderer, {x, y, w, h}, {r, g, b})

      assert match?(:ok, result) or match?({:error, _}, result)
    end)

    DesktopUI.Graphics.destroy_renderer(renderer)
    DesktopUI.Graphics.destroy_window(window)
  end
end
```

**Testing:**
- Run fuzzing overnight
- Capture any crashes
- Add found crashes as regression tests

**Dependencies:** D2 (Concurrent tests)
**Related:** D4 (Property-based tests)

---

### E6. Add Memory Leak Detection
**Priority:** LOW
**Complexity:** Medium (2 days)
**Files**: New: `test/desktop_ui/memory_leak_test.exs`

**Problem:**
No detection of memory leaks in NIF code.

**Solution:**
Add memory profiling tests:

```elixir
defmodule DesktopUI.MemoryLeakTest do
  use ExUnit.Case, async: false

  test "no memory leak in create/destroy window cycle" do
    :erlang.garbage_collect()

    initial_memory = :erlang.memory(:total)

    # Perform many cycles
    for _ <- 1..1000 do
      {:ok, window} = DesktopUI.Graphics.create_window("Leak Test", 640, 480)
      DesktopUI.Graphics.destroy_window(window)
    end

    :erlang.garbage_collect()

    final_memory = :erlang.memory(:total)
    leaked = final_memory - initial_memory

    # Allow some growth but not excessive (<10MB)
    assert leaked < 10_000_000,
      "Memory leak detected: #{div(leaked, 1_000_000)}MB leaked"
  end

  test "no memory leak in renderer cache" do
    cache = DesktopUI.RendererCache

    :erlang.garbage_collect()
    initial_memory = :erlang.memory(:total)

    # Add and remove many entries
    for i <- 1..1000 do
      cache.put(i, {:renderer, i})
      cache.get(i)
      cache.delete(i)
    end

    :erlang.garbage_collect()
    final_memory = :erlang.memory(:total)
    leaked = final_memory - initial_memory

    assert leaked < 5_000_000,
      "Cache memory leak: #{div(leaked, 1_000_000)}MB leaked"
  end

  test "no memory leak in event polling" do
    {:ok, window} = DesktopUI.Graphics.create_window("Mem Test", 640, 480)
    {:ok, renderer} = DesktopUI.Graphics.create_renderer(window)

    :erlang.garbage_collect()
    initial_memory = :erlang.memory(:total)

    # Poll many times
    for _ <- 1..10_000 do
      DesktopUI.Graphics.poll_events()
    end

    :erlang.garbage_collect()
    final_memory = :erlang.memory(:total)
    leaked = final_memory - initial_memory

    DesktopUI.Graphics.destroy_renderer(renderer)
    DesktopUI.Graphics.destroy_window(window)

    assert leaked < 1_000_000,
      "Event polling memory leak: #{div(leaked, 1_000_000)}MB leaked"
  end
end
```

**Testing:**
- Run before and after operations
- Track growth patterns
- Set up CI memory budget

**Dependencies:** A3 (ETS ownership)
**Related:** E3 (Benchmarks)

---

### E7. Add Lifecycle Documentation
**Priority:** LOW
**Complexity:** Low (1 day)
**Files:** Update: `lib/desktop_ui/*.ex`

**Problem:**
Component lifecycle and initialization order not documented.

**Solution:**
Add comprehensive lifecycle documentation:

```elixir
defmodule DesktopUI do
  @moduledoc """
  DesktopUI - Cross-platform desktop UI framework.

  ## Component Lifecycle

  DesktopUI follows a strict initialization and shutdown order to ensure
  proper resource management:

  ### Startup Sequence

  1. **Registry** - Process registry for component discovery
  2. **RendererCache** - ETS table owner for renderer lookups
  3. **Graphics** - NIF initialization and SDL2 startup
  4. **Window Creation** - Primary window creation
  5. **Renderer Creation** - SDL2 renderer initialization
  6. **EventLoop** - Event polling and processing
  7. **Runtime** - Application supervisor and orchestrator

  ### Shutdown Sequence

  1. **EventLoop** - Stop event polling
  2. **Runtime** - Stop application logic
  3. **Renderer** - Release SDL2 renderer resources
  4. **Window** - Destroy SDL2 windows
  5. **Graphics** - SDL2 shutdown
  6. **RendererCache** - Flush and close ETS tables

  ### Hot Code Reloading

  DesktopUI supports hot code reloading with the following considerations:

  - ETS tables are owned by dedicated GenServer (RendererCache)
  - Window/Renderer references remain valid across reloads
  - EventLoop state is preserved in GenServer
  - Application state should be serialized in Runtime

  ## Architecture

  ```
  +------------------+
  | User Application |
  +------------------+
           ↓
  +------------------+     +-----------------+
  | DesktopUI.Runtime|←----|DesktopUI.Signals|
  +------------------+     +-----------------+
           ↓
  +------------------+
  | DesktopUI.Elm    | (Behaviour)
  +------------------+
           ↓
  +------------------+     +-----------------+
  |  EventLoop       |←----|Graphics.Cache   |
  +------------------+     +-----------------+
           ↓
  +------------------+     +-----------------+
  | Graphics.Renderer|     |Graphics.Window  |
  +------------------+     +-----------------+
           ↓
  +------------------+
  | DesktopUI.Graphics| (NIF wrapper)
  +------------------+
           ↓
  +------------------+
  | SDL2 (C library) |
  +------------------+
  ```

  ## Usage Example

      # Start runtime
      {:ok, runtime} = DesktopUI.Runtime.start_link()

      # Application automatically running
      # Window created and event loop processing events

      # Stop runtime
      DesktopUI.Runtime.stop(runtime)

  """
end
```

**Testing:**
- Documentation examples should compile
- Verify startup/shutdown sequence is accurate
- Create Mermaid diagram for docs

**Dependencies:** C1-C3 (Architecture refactoring)

---

### E8. Add Stress Tests
**Priority:** LOW
**Complexity:** Medium (2 days)
**Files:** New: `test/desktop_ui/stress_test.exs`

**Problem:**
No testing of system limits and rapid resource cycling.

**Solution:**
Add comprehensive stress tests:

```elixir
defmodule DesktopUI.StressTest do
  use ExUnit.Case, async: false

  @tag :stress
  test "rapid window create/destroy cycles" do
    iterations = 100

    {time, _} = :timer.tc(fn ->
      for i <- 1..iterations do
        {:ok, window} = DesktopUI.Graphics.create_window("Stress#{i}", 640, 480)
        DesktopUI.Graphics.destroy_window(window)
      end
    end)

    avg_time = div(time, iterations) / 1000  # Convert to ms

    # Should average <10ms per cycle
    assert avg_time < 10,
      "Average cycle time too slow: #{Float.round(avg_time, 2)}ms"
  end

  @tag :stress
  test "maximum window creation" do
    # Create as many windows as possible
    windows = Enum.reduce_while(1..1000, [], fn i, acc ->
      case DesktopUI.Graphics.create_window("Max#{i}", 320, 240) do
        {:ok, window} -> {:cont, [window | acc]}
        {:error, _} -> {:halt, acc}
      end
    end)

    # Should create at least 50 windows
    assert length(windows) >= 50,
      "Only created #{length(windows)} windows"

    # Cleanup
    Enum.each(windows, &DesktopUI.Graphics.destroy_window/1)
  end

  @tag :stress
  test "high frequency event polling" do
    {:ok, window} = DesktopUI.Graphics.create_window("Poll Stress", 640, 480)
    {:ok, _renderer} = DesktopUI.Graphics.create_renderer(window)

    # Poll as fast as possible for 1 second
    iterations = Stream.unfold(0, fn count ->
      start = System.monotonic_time(:millisecond)

      events = DesktopUI.Graphics.poll_events()
      elapsed = System.monotonic_time(:millisecond) - start

      if elapsed < 1000 do
        {count + 1, count + 1}
      else
        nil
      end
    end)
    |> Enum.to_list()
    |> List.last()

    # Should handle >100 polls per second
    assert iterations > 100,
      "Only completed #{iterations} polls in 1 second"

    DesktopUI.Graphics.destroy_renderer(window)
    DesktopUI.Graphics.destroy_window(window)
  end
end
```

**Testing:**
- Run stress tests nightly
- Track performance over time
- Add to CI with timeout

**Dependencies:** B2 (Race conditions)
**Related:** D2, E3

---

## Implementation Order & Dependencies

### Week 1: Critical Path
1. **A1** Integration Test Setup (2h) → Unblocks integration testing
2. **A2** Window Dimension Bounds (2h) → No deps
3. **A3** ETS Table Ownership (6h) → Foundation for cache refactoring

### Week 2: Security (Requires Week 1 complete)
4. **B1** Buffer Overflow Protection (3h) → No deps
5. **B2** Slot Management Races (8h) → Foundation for resource management
6. **B3** ETS Access Control (5h) → Requires A3
7. **B4** Poll Interval Validation (2h) → No deps

### Week 3-4: Architecture (Requires Week 2 complete)
8. **C1** Split Graphics Module (3d) → Foundation for all other refactoring
9. **C2** Decouple EventLoop (2d) → Requires C1
10. **C3** Registry Discovery (1d) → Requires C2
11. **C4** Capability Discovery (1d) → Requires C1
12. **C5** Dynamic Resources (3d) → Requires B2, LOW PRIORITY

### Week 5-6: Testing (Requires Week 4 complete)
13. **D1** Visual Verification (4d) → Requires A1
14. **D2** Concurrent Testing (2d) → Requires B2, B3
15. **D3** Failure Injection (2d) → Requires A3
16. **D4** Property-Based Tests (2d) → Requires C1
17. **D5** Assert Receive (1d) → No deps

### Week 7+: Code Quality (Can parallelize)
18. **E1** Color Module (0.5d) → Requires C1
19. **E2** Error Messages (1d) → No deps
20. **E3** Benchmarks (2d) → Requires C1
21. **E4** Telemetry (2d) → No deps
22. **E5** Fuzzing (4d) → Requires D2, D4
23. **E6** Memory Leak Detection (2d) → Requires A3
24. **E7** Lifecycle Docs (1d) → Requires C1-C3
25. **E8** Stress Tests (2d) → Requires B2

---

## Testing Strategy

### Unit Tests
- **Goal:** 100% coverage of public APIs
- **Tools:** ExUnit
- **When:** Continuous

### Integration Tests
- **Goal:** End-to-end workflow validation
- **Tools:** ExUnit, SDL2 fixtures
- **When:** Every PR (requires A1 fix)

### Property-Based Tests
- **Goal:** Explore edge cases
- **Tools:** StreamData, PropCheck
- **When:** Every PR, nightly extended run

### Concurrent Tests
- **Goal:** Find race conditions
- **Tools:** ExUnit, Task.async
- **When:** Every PR

### Visual Tests
- **Goal:** Verify correct rendering
- **Tools:** Screenshot comparison
- **When:** Every PR, visual regression checks

### Fuzzing Tests
- **Goal:** Find NIF boundary bugs
- **Tools:** StreamData, AFL
- **When:** Nightly, before releases

### Performance Tests
- **Goal:** Detect regressions
- **Tools:** Benchee
- **When:** Nightly, before releases

### Stress Tests
- **Goal:** Find system limits
- **Tools:** Custom stress harness
- **When:** Nightly

---

## Risk Assessment

### High Risk Items
1. **A3 ETS Table Ownership** - Core architectural change
   - **Mitigation:** Comprehensive testing, staged rollout
2. **B2 Slot Management** - Locking implementation
   - **Mitigation:** Stress testing, concurrent test suite
3. **C1 Graphics Module Split** - Large refactoring
   - **Mitigation:** Keep compatibility layer, gradual migration
4. **C5 Dynamic Resources** - Complex memory management
   - **Mitigation:** Memory leak detection, fallback to fixed limits

### Medium Risk Items
1. **D1 Visual Verification** - Screenshot comparison can be flaky
   - **Mitigation:** Reasonable tolerance thresholds, fixture management
2. **D4 Property-Based Testing** - May find many edge cases
   - **Mitigation:** Fix blockers first, use for exploration
3. **E5 Fuzzing** - Can generate excessive test cases
   - **Mitigation:** Smart generators, time-boxed runs

### Low Risk Items
- Documentation improvements
- Telemetry addition
- Benchmark suite creation

---

## Success Criteria

### Phase A (Week 1)
- ✅ All 22 integration tests passing
- ✅ Window bounds validated in NIF
- ✅ ETS tables owned by GenServer
- ✅ Hot reload tested and working

### Phase B (Week 2)
- ✅ All buffer overflows prevented
- ✅ No race conditions in concurrent tests
- ✅ Public ETS access controlled
- ✅ All inputs validated

### Phase C (Week 3-4)
- ✅ Graphics module split into 5 modules
- ✅ EventLoop decoupled from renderer
- ✅ Registry-based process discovery
- ✅ Capability queries working

### Phase D (Week 5-6)
- ✅ 90%+ visual test pass rate
- ✅ 1000+ concurrent operations handled
- ✅ All crash paths tested
- ✅ Property tests finding edge cases

### Phase E (Week 7+)
- ✅ Performance baseline established
- ✅ Telemetry emitting events
- ✅ No memory leaks detected
- ✅ Fuzzing finding no crashes

---

## Estimated Timeline

| Phase | Duration | Dependencies | Complete |
|-------|----------|--------------|----------|
| Phase A: Blockers | 1 week | None | Week 1 |
| Phase B: Security | 1 week | Phase A | Week 2 |
| Phase C: Architecture | 2 weeks | Phase B | Week 4 |
| Phase D: Testing | 2 weeks | Phase C | Week 6 |
| Phase E: Quality | Ongoing | Phase D | Week 7+ |

**Total:** 6 weeks to complete all HIGH and MEDIUM priority items

**Minimal Viable Fix:** 2 weeks (Phases A + B only)

---

## Next Steps

1. **Immediate (Today):** Fix A1 integration test setup
2. **This Week:** Complete Phase A (all 3 blockers)
3. **Next Week:** Complete Phase B (security hardening)
4. **Planning:** Schedule Phases C-E based on team availability

---

**Document Version:** 1.0
**Last Updated:** 2026-01-25
**Status:** Ready for Implementation
