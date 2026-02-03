defmodule DesktopUI.Runtime do
  @moduledoc """
  Bootstrap supervisor and event bridge for DesktopUI applications.

  The Runtime is NOT a central orchestrator—agents are autonomous and
  communicate via signals. The Runtime's responsibilities are:

  1. **Bootstrap**: Start the supervision tree with signal bus, renderer, and components
  2. **Event Bridge**: Convert external events (SDL, keyboard, etc.) to Jido signals
  3. **Lifecycle Management**: Ensure clean startup and shutdown of all processes

  ## Architecture

  The Runtime uses a Supervisor to manage children:

  ```
  DesktopUI.Runtime (Supervisor)
    ├── Jido.Signal.Bus (:desktop_ui)
    ├── RenderingCoordinator
    └── Root Component (Jido.Agent)
  ```

  ## Usage

  Start the runtime with a root component:

      {:ok, pid} = DesktopUI.Runtime.start_link(
        root_component: MyCounterComponent,
        renderer: DesktopUI.Renderer.Mock,
        bus: :desktop_ui
      )

  Or include in your application supervisor:

      children = [
        {DesktopUI.Runtime,
          root_component: MyCounterComponent,
          renderer: DesktopUI.Renderer.Mock,
          bus: :desktop_ui
        }
      ]

  ## Root Component Requirements

  The root component must:
  - Use `DesktopUI.Elm` (which includes `use Jido.Agent`)
  - Implement `init/1`, `update/2`, and `view/1` callbacks
  - Be startable via `Jido.AgentServer.start_link/2`

  ## Event Bridge

  Bridge external events to signals:

      # Keyboard event
      DesktopUI.Runtime.bridge_event({:sdl_keydown, key: :up, mod: []})

      # Mouse event (with optional target_id from hit testing)
      DesktopUI.Runtime.bridge_event(
        {:sdl_mouseup, x: 100, y: 50, button: :left, target_id: :btn_click}
      )

      # Quit event
      DesktopUI.Runtime.bridge_event({:sdl_quit})

  """

  use GenServer
  alias DesktopUI.Signals

  @type option ::
          {:root_component, module()}
          | {:root_component_opts, keyword()}
          | {:renderer, atom() | {atom(), atom()}}
          | {:bus, atom()}
          | {:name, atom()}
          | {:window_title, String.t()}
          | {:window_width, pos_integer()}
          | {:window_height, pos_integer()}
          | {:fullscreen, boolean()}
          | {:event_polling, boolean()}
          | {:poll_interval, pos_integer()}

  # Client API

  @doc """
  Start the Runtime supervisor.

  ## Options

  * `:root_component` - The root component module (must implement DesktopUI.Elm) (required)
  * `:root_component_opts` - Options to pass to root component's init/1 (default: [])
  * `:renderer` - Renderer module or {module, name} tuple (default: DesktopUI.Renderer.SDL2)
  * `:bus` - Signal bus name (default: :desktop_ui)
  * `:name` - Runtime process name (optional)
  * `:window_title` - SDL2 window title (default: "DesktopUI App")
  * `:window_width` - SDL2 window width (default: 800)
  * `:window_height` - SDL2 window height (default: 600)
  * `:fullscreen` - SDL2 fullscreen mode (default: false)
  * `:event_polling` - Enable SDL2 event polling (default: true)
  * `:poll_interval` - Event poll interval in ms (default: 16, ~60 FPS)

  ## Examples

      # With SDL2 graphics (default)
      {:ok, pid} = DesktopUI.Runtime.start_link(
        root_component: MyCounterComponent,
        window_title: "My App",
        window_width: 800,
        window_height: 600
      )

      # With mock renderer (for testing)
      {:ok, pid} = DesktopUI.Runtime.start_link(
        root_component: MyCounterComponent,
        renderer: DesktopUI.Renderer.Mock,
        event_polling: false
      )

  """
  @spec start_link([option]) :: GenServer.on_start()
  def start_link(opts) do
    {name_opts, opts} = Keyword.pop(opts, :name, nil)
    GenServer.start_link(__MODULE__, opts, name: name_opts)
  end

  @doc """
  Bridge an external event to a Jido signal.

  Converts SDL-style event tuples to Jido signals and publishes them
  to the signal bus.

  ## Supported Events

  * `{:sdl_keydown, key: key, mod: modifiers}` - Key press event
  * `{:sdl_keyup, key: key, mod: modifiers}` - Key release event
  * `{:sdl_mouseup, x: x, y: y, button: button, target_id: target_id}` - Mouse click
  * `{:sdl_mousedown, x: x, y: y, button: button, target_id: target_id}` - Mouse press
  * `{:sdl_mousemove, x: x, y: y}` - Mouse movement
  * `{:sdl_quit}` - Application quit event

  ## Parameters

  * `event` - Event tuple describing the external event
  * `opts` - Optional keyword list
    * `:bus` - Signal bus name to use (default: :desktop_ui)

  ## Returns

  `:ok` or `{:error, reason}`

  ## Examples

      # Bridge keyboard event to default bus
      DesktopUI.Runtime.bridge_event({:sdl_keydown, key: :up, mod: []})

      # Bridge keyboard event to custom bus
      DesktopUI.Runtime.bridge_event({:sdl_keydown, key: :up, mod: []}, bus: :my_bus)

  """
  @spec bridge_event(term(), keyword()) :: :ok | {:error, term()}
  def bridge_event(event, opts \\ []) do
    bus = Keyword.get(opts, :bus, :desktop_ui)

    case convert_event_to_signal(event, bus) do
      {:ok, :mouse_move} ->
        # Mouse move events don't generate signals, just acknowledge
        {:ok, :mouse_move}

      {:ok, signal} ->
        case Jido.Signal.Bus.publish(bus, [signal]) do
          {:ok, _recorded} -> :ok
          {:error, reason} -> {:error, reason}
        end

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Get the signal bus name used by the runtime.

  ## Returns

  The signal bus name (atom)

  """
  @spec get_bus() :: atom()
  def get_bus, do: :desktop_ui

  @doc """
  Get the root component PID if available.

  ## Returns

  PID of root component or `nil` if not found

  """
  @spec get_root_component() :: pid() | nil
  def get_root_component do
    get_root_component(DesktopUI.Runtime)
  end

  @spec get_root_component(atom()) :: pid() | nil
  def get_root_component(runtime_name) when is_atom(runtime_name) do
    # Get the registry PID from the Runtime's state
    case GenServer.call(runtime_name, :get_registry_pid) do
      nil ->
        # No registry available
        nil

      pid when is_pid(pid) ->
        # Try Registry lookup
        case DesktopUI.Registry.lookup(pid, :root_component) do
          {:ok, component_pid} when is_pid(component_pid) -> component_pid
          :error -> nil
        end
    end
  catch
    :exit, _ ->
      # Runtime not running
      nil
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Extract options
    root_component = Keyword.fetch!(opts, :root_component)
    root_component_opts = Keyword.get(opts, :root_component_opts, [])
    renderer = Keyword.get(opts, :renderer, DesktopUI.Renderer.SDL2)
    bus = Keyword.get(opts, :bus, :desktop_ui)

    # SDL2 options for EventLoop
    window_title = Keyword.get(opts, :window_title, "DesktopUI App")
    window_width = Keyword.get(opts, :window_width, 800)
    window_height = Keyword.get(opts, :window_height, 600)
    fullscreen = Keyword.get(opts, :fullscreen, false)
    event_polling = Keyword.get(opts, :event_polling, true)
    poll_interval = Keyword.get(opts, :poll_interval, 16)

    # Determine if we should use SDL2 (unless explicitly overridden to Mock)
    use_sdl2 = renderer != DesktopUI.Renderer.Mock

    # Define children in supervision order
    children =
      [
        # Registry must start first for component registration
        # Note: Registry uses a public ETS table, so no process name needed
        {DesktopUI.Registry, []},
        # Signal bus must start early
        {Jido.Signal.Bus, [name: bus]},
        # EventLoop for SDL2 integration (optional, depends on renderer)
        # Only start EventLoop if we're using SDL2 renderer
        # TODO: We need to get window_id from EventLoop to pass to SDL2 renderer
        # For now, skip EventLoop and add it as a separate concern
        # RenderingCoordinator depends on signal bus
        # Note: No fixed name to avoid conflicts when Runtime is started/stopped rapidly in tests
        {DesktopUI.RenderingCoordinator,
         [
           renderer: renderer,
           bus: bus
         ]},
        # Root component starts last
        {Jido.AgentServer,
         [
           agent: root_component,
           opts: root_component_opts,
           name: :root_component
         ]}
      ]

    # Add EventLoop child if using SDL2
    # Note: No fixed name to avoid conflicts in tests where Runtime is started/stopped rapidly
    children =
      if use_sdl2 and event_polling do
        [
          {DesktopUI.Runtime.EventLoop,
           [
             bus: bus,
             window_title: window_title,
             window_width: window_width,
             window_height: window_height,
             fullscreen: fullscreen,
             event_polling: event_polling,
             poll_interval: poll_interval,
             renderer: renderer
           ]}
          | children
        ]
      else
        children
      end

    # Start a supervisor to manage the children
    # This allows us to have proper supervision while also handling custom messages
    # Note: No fixed name to avoid conflicts when Runtime is started/stopped rapidly in tests
    {:ok, supervisor_pid} =
      Supervisor.start_link(children, strategy: :one_for_one)

    # Get the Registry PID from the supervisor
    # Search all children since order is not guaranteed
    registry_pid =
      Enum.find_value(Supervisor.which_children(supervisor_pid), fn
        {DesktopUI.Registry, pid, _, _} when is_pid(pid) -> pid
        _ -> nil
      end)

    # Try to register root component immediately (send without delay)
    # The handle_info will retry if not ready yet
    send(self(), {:register_root_component})

    # Store the supervisor PID, registry PID, and other state
    {:ok, %{supervisor: supervisor_pid, registry: registry_pid, bus: bus}}
  end

  @impl true
  def handle_call(:get_registry_pid, _from, state) do
    {:reply, state.registry, state}
  end

  @impl true
  def handle_call(_msg, _from, state) do
    {:reply, {:error, :unknown_request}, state}
  end

  @impl true
  def handle_info({:register_root_component}, state) do
    # Register root component with the Registry
    # Find the Jido.AgentServer child's PID from the supervisor
    root_pid =
      Enum.find_value(Supervisor.which_children(state.supervisor), fn
        {Jido.AgentServer, pid, _, _} when is_pid(pid) -> pid
        _ -> nil
      end)

    case root_pid do
      nil ->
        # Root component not ready yet, retry quickly
        Process.send_after(self(), {:register_root_component}, 5)

      pid when is_pid(pid) ->
        if state.registry do
          DesktopUI.Registry.register(state.registry, :root_component, pid)
        end
    end

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Stop the supervisor when the Runtime GenServer stops
    # This ensures all children (signal bus, RenderingCoordinator, etc.) are stopped
    if state.supervisor do
      try do
        # Check if supervisor is still alive before trying to stop it
        if Process.alive?(state.supervisor) do
          Supervisor.stop(state.supervisor, :normal, 5000)
        end
      rescue
        # Supervisor might already be stopped or stopping
        _ -> :ok
      end
    end

    :ok
  end

  # Event conversion

  defp convert_event_to_signal({:sdl_keydown, data}, _bus) do
    key = Keyword.get(data, :key)
    modifiers = Keyword.get(data, :mod, [])

    # Convert atom key to string for signal schema
    key_str = if is_atom(key), do: Atom.to_string(key), else: key

    Signals.KeyPressed.new(
      %{
        key: key_str,
        modifiers: modifiers
      },
      source: "/desktop_ui/runtime"
    )
  end

  defp convert_event_to_signal({:sdl_keyup, data}, _bus) do
    key = Keyword.get(data, :key)
    modifiers = Keyword.get(data, :mod, [])

    # Convert atom key to string for signal schema
    key_str = if is_atom(key), do: Atom.to_string(key), else: key

    Signals.KeyReleased.new(
      %{
        key: key_str,
        modifiers: modifiers
      },
      source: "/desktop_ui/runtime"
    )
  end

  defp convert_event_to_signal({:sdl_mouseup, data}, _bus) do
    target_id = Keyword.get(data, :target_id)
    button = Keyword.get(data, :button, :left)
    x = Keyword.get(data, :x, 0)
    y = Keyword.get(data, :y, 0)

    if target_id do
      Signals.Clicked.new(
        %{
          target_id: target_id,
          button: button,
          x: x,
          y: y
        },
        source: "/desktop_ui/runtime"
      )
    else
      {:error, :no_target_id}
    end
  end

  defp convert_event_to_signal({:sdl_mousedown, data}, _bus) do
    target_id = Keyword.get(data, :target_id)
    button = Keyword.get(data, :button, :left)
    x = Keyword.get(data, :x, 0)
    y = Keyword.get(data, :y, 0)

    if target_id do
      Signals.MousePressed.new(
        %{
          target_id: target_id,
          button: button,
          x: x,
          y: y
        },
        source: "/desktop_ui/runtime"
      )
    else
      {:error, :no_target_id}
    end
  end

  defp convert_event_to_signal({:sdl_mousemove, _data}, _bus) do
    # Mouse move events - for now just acknowledge
    # Could add MouseMoved signal later for drag/drop
    {:ok, :mouse_move}
  end

  defp convert_event_to_signal({:sdl_quit}, _bus) do
    # Publish quit signal - no data needed for empty schema
    Signals.Quit.new(%{})
  end

  defp convert_event_to_signal(_unknown, _bus) do
    {:error, :unknown_event_type}
  end
end
