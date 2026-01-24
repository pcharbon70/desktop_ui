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
  - Validate widget trees before rendering
  - Pass validated trees to the renderer module
  - Handle RenderRequest signals for forced redraws
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
                                                    Validate widget tree
                                                          ↓
                                                    Pass to renderer
  ```

  ## Usage

  Start the coordinator with a renderer module:

      {:ok, pid} = DesktopUI.RenderingCoordinator.start_link(
        renderer: DesktopUI.Renderer.Mock,
        bus: :desktop_ui,
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

  ## Component Registration

  Components must be registered with the coordinator before they will
  be rendered on state changes. Registration includes:
  - `component_id` - Unique identifier for the component
  - `module` - The component module (must implement DesktopUI.Elm)
  - `pid` - The component agent's PID (optional, for RenderRequest support)

  """

  alias DesktopUI.Widget

  use GenServer
  require Logger

  # ETS table for component registry (persisted across GenServer callbacks)
  @components_table :desktop_ui_rendering_coordinator_components
  @metrics_table :desktop_ui_rendering_coordinator_metrics

  @doc """
  Start the RenderingCoordinator.
  """
  def start_link(opts) do
    {name_opts, opts} = Keyword.pop(opts, :name, nil)
    GenServer.start_link(__MODULE__, opts, name: name_opts)
  end

  @impl true
  def init(opts) do
    # Extract options
    bus = Keyword.get(opts, :bus, :desktop_ui)
    renderer = Keyword.get(opts, :renderer, __MODULE__.NoOpRenderer)

    # Create ETS tables
    ensure_ets_tables(bus: bus, renderer: renderer)

    # Subscribe to all desktop_ui signals
    case Jido.Signal.Bus.subscribe(
           bus,
           "desktop_ui.**",
           dispatch: {:pid, target: self()}
         ) do
      {:ok, _sub} ->
        {:ok, %{bus: bus, renderer: renderer, subscribed: true}}

      {:error, _reason} ->
        {:ok, %{bus: bus, renderer: renderer, subscribed: false}}
    end
  end

  # Ensure ETS tables exist (call this before using them)
  defp ensure_ets_tables(opts \\ []) do
    table_opts = [
      :named_table,
      :set,
      :protected,
      read_concurrency: true
    ]

    # Create components table if it doesn't exist
    case :ets.whereis(@components_table) do
      :undefined -> :ets.new(@components_table, table_opts)
      _ -> :already_exists
    end

    # Create metrics table if it doesn't exist
    case :ets.whereis(@metrics_table) do
      :undefined -> :ets.new(@metrics_table, table_opts)
      _ -> :already_exists
    end

    # Store configuration if provided
    if opts != [] do
      bus = Keyword.get(opts, :bus, :desktop_ui)
      renderer = Keyword.get(opts, :renderer, __MODULE__.NoOpRenderer)
      :ets.insert(@metrics_table, {:bus, bus})
      :ets.insert(@metrics_table, {:renderer, renderer})
    end

    :ok
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

  # Private Functions

  # Handle a state change signal from a component
  defp handle_state_change(_state, component_id, new_elm_state) do
    case :ets.lookup(@components_table, component_id) do
      [] ->
        # Component not registered - skip
        :ok

      [{^component_id, component_info}] ->
        renderer = get_metric(:renderer, __MODULE__.NoOpRenderer)
        render_component(component_id, component_info, new_elm_state, renderer)
    end
  end

  # Handle a render request signal
  defp handle_render_request(_state, component_id, _force) do
    case :ets.lookup(@components_table, component_id) do
      [] ->
        # Component not registered - skip
        :ok

      [{^component_id, component_info}] ->
        if component_info.pid do
          case get_component_elm_state(component_info.pid) do
            {:ok, elm_state} ->
              renderer = get_metric(:renderer, __MODULE__.NoOpRenderer)
              render_component(component_id, component_info, elm_state, renderer)

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

  # Render a component by calling its view/1 function
  defp render_component(component_id, component_info, elm_state, renderer) do
    module = component_info.module

    # Call the component's view/1 function
    try do
      widget = apply(module, :view, [elm_state])

      # Validate the widget tree
      case Widget.validate(widget) do
        :ok ->
          # Pass to renderer
          render_widget(renderer, component_id, widget)

          # Update metrics in ETS
          increment_metric(:renders_completed)

          :ets.insert(
            @components_table,
            {component_id, Map.put(component_info, :last_rendered, DateTime.utc_now())}
          )

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
  defp increment_metric(metric_name) do
    case :ets.lookup(@metrics_table, metric_name) do
      [{^metric_name, count}] ->
        :ets.insert(@metrics_table, {metric_name, count + 1})

      [] ->
        # Metric doesn't exist yet, initialize to 1
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
      case Jido.Agent.Server.state(pid) do
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

  # Check if a module implements DesktopUI.Elm behaviour
  defp component_module?(module) when is_atom(module) do
    # Check if module has the required DesktopUI.Elm callbacks
    function_exported?(module, :init, 1) and
      function_exported?(module, :update, 2) and
      function_exported?(module, :view, 1) and
      function_exported?(module, :on_signal, 2)
  end

  defp component_module?(_), do: false

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
