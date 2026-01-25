defmodule DesktopUI.Runtime.EventLoop do
  @moduledoc """
  GenServer that manages SDL2 event polling and signal publishing.

  The EventLoop is responsible for:
  - Initializing SDL2 on startup
  - Creating the SDL2 window
  - Polling SDL events periodically
  - Translating SDL events to Jido signals
  - Publishing signals to the bus
  - Handling SDL_QUIT for graceful shutdown
  - Cleaning up SDL2 resources on termination

  This process runs as a child of the DesktopUI.Runtime supervisor.

  ## State

  The EventLoop maintains the following state:

  ```elixir
  %{
    bus: atom(),
    window_id: non_neg_integer() | nil,
    window_width: pos_integer(),
    window_height: pos_integer(),
    fullscreen: boolean(),
    event_polling: boolean(),
    poll_interval: pos_integer(),
    renderer: module() | {module(), term()} | nil
  }
  ```

  ## Usage

  The EventLoop is typically started by DesktopUI.Runtime:

      # In your Runtime.start_link options
      DesktopUI.Runtime.start_link(
        root_component: MyComponent,
        window_title: "My App",
        window_width: 800,
        window_height: 600,
        event_polling: true
      )

  """

  use GenServer
  require Logger

  alias DesktopUI.Graphics

  # Poll interval bounds (in milliseconds)
  # Minimum 1ms prevents excessive CPU usage from tight loops
  # Maximum 1000ms (1 second) ensures responsive event handling
  @min_poll_interval 1
  @max_poll_interval 1000

  @type option ::
          {:bus, atom()}
          | {:window_title, String.t()}
          | {:window_width, pos_integer()}
          | {:window_height, pos_integer()}
          | {:fullscreen, boolean()}
          | {:event_polling, boolean()}
          | {:poll_interval, pos_integer()}
          | {:renderer, atom() | {atom(), term()}}

  @type t :: %__MODULE__{
          bus: atom(),
          window_id: non_neg_integer() | nil,
          window_width: pos_integer(),
          window_height: pos_integer(),
          fullscreen: boolean(),
          event_polling: boolean(),
          poll_interval: pos_integer(),
          renderer: term()
        }

  defstruct [
    :bus,
    :window_id,
    :window_width,
    :window_height,
    :fullscreen,
    :event_polling,
    :poll_interval,
    :renderer
  ]

  # Client API

  @doc """
  Start the EventLoop GenServer.

  ## Options

  * `:bus` - Signal bus name (default: :desktop_ui)
  * `:window_title` - Window title (default: "DesktopUI App")
  * `:window_width` - Window width (default: 800)
  * `:window_height` - Window height (default: 600)
  * `:fullscreen` - Fullscreen mode (default: false)
  * `:event_polling` - Enable event polling (default: true)
  * `:poll_interval` - Event poll interval in ms (default: 16, ~60 FPS)
  * `:renderer` - Renderer module or tuple (default: DesktopUI.Renderer.SDL2)

  """
  @spec start_link([option]) :: GenServer.on_start()
  def start_link(opts) do
    {name_opts, opts} = Keyword.pop(opts, :name, nil)
    GenServer.start_link(__MODULE__, opts, name: name_opts)
  end

  @doc """
  Get the current window ID.

  Returns `nil` if SDL2 is not initialized.
  """
  @spec get_window_id(GenServer.server()) :: non_neg_integer() | nil
  def get_window_id(server \\ __MODULE__) do
    GenServer.call(server, :get_window_id)
  end

  @doc """
  Get the current window dimensions.

  Returns `{width, height}` or `nil` if no window.
  """
  @spec get_window_size(GenServer.server()) :: {pos_integer(), pos_integer()} | nil
  def get_window_size(server \\ __MODULE__) do
    GenServer.call(server, :get_window_size)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Extract options
    bus = Keyword.get(opts, :bus, :desktop_ui)
    window_title = Keyword.get(opts, :window_title, "DesktopUI App")
    window_width = Keyword.get(opts, :window_width, 800)
    window_height = Keyword.get(opts, :window_height, 600)
    fullscreen = Keyword.get(opts, :fullscreen, false)
    event_polling = Keyword.get(opts, :event_polling, true)
    poll_interval = Keyword.get(opts, :poll_interval, 16)
    renderer = Keyword.get(opts, :renderer, DesktopUI.Renderer.SDL2)

    # Validate poll interval first
    with :ok <- validate_poll_interval(poll_interval) do
      # Create initial state
      state = %__MODULE__{
        bus: bus,
        window_id: nil,
        window_width: window_width,
        window_height: window_height,
        fullscreen: fullscreen,
        event_polling: event_polling,
        poll_interval: poll_interval,
        renderer: renderer
      }

      # Try to initialize SDL2
      case initialize_sdl2(state, window_title, window_width, window_height, fullscreen) do
        {:ok, new_state} ->
          # Start event polling loop if enabled
          if event_polling do
            send(self(), :poll_sdl_events)
          end

          {:ok, new_state}

        {:error, _reason} = error ->
          # SDL2 initialization failed - log and continue without SDL2
          Logger.warning("""
          SDL2 initialization failed, running in headless mode. \
          Events will not be processed.\
          """)

          {:ok, state}
      end
    else
      {:error, reason} ->
        # Invalid poll interval - stop the GenServer
        Logger.error("Invalid poll_interval: #{reason}")
        {:stop, {:invalid_poll_interval, reason}}
    end
  end

  @impl true
  def handle_call(:get_window_id, _from, state) do
    {:reply, state.window_id, state}
  end

  @impl true
  def handle_call(:get_window_size, _from, state) do
    if state.window_id do
      {:reply, {state.window_width, state.window_height}, state}
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_info(:poll_sdl_events, %{window_id: nil} = state) do
    # No window, just reschedule
    Process.send_after(self(), :poll_sdl_events, state.poll_interval)
    {:noreply, state}
  end

  def handle_info(:poll_sdl_events, state) do
    case poll_all_events(state) do
      {:quit, _state} ->
        # Initiate graceful shutdown
        Logger.info("SDL_QUIT received, shutting down")
        {:stop, :normal, state}

      {:continue, new_state} ->
        # Schedule next poll
        Process.send_after(self(), :poll_sdl_events, state.poll_interval)
        {:noreply, new_state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    # Cleanup SDL2 resources
    cleanup_sdl2(state)
    :ok
  end

  # Private Functions

  # Initialize SDL2 and create window
  defp initialize_sdl2(state, title, width, height, fullscreen) do
    with :ok <- Graphics.sdl_init(),
         {:ok, window_id} <-
           Graphics.create_window(title, width, height,
             resizable: true,
             fullscreen: fullscreen
           ) do
      # Store window_id in SDL2 renderer for coordinator compatibility
      DesktopUI.Renderer.SDL2.set_window_id(window_id)

      {:ok,
       %{
         state
         | window_id: window_id,
           window_width: width,
           window_height: height
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Poll all available SDL events
  defp poll_all_events(state) do
    case Graphics.poll_event() do
      {:quit} ->
        {:quit, state}

      {:mouse_button_down, button, x, y} ->
        publish_mouse_pressed(x, y, button, state.bus)
        poll_all_events(state)

      {:mouse_button_up, button, x, y} ->
        publish_mouse_released(x, y, button, state.bus)
        poll_all_events(state)

      {:mouse_motion, x, y, _xrel, _yrel} ->
        # Mouse motion - could publish MouseMoved signal later
        poll_all_events(state)

      {:key_down, keycode, modifiers} ->
        publish_key_pressed(keycode, modifiers, state.bus)
        poll_all_events(state)

      {:key_up, keycode, modifiers} ->
        publish_key_released(keycode, modifiers, state.bus)
        poll_all_events(state)

      {:window_event, event_id, _data1, _data2} ->
        handle_window_event(event_id, state)
        poll_all_events(state)

      :no_event ->
        {:continue, state}

      _ ->
        # Unknown event type, continue polling
        poll_all_events(state)
    end
  end

  # Publish KeyPressed signal
  defp publish_key_pressed(keycode, modifiers, bus) do
    key_str = keycode_to_string(keycode)
    mod_list = modifiers_to_list(modifiers)

    case DesktopUI.Signals.KeyPressed.new(
           %{key: key_str, modifiers: mod_list},
           source: "/desktop_ui/runtime/event_loop"
         ) do
      {:ok, signal} ->
        Jido.Signal.Bus.publish(bus, [signal])

      {:error, _reason} ->
        :ok
    end
  end

  # Publish KeyReleased signal
  defp publish_key_released(keycode, modifiers, bus) do
    key_str = keycode_to_string(keycode)
    mod_list = modifiers_to_list(modifiers)

    case DesktopUI.Signals.KeyReleased.new(
           %{key: key_str, modifiers: mod_list},
           source: "/desktop_ui/runtime/event_loop"
         ) do
      {:ok, signal} ->
        Jido.Signal.Bus.publish(bus, [signal])

      {:error, _reason} ->
        :ok
    end
  end

  # Publish MousePressed signal
  defp publish_mouse_pressed(x, y, button, bus) do
    button_atom = sdl_button_to_atom(button)

    # TODO: Implement hit testing for target_id
    # For now, target_id is nil

    case DesktopUI.Signals.MousePressed.new(
           %{x: x, y: y, button: button_atom, target_id: nil},
           source: "/desktop_ui/runtime/event_loop"
         ) do
      {:ok, signal} ->
        Jido.Signal.Bus.publish(bus, [signal])

      {:error, _reason} ->
        :ok
    end
  end

  # Publish MouseReleased signal (could become Clicked if target matches)
  defp publish_mouse_released(x, y, button, bus) do
    button_atom = sdl_button_to_atom(button)

    # TODO: Implement hit testing for target_id
    # For now, target_id is nil, so we can't create a Clicked signal
    # Publish MouseReleased instead

    case DesktopUI.Signals.MouseReleased.new(
           %{x: x, y: y, button: button_atom, target_id: nil},
           source: "/desktop_ui/runtime/event_loop"
         ) do
      {:ok, signal} ->
        Jido.Signal.Bus.publish(bus, [signal])

      {:error, _reason} ->
        :ok
    end
  end

  # Handle window events
  defp handle_window_event(:resized, state) do
    # Get new window size
    case Graphics.get_window_size(state.window_id) do
      {:ok, {width, height}} ->
        # Publish WindowResized signal
        case DesktopUI.Signals.WindowResized.new(
               %{width: width, height: height},
               source: "/desktop_ui/runtime/event_loop"
             ) do
          {:ok, signal} ->
            Jido.Signal.Bus.publish(state.bus, [signal])

          {:error, _reason} ->
            :ok
        end

        {:continue, %{state | window_width: width, window_height: height}}

      {:error, _reason} ->
        {:continue, state}
    end
  end

  defp handle_window_event(_event_id, state) do
    {:continue, state}
  end

  # Convert SDL keycode atom to string
  defp keycode_to_string(keycode) when is_atom(keycode) do
    keycode
    |> Atom.to_string()
    |> String.replace_prefix("key_", "")
  end

  defp keycode_to_string(keycode), do: to_string(keycode)

  # Convert SDL modifier map to list
  defp modifiers_to_list(modifiers) when is_map(modifiers) do
    mods = []

    mods =
      if Map.get(modifiers, :shift, false) do
        [:shift | mods]
      else
        mods
      end

    mods =
      if Map.get(modifiers, :ctrl, false) do
        [:ctrl | mods]
      else
        mods
      end

    mods =
      if Map.get(modifiers, :alt, false) do
        [:alt | mods]
      else
        mods
      end

    mods =
      if Map.get(modifiers, :gui, false) do
        [:meta | mods]
      else
        mods
      end

    Enum.reverse(mods)
  end

  defp modifiers_to_list(_), do: []

  # Convert SDL button to atom
  defp sdl_button_to_atom(:left), do: :left
  defp sdl_button_to_atom(:middle), do: :middle
  defp sdl_button_to_atom(:right), do: :right
  defp sdl_button_to_atom(_), do: :left

  # Validate poll interval is within acceptable bounds
  @doc false
  defp validate_poll_interval(interval) when is_integer(interval) do
    cond do
      interval < @min_poll_interval ->
        {:error, "poll_interval must be at least #{@min_poll_interval}ms, got: #{interval}ms"}

      interval > @max_poll_interval ->
        {:error, "poll_interval must be at most #{@max_poll_interval}ms, got: #{interval}ms"}

      true ->
        :ok
    end
  end

  defp validate_poll_interval(_), do: {:error, "poll_interval must be an integer"}

  # Cleanup SDL2 resources
  defp cleanup_sdl2(%{window_id: window_id}) when is_integer(window_id) do
    Graphics.destroy_window(window_id)

    # Clear window_id from SDL2 renderer ETS table
    try do
      :ets.delete(DesktopUI.Renderer.SDL2.window_table(), :window_id)
    rescue
      _ -> :ok
    end

    :ok
  end

  defp cleanup_sdl2(_state), do: :ok
end
