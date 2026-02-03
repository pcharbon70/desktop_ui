defmodule DesktopUI.RenderingCoordinator do
  @moduledoc """
  GenServer that coordinates rendering of UI components.

  The RenderingCoordinator subscribes to component state changes and
  orchestrates the rendering pipeline. It acts as the bridge between
  component state changes and actual rendering.

  ## Responsibilities

  - Subscribe to component StateChanged signals
  - Track registered components (PID, module, metadata)
  - Call component's view/1 when state changes
  - Calculate layout for widget trees
  - Store layouts for hit testing and caching
  - Validate widget trees before rendering
  - Pass validated layouts to the renderer module
  - Handle RenderRequest signals for forced redraws
  - Handle WindowResized signals for layout recalculation
  - Track render metrics

  ## Architecture

  The coordinator follows a signal-based architecture:

  ```
  Component state changes → StateChanged signal → Coordinator
                                                          ↓
                                                    Look up component
                                                          ↓
                                                    Call view/1
                                                          ↓
                                                    Calculate UI tree version
                                                          ↓
                              ┌─────────────────────────┴─────────────────────────┐
                              │  UI tree changed?                               │
                              │  Yes → Calculate layout                         │
                              │  No  → Use cached layout                        │
                              └─────────────────────────────────────────────┘
                                                          ↓
                                                    Store layout in ETS
                                                          ↓
                                                    Render with layout
  ```

  ## Window Resize Handling

  When the window is resized, the coordinator:
  1. Receives WindowResized signal with new dimensions
  2. Updates stored window bounds
  3. Triggers layout recalculation for all components
  4. Components re-render with new layout

  ## Usage

  Start the coordinator with a renderer module and optional window bounds:

      {:ok, pid} = DesktopUI.RenderingCoordinator.start_link(
        renderer: DesktopUI.Renderer.Mock,
        bus: :desktop_ui,
        window_width: 800,
        window_height: 600,
        name: :rendering_coordinator
      )

  Register components by publishing a ComponentRegister signal:

      {:ok, signal} = DesktopUI.Signals.ComponentRegister.new(%{
        component_id: "counter_123",
        module: MyCounterComponent,
        pid: component_pid
      })
      Jido.Signal.Bus.publish(:desktop_ui, [signal])

  Or use the convenience function:

      {:ok, _signal} = DesktopUI.RenderingCoordinator.register_component(
        coordinator_pid,
        "counter_123",
        MyCounterComponent,
        pid: component_pid
      )

  Perform hit testing on the current layout:

      DesktopUI.RenderingCoordinator.hit_test("counter_123", 100, 50)
      #=> {:ok, %{widget_id: :btn_inc, on_click: :increment}}

  ## Component Registration

  Components must be registered with the coordinator before they will
  be rendered on state changes. Registration includes:
  - `component_id` - Unique identifier for the component
  - `module` - The component module (must implement DesktopUI.Elm)
  - `pid` - The component agent's PID (optional, for RenderRequest support)

  ## Layout Caching

  The coordinator caches layouts based on UI tree version:
  - First render: Calculates layout and stores in ETS
  - Subsequent renders with unchanged UI: Reuses cached layout
  - UI tree changes: Recalculates layout and updates cache
  - Window resize: Forces layout recalculation for all components

  ## ETS Table Usage

  The coordinator uses three ETS tables for high-performance concurrent access:

  ### Tables

  - `@components_table` - Component registry: `{component_id, component_info}`
  - `@metrics_table` - Metrics and configuration: `{key, value}`
  - `@layouts_table` - Layout cache: `{{component_id, "current"}, layout}`

  ### Access Patterns

  **Read Operations** (any process):
  - Component lookup via `get_components/1`
  - Layout retrieval for hit testing via `hit_test/3`
  - Metrics queries via `get_metrics/1`

  **Write Operations** (coordinator only):
  - Component registration/unregistration
  - Layout storage and updates
  - Metric increments (atomic via `update_counter/3`)

  ### Concurrency

  Tables use `:protected` access mode:
  - Owner (coordinator) has read/write access
  - Other processes have read-only access
  - Prevents unauthorized writes and data corruption

  ### Security

  - Size limits prevent unbounded growth (DoS protection)
  - Oldest entries evicted when limits exceeded
  - Orphaned table detection and cleanup on startup

  ### Performance

  - ETS provides O(1) key-based lookups
  - Layout cache reduces redundant calculations
  - Atomic counters prevent race conditions in metrics

  """

  alias DesktopUI.{Layout, Widget}

  use GenServer
  require Logger

  # ETS table for component registry (persisted across GenServer callbacks)
  @components_table :desktop_ui_rendering_coordinator_components
  @metrics_table :desktop_ui_rendering_coordinator_metrics
  @layouts_table :desktop_ui_rendering_coordinator_layouts

  # SECURITY: Maximum ETS table sizes to prevent DoS via unbounded growth
  # These are soft limits - when exceeded, oldest entries are evicted
  # Note: Metrics table has bounded keys (renders_completed, renders_failed, renders_skipped, window_bounds)
  @max_components 1000
  @max_layouts 500

  @doc """
  Start the RenderingCoordinator.
  """
  def start_link(opts) do
    {name_opts, opts} = Keyword.pop(opts, :name, nil)
    GenServer.start_link(__MODULE__, opts, name: name_opts)
  end

  # Minimum and maximum window bounds (8K resolution)
  @min_window_width 100
  @min_window_height 100
  @max_window_width 7680
  @max_window_height 4320

  # Validate window dimension is within acceptable bounds
  # Clamps values to prevent extreme window sizes that could cause rendering issues
  defp validate_window_dimension(value, min, max, dimension) when is_integer(value) do
    cond do
      value < min ->
        Logger.warning(
          "Window #{dimension} (#{value}) below minimum (#{min}), using minimum instead"
        )

        min

      value > max ->
        Logger.warning(
          "Window #{dimension} (#{value}) above maximum (#{max}), using maximum instead"
        )

        max

      true ->
        value
    end
  end

  # Handle non-integer values by falling back to defaults
  defp validate_window_dimension(_value, _min, max, dimension) do
    Logger.warning("Invalid window #{dimension}, using default: #{max}")
    max
  end

  @impl true
  def init(opts) do
    # Extract options
    bus = Keyword.get(opts, :bus, :desktop_ui)
    renderer = Keyword.get(opts, :renderer, __MODULE__.NoOpRenderer)
    window_width = Keyword.get(opts, :window_width, 800)
    window_height = Keyword.get(opts, :window_height, 600)

    # Validate and clamp window bounds to prevent extreme values
    window_width = validate_window_dimension(window_width, @min_window_width, @max_window_width, :width)
    window_height = validate_window_dimension(window_height, @min_window_height, @max_window_height, :height)

    # Create ETS tables
    ensure_ets_tables()

    # Initialize window bounds in ETS if we're the table owner
    # This allows the first coordinator to set the initial bounds for sharing
    if table_owner?(@metrics_table) do
      :ets.insert(@metrics_table, {:window_bounds, %{width: window_width, height: window_height}})
    end

    # Store window bounds in state for this coordinator instance
    # Each coordinator has its own validated bounds in its state
    initial_state = %{
      bus: bus,
      renderer: renderer,
      subscribed: false,
      window_width: window_width,
      window_height: window_height
    }

    # Subscribe to all desktop_ui signals
    case Jido.Signal.Bus.subscribe(
           bus,
           "desktop_ui.**",
           dispatch: {:pid, target: self()}
         ) do
      {:ok, _sub} ->
        {:ok, %{initial_state | subscribed: true}}

      {:error, _reason} ->
        {:ok, initial_state}
    end
  end

  # Ensure ETS tables exist (call this before using them)
  # SECURITY: Using :protected access instead of :public to prevent unauthorized writes
  # Only the owner process (RenderingCoordinator) can write to these tables
  # Other processes can read but not modify, preventing DoS via data corruption
  defp ensure_ets_tables do
    table_opts = [
      :named_table,
      :set,
      :protected,
      read_concurrency: true
    ]

    # Handle each table - check if exists, if owned by dead process, delete and recreate
    ensure_table(@components_table, table_opts)
    ensure_table(@metrics_table, table_opts)
    ensure_table(@layouts_table, table_opts)

    :ok
  end

  # Ensure a single ETS table exists and is owned by a live process
  # If table exists but is owned by a dead process, delete it and recreate
  # SECURITY: Only attempt to delete tables if we're the owner (to prevent permission errors)
  defp ensure_table(table_name, opts) do
    case :ets.whereis(table_name) do
      :undefined ->
        # Table doesn't exist, create it (we become owner)
        :ets.new(table_name, opts)

      owner_pid when is_pid(owner_pid) ->
        # Table exists, check if we're the owner
        if owner_pid == self() do
          # We own this table, already initialized
          :already_exists
        else
          # Another process owns this table
          if Process.alive?(owner_pid) do
            # Owner is alive (and not us), reuse existing table
            :already_exists
          else
            # Owner is dead, try to delete orphaned table and recreate (we become new owner)
            # Note: This may fail if the table has a heir, but that's acceptable
            try do
              :ets.delete(table_name)
              :ets.new(table_name, opts)
            rescue
              ArgumentError -> :already_exists
            end
          end
        end

      _ ->
        # Table has some other owner type (heir, etc), just use it as-is
        # We can't delete it, and we shouldn't recreate it
        :already_exists
    end
  end

  # Check if the current process owns the given ETS table
  defp table_owner?(table_name) do
    case :ets.whereis(table_name) do
      :undefined -> false
      pid when is_pid(pid) -> pid == self()
      _ -> false  # heir or other reference types
    end
  end

  # Evict entries from a table if it exceeds its maximum size
  # SECURITY: Prevents DoS via unbounded ETS table growth
  defp maybe_evict_oldest(table_name, max_size) do
    current_size = :ets.info(table_name, :size)

    if current_size >= max_size do
      # Table is at or over limit, evict all entries using select_delete
      # This effectively resets the table when it exceeds its limit
      match_spec = [{{:"$1", :"$2"}, [], [true]}]

      evicted = :ets.select_delete(table_name, match_spec)

      if evicted > 0 do
        Logger.warning(
          "Evicted #{evicted} entries from #{table_name} (size: #{current_size}, max: #{max_size})"
        )
      end

      :ok
    else
      :ok
    end
  end

  @impl true
  def handle_info({:signal, %Jido.Signal{type: "desktop_ui.state.changed"} = signal}, state) do
    component_id = signal.data.component_id
    new_elm_state = signal.data.new_state

    handle_state_change(state, component_id, new_elm_state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:signal, %Jido.Signal{type: "desktop_ui.render.request"} = signal}, state) do
    component_id = signal.data.component_id
    force = Map.get(signal.data, :force, false)

    handle_render_request(state, component_id, force)
    {:noreply, state}
  end

  @impl true
  def handle_info({:signal, %Jido.Signal{type: "desktop_ui.component.register"} = signal}, state) do
    component_id = signal.data.component_id
    module = signal.data.module
    pid = Map.get(signal.data, :pid)

    # Validate that the module implements DesktopUI.Elm behaviour
    if not component_module?(module) do
      # Log warning and skip registration
      {:noreply, state}
    else
      component_info = %{
        module: module,
        pid: pid,
        registered_at: DateTime.utc_now()
      }

      # Check table size and evict if needed before inserting
      maybe_evict_oldest(@components_table, @max_components)

      # Store in ETS table for persistence
      :ets.insert(@components_table, {component_id, component_info})

      {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        {:signal, %Jido.Signal{type: "desktop_ui.component.unregister"} = signal},
        state
      ) do
    component_id = signal.data.component_id

    # Remove from ETS table
    :ets.delete(@components_table, component_id)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:signal, %Jido.Signal{type: "desktop_ui.window.resized"} = signal},
        state
      ) do
    width = signal.data.width
    height = signal.data.height

    # Update stored window bounds
    :ets.insert(@metrics_table, {:window_bounds, %{width: width, height: height}})

    # Trigger layout recalculation for all registered components
    trigger_layout_recalculation(state.bus)

    {:noreply, state}
  end

  @impl true
  def handle_info({:signal, _signal}, state) do
    # Ignore other signals
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Public API

  @doc """
  Register a component for rendering.

  ## Parameters

  - `coordinator_pid` - PID of the RenderingCoordinator (unused, kept for API compatibility)
  - `component_id` - Unique identifier for the component
  - `module` - The component module (must implement DesktopUI.Elm)
  - `opts` - Optional keyword list of metadata

  ## Options

  - `:bus` - Signal bus name (default: :desktop_ui)
  - `:pid` - Component agent PID (optional, for RenderRequest support)

  ## Returns

  `{:ok, signal}` or `{:error, reason}`

  """
  @spec register_component(pid(), String.t(), atom(), keyword()) ::
          {:ok, Jido.Signal.t()} | {:error, term()}
  def register_component(_coordinator_pid, component_id, module, opts \\ []) do
    bus = Keyword.get(opts, :bus, :desktop_ui)

    # Build signal data
    data = [
      component_id: component_id,
      module: module
    ]

    data =
      if pid = Keyword.get(opts, :pid) do
        Keyword.put(data, :pid, pid)
      else
        data
      end

    # Create and publish the registration signal
    case DesktopUI.Signals.ComponentRegister.new(data) do
      {:ok, signal} ->
        Jido.Signal.Bus.publish(bus, [signal])
        {:ok, signal}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Unregister a component from rendering.

  ## Parameters

  - `coordinator_pid` - PID of the RenderingCoordinator (unused, kept for API compatibility)
  - `component_id` - Unique identifier for the component
  - `opts` - Optional keyword list

  ## Options

  - `:bus` - Signal bus name (default: :desktop_ui)

  ## Returns

  `{:ok, signal}` or `{:error, reason}`

  """
  @spec unregister_component(pid(), String.t(), keyword()) ::
          {:ok, Jido.Signal.t()} | {:error, term()}
  def unregister_component(_coordinator_pid, component_id, opts \\ []) do
    bus = Keyword.get(opts, :bus, :desktop_ui)

    case DesktopUI.Signals.ComponentUnregister.new(%{component_id: component_id}) do
      {:ok, signal} ->
        Jido.Signal.Bus.publish(bus, [signal])
        {:ok, signal}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get render metrics from the coordinator.

  ## Parameters

  - `coordinator_pid` - PID of the RenderingCoordinator (unused, kept for API compatibility)

  ## Returns

  Map with keys:
  - `:renders_completed` - Number of successful renders
  - `:renders_failed` - Number of failed renders
  - `:renders_skipped` - Number of skipped renders

  """
  @spec get_metrics(pid()) :: map()
  def get_metrics(_coordinator_pid) do
    # Ensure ETS tables exist first
    ensure_ets_tables()

    %{
      renders_completed: get_metric(:renders_completed, 0),
      renders_failed: get_metric(:renders_failed, 0),
      renders_skipped: get_metric(:renders_skipped, 0)
    }
  end

  @doc """
  Get registered components.

  ## Parameters

  - `coordinator_pid` - PID of the RenderingCoordinator (unused, kept for API compatibility)

  ## Returns

  Map of component_id => component_info

  """
  @spec get_components(pid()) :: map()
  def get_components(_coordinator_pid) do
    # Ensure ETS tables exist first
    ensure_ets_tables()

    # Read all components from ETS table
    :ets.tab2list(@components_table)
    |> Enum.into(%{})
  end

  @doc """
  Get the window bounds for a coordinator.

  ## Parameters

  - `coordinator_pid` - PID of the RenderingCoordinator

  ## Returns

  Map with `:width` and `:height` keys

  ## Examples

      {:ok, pid} = DesktopUI.RenderingCoordinator.start_link([])
      bounds = DesktopUI.RenderingCoordinator.get_window_bounds(pid)
      #=> %{width: 800, height: 600}

  """
  @spec get_window_bounds(pid()) :: %{width: pos_integer(), height: pos_integer()}
  def get_window_bounds(coordinator_pid) do
    state = :sys.get_state(coordinator_pid)
    %{width: state.window_width, height: state.window_height}
  end

  @doc """
  Hit test for a component's current layout.

  This function performs a hit test on the stored layout tree for a component
  to determine which widget was clicked at the given position.

  Returns `{:ok, %{widget_id: id, on_click: message}}` for interactive widgets,
  or `nil` if no widget was found at the position.

  ## Parameters

  - `component_id` - The component to test
  - `x` - X coordinate
  - `y` - Y coordinate

  ## Examples

      DesktopUI.RenderingCoordinator.hit_test("counter_123", 100, 50)
      #=> {:ok, %{widget_id: :btn_inc, on_click: :increment}}

      DesktopUI.RenderingCoordinator.hit_test("counter_123", 9999, 9999)
      #=> nil

  """
  @spec hit_test(String.t(), non_neg_integer(), non_neg_integer()) ::
    {:ok, %{widget_id: atom(), on_click: term()}} | nil
  def hit_test(component_id, x, y) do
    ensure_ets_tables()

    case :ets.lookup(@layouts_table, {component_id, "current"}) do
      [{{_key, "current"}, layout}] ->
        Layout.hit_test(layout, x, y)

      [] ->
        nil
    end
  end

  # Private Functions

  # Handle a state change signal from a component
  defp handle_state_change(state, component_id, new_elm_state) do
    case :ets.lookup(@components_table, component_id) do
      [] ->
        # Component not registered - skip
        :ok

      [{^component_id, component_info}] ->
        render_component(component_id, component_info, new_elm_state, state.renderer, state.bus)
    end
  end

  # Handle a render request signal
  defp handle_render_request(state, component_id, force) do
    case :ets.lookup(@components_table, component_id) do
      [] ->
        # Component not registered - skip
        :ok

      [{^component_id, component_info}] ->
        if component_info.pid do
          case get_component_elm_state(component_info.pid) do
            {:ok, elm_state} ->
              # If force is true, bypass version checking
              if force do
                force_render_component(component_id, component_info, elm_state, state.renderer)
              else
                render_component(component_id, component_info, elm_state, state.renderer, state.bus)
              end

            :error ->
              # Couldn't get state - skip but log
              :ok
          end
        else
          # No PID to query - skip
          :ok
        end
    end
  end

  # Force render component (bypass version checking)
  # Used when window is resized or layout needs to be recalculated
  defp force_render_component(component_id, component_info, elm_state, renderer) do
    module = component_info.module

    try do
      widget = apply(module, :view, [elm_state])

      case Widget.validate(widget) do
        :ok ->
          available_bounds = get_available_bounds()

          # Always calculate new layout when forced
          case Layout.calculate(widget, available_bounds) do
            {:ok, layout} ->
              # Check table size and evict if needed before inserting
              maybe_evict_oldest(@layouts_table, @max_layouts)

              :ets.insert(@layouts_table, {{component_id, "current"}, layout})
              render_widget_with_layout(renderer, component_id, layout)
              increment_metric(:renders_completed)

              # Update version and timestamp
              ui_tree_version = calculate_ui_tree_version(widget)
              updated_info =
                component_info
                |> Map.put(:ui_tree_version, ui_tree_version)
                |> Map.put(:last_rendered, DateTime.utc_now())

              :ets.insert(@components_table, {component_id, updated_info})

              :ok

            {:error, reason} ->
              Logger.warning("Layout calculation failed for component #{component_id}: #{inspect(reason)}")
              render_widget(renderer, component_id, widget)
              increment_metric(:renders_completed)
              :ok
          end

        {:error, reason} ->
          Logger.warning("Widget validation failed for component #{component_id}: #{inspect(reason)}")
          increment_metric(:renders_failed)
          :ok
      end
    rescue
      error ->
        Logger.error("Force render error for component #{component_id}: #{inspect(error)}")
        increment_metric(:renders_failed)
        :ok
    end
  end

  # Render a component by calling its view/1 function
  defp render_component(component_id, component_info, elm_state, renderer, _bus) do
    module = component_info.module

    # Call the component's view/1 function
    try do
      widget = apply(module, :view, [elm_state])

      # Calculate UI tree version for change detection
      ui_tree_version = calculate_ui_tree_version(widget)
      current_version = Map.get(component_info, :ui_tree_version, nil)

      # Validate the widget tree
      case Widget.validate(widget) do
        :ok ->
          # Get available bounds from ETS (updated on window resize)
          available_bounds = get_available_bounds()

          # Check if we can reuse cached layout
          if ui_tree_version == current_version do
            # UI tree unchanged - try to reuse cached layout
            case :ets.lookup(@layouts_table, {component_id, "current"}) do
              [{{_key, "current"}, cached_layout}] ->
                # Render with cached layout
                render_widget_with_layout(renderer, component_id, cached_layout)
                increment_metric(:renders_completed)

              [] ->
                # No cached layout - must calculate
                calculate_and_store_layout(
                  component_id,
                  widget,
                  available_bounds,
                  ui_tree_version,
                  renderer
                )
            end
          else
            # UI tree changed - calculate new layout
            calculate_and_store_layout(
              component_id,
              widget,
              available_bounds,
              ui_tree_version,
              renderer
            )
          end

          # Update component info with new version and timestamp
          updated_info =
            component_info
            |> Map.put(:ui_tree_version, ui_tree_version)
            |> Map.put(:last_rendered, DateTime.utc_now())

          :ets.insert(@components_table, {component_id, updated_info})

          :ok

        {:error, reason} ->
          # Log validation error but don't crash
          Logger.warning("Widget validation failed for component #{component_id}: #{inspect(reason)}")
          increment_metric(:renders_failed)
          :ok
      end
    rescue
      error ->
        # Handle any errors from view/1 or rendering
        Logger.error("Render error for component #{component_id}: #{inspect(error)}")
        increment_metric(:renders_failed)
        :ok
    end
  end

  # Helper to increment a metric counter in ETS
  # Uses atomic :ets.update_counter/3 to prevent race conditions
  defp increment_metric(metric_name) do
    try do
      # Atomically increment the counter at position 2 of the tuple
      # If key doesn't exist, this will raise an exception
      :ets.update_counter(@metrics_table, metric_name, {2, 1})
    rescue
      ArgumentError ->
        # Key doesn't exist, initialize to 1
        # Note: This still has a small race window but is much better than before
        :ets.insert(@metrics_table, {metric_name, 1})
    end
  end

  # Helper to get a metric value from ETS (public for testing)
  def get_metric(metric_name, default \\ 0) do
    case :ets.lookup(@metrics_table, metric_name) do
      [{^metric_name, value}] -> value
      [] -> default
    end
  end

  # Get a component's elm state via its agent server
  defp get_component_elm_state(pid) when is_pid(pid) do
    try do
      case Jido.AgentServer.state(pid) do
        {:ok, server_state} ->
          agent = server_state.agent
          elm_state = Map.get(agent.state, :elm_state)

          if is_nil(elm_state) do
            :error
          else
            {:ok, elm_state}
          end

        _ ->
          :error
      end
    rescue
      error ->
        Logger.debug("Failed to get elm_state from agent: #{inspect(error)}")
        :error
    end
  end

  defp get_component_elm_state(_), do: :error

  # Pass widget to renderer module or named process
  defp render_widget(renderer, component_id, widget) do
    case renderer do
      {module, name} when is_atom(module) and is_atom(name) ->
        # Call with process name (for stateful renderers like MockRenderer)
        if function_exported?(module, :render, 3) do
          apply(module, :render, [component_id, widget, name])
        else
          :ok
        end

      module when is_atom(module) ->
        # Call module directly (for stateless renderers like NoOpRenderer)
        if function_exported?(module, :render, 2) do
          apply(module, :render, [component_id, widget])
        else
          :ok
        end

      _ ->
        :ok
    end
  end

  # Calculate a version/hash of the widget tree for change detection
  # Uses :erlang.phash2/1 for fast structural comparison
  defp calculate_ui_tree_version(widget) do
    :erlang.phash2(widget)
  end

  # Calculate layout and store it in ETS, then render with the layout
  defp calculate_and_store_layout(component_id, widget, available_bounds, _ui_tree_version, renderer) do
    case Layout.calculate(widget, available_bounds) do
      {:ok, layout} ->
        # Check table size and evict if needed before inserting
        maybe_evict_oldest(@layouts_table, @max_layouts)

        # Store layout for hit testing
        :ets.insert(@layouts_table, {{component_id, "current"}, layout})

        # Render with the calculated layout
        render_widget_with_layout(renderer, component_id, layout)
        increment_metric(:renders_completed)

      {:error, reason} ->
        # Layout calculation failed - fall back to widget rendering
        Logger.warning("Layout calculation failed for component #{component_id}: #{inspect(reason)}")
        render_widget(renderer, component_id, widget)
        increment_metric(:renders_completed)
    end
  end

  # Render widget with pre-calculated layout
  # This is the preferred rendering path as layout is calculated once
  defp render_widget_with_layout(renderer, component_id, layout) do
    case renderer do
      {module, name} when is_atom(module) and is_atom(name) ->
        # Try render_with_layout first (preferred), fall back to render
        if function_exported?(module, :render_with_layout, 3) do
          apply(module, :render_with_layout, [component_id, layout, name])
        else
          # Fallback: render with widget extracted from layout
          widget = layout.widget
          if function_exported?(module, :render, 3) do
            apply(module, :render, [component_id, widget, name])
          else
            :ok
          end
        end

      module when is_atom(module) ->
        # Try render_with_layout first (preferred), fall back to render
        if function_exported?(module, :render_with_layout, 2) do
          apply(module, :render_with_layout, [component_id, layout])
        else
          # Fallback: render with widget extracted from layout
          widget = layout.widget
          if function_exported?(module, :render, 2) do
            apply(module, :render, [component_id, widget])
          else
            :ok
          end
        end

      _ ->
        :ok
    end
  end

  # Check if a module implements DesktopUI.Elm behaviour
  defp component_module?(module) when is_atom(module) do
    # Check if module has the required DesktopUI.Elm callbacks
    function_exported?(module, :init, 1) and
      function_exported?(module, :update, 2) and
      function_exported?(module, :view, 1) and
      function_exported?(module, :on_signal, 2)
  end

  defp component_module?(_), do: false

  # Get available bounds for layout calculation
  # Reads from ETS where window bounds are stored (updated on resize)
  defp get_available_bounds do
    case :ets.lookup(@metrics_table, :window_bounds) do
      [{:window_bounds, bounds}] ->
        bounds

      [] ->
        # Default bounds if not set (fallback)
        %{width: 800, height: 600}
    end
  end

  # Trigger layout recalculation for all registered components
  # Called when window is resized to ensure all widgets are re-laid out
  defp trigger_layout_recalculation(bus) do
    # Get all registered components
    components = :ets.tab2list(@components_table)

    # Publish RenderRequest signal for each component with force: true
    Enum.each(components, fn {component_id, _component_info} ->
      case DesktopUI.Signals.RenderRequest.new(%{
        component_id: component_id,
        force: true
      }) do
        {:ok, signal} ->
          Jido.Signal.Bus.publish(bus, [signal])

        {:error, _reason} ->
          :ok
      end
    end)
  end

  # No-op renderer for testing/development
  defmodule NoOpRenderer do
    @moduledoc """
    No-op renderer that accepts render calls but does nothing.
    Used as the default renderer when none is specified.
    """

    @doc """
    Render a widget tree (no-op implementation).
    """
    def render(_component_id, _widget) do
      :ok
    end
  end
end
