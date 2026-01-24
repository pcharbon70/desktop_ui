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
  - Be startable via `Jido.Agent.Server.start_link/2`

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

  use Supervisor
  alias DesktopUI.Signals

  @type option ::
    {:root_component, module()}
    | {:root_component_opts, keyword()}
    | {:renderer, atom() | {atom(), atom()}}
    | {:bus, atom()}
    | {:name, atom()}

  # Client API

  @doc """
  Start the Runtime supervisor.

  ## Options

  * `:root_component` - The root component module (must implement DesktopUI.Elm) (required)
  * `:root_component_opts` - Options to pass to root component's init/1 (default: [])
  * `:renderer` - Renderer module or {module, name} tuple (default: DesktopUI.Renderer.Mock)
  * `:bus` - Signal bus name (default: :desktop_ui)
  * `:name` - Runtime process name (optional)

  ## Examples

      {:ok, pid} = DesktopUI.Runtime.start_link(
        root_component: MyCounterComponent,
        renderer: DesktopUI.Renderer.Mock,
        bus: :desktop_ui
      )

  """
  @spec start_link([option]) :: Supervisor.on_start()
  def start_link(opts) do
    {name_opts, opts} = Keyword.pop(opts, :name, nil)
    Supervisor.start_link(__MODULE__, opts, name: name_opts)
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
    # Jido.Agent.Server doesn't register with the Process registry using
    # the provided name. Instead, we find the child by PID from the
    # supervisor's children.
    case Process.whereis(DesktopUI.Runtime) do
      nil -> nil
      runtime_pid when is_pid(runtime_pid) ->
        # Get the children of the runtime supervisor
        children = Supervisor.which_children(runtime_pid)

        # Find the Jido.Agent.Server child (root component)
        # Children are returned as [{id, pid, type, modules}]
        case Enum.find(children, fn {id, _pid, _type, _modules} ->
          id == Jido.Agent.Server
        end) do
          {_, pid, _, _} when is_pid(pid) -> pid
          _ -> nil
        end
    end
  end

  def get_root_component(runtime_name) when is_atom(runtime_name) do
    case Process.whereis(runtime_name) do
      nil -> nil
      runtime_pid when is_pid(runtime_pid) ->
        children = Supervisor.which_children(runtime_pid)

        case Enum.find(children, fn {id, _pid, _type, _modules} ->
          id == Jido.Agent.Server
        end) do
          {_, pid, _, _} when is_pid(pid) -> pid
          _ -> nil
        end
    end
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Extract options
    root_component = Keyword.fetch!(opts, :root_component)
    root_component_opts = Keyword.get(opts, :root_component_opts, [])
    renderer = Keyword.get(opts, :renderer, DesktopUI.Renderer.Mock)
    bus = Keyword.get(opts, :bus, :desktop_ui)

    # Define children in supervision order
    children = [
      # Signal bus must start first
      {Jido.Signal.Bus, [name: bus]},
      # RenderingCoordinator depends on signal bus
      {DesktopUI.RenderingCoordinator,
        [renderer: renderer, bus: bus, name: :rendering_coordinator]},
      # Root component starts last
      {Jido.Agent.Server,
        [
          agent: root_component,
          opts: root_component_opts,
          name: :root_component
        ]}
    ]

    # After children start, register root component with coordinator
    # We'll do this via a Registry or by having the component register itself
    # For now, the component's init will handle registration via signals

    # Use one_for_one strategy - if a child crashes, only that child is restarted
    Supervisor.init(children, strategy: :one_for_one)
  end

  # Event conversion

  defp convert_event_to_signal({:sdl_keydown, data}, _bus) do
    key = Keyword.get(data, :key)
    modifiers = Keyword.get(data, :mod, [])

    # Convert atom key to string for signal schema
    key_str = if is_atom(key), do: Atom.to_string(key), else: key

    Signals.KeyPressed.new(%{
      key: key_str,
      modifiers: modifiers
    }, source: "/desktop_ui/runtime")
  end

  defp convert_event_to_signal({:sdl_keyup, data}, _bus) do
    key = Keyword.get(data, :key)
    modifiers = Keyword.get(data, :mod, [])

    # Convert atom key to string for signal schema
    key_str = if is_atom(key), do: Atom.to_string(key), else: key

    Signals.KeyReleased.new(%{
      key: key_str,
      modifiers: modifiers
    }, source: "/desktop_ui/runtime")
  end

  defp convert_event_to_signal({:sdl_mouseup, data}, _bus) do
    target_id = Keyword.get(data, :target_id)
    button = Keyword.get(data, :button, :left)
    x = Keyword.get(data, :x, 0)
    y = Keyword.get(data, :y, 0)

    if target_id do
      Signals.Clicked.new(%{
        target_id: target_id,
        button: button,
        x: x,
        y: y
      }, source: "/desktop_ui/runtime")
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
      Signals.MousePressed.new(%{
        target_id: target_id,
        button: button,
        x: x,
        y: y
      }, source: "/desktop_ui/runtime")
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
