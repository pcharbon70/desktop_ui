defmodule DesktopUI.Elm do
  @moduledoc """
  The Elm Architecture behaviour for DesktopUI components with Jido.Agent integration.

  This module defines the contract that all UI components must implement,
  following The Elm Architecture (TEA) pattern for predictable state management
  and unidirectional data flow, integrated with Jido agents for signal-based
  communication.

  ## The Elm Architecture with Jido

  TEA consists of three core concepts:

  1. **Model** - Your application's state
  2. **Update** - A way to update state based on messages
  3. **View** - A way to render state as UI elements

  With Jido integration, components become autonomous agents that:
  - Publish state change signals automatically
  - Handle incoming signals via `on_signal/2`
  - Communicate with other agents decoupled via the signal bus

  ## Component Lifecycle

  The lifecycle of a component follows this flow:

  1. Agent starts with `use Jido.Agent`
  2. `init/1` - Initialize with options, return initial state and commands
  3. `view/1` - Render current state as a UI tree
  4. Signal arrives (e.g., Clicked, KeyPressed)
  5. `on_signal/2` - Process signal, optionally call `handle_ui_signal/2`
  6. `handle_ui_signal/2` - Calls `update/2` with message
  7. If state changed, `StateChanged` signal is auto-published
  8. RenderingCoordinator receives signal and triggers render
  9. Loop continues

  ## Using This Behaviour

  To create a component, `use DesktopUI.Elm` in your module:

      defmodule MyComponent do
        use DesktopUI.Elm,
          name: "my_component",
          description: "A sample component"

        @impl true
        def init(_opts) do
          # Initialize state from options
          initial_state = %{count: 0}
          {initial_state, []}
        end

        @impl true
        def update(:increment, %{count: count} = state) do
          # Handle message, return new state and commands
          new_state = %{state | count: count + 1}
          {new_state, []}
        end

        @impl true
        def view(%{count: count}) do
          # Return UI tree describing what to render
          # See DesktopUI.Widget for constructors
          DesktopUI.Widget.label("Count: " <> Integer.to_string(count))
        end

        @impl true
        def on_signal(agent, signal) do
          # Optional: Handle custom signals
          {:ok, agent}
        end
      end

  The `use DesktopUI.Elm` macro:
  1. Includes `use Jido.Agent` for agent capabilities
  2. Defines `@behaviour DesktopUI.Elm`
  3. Generates default implementations that raise helpful errors
  4. Makes the `DesktopUI.Widget` module available as `Widget`

  ## Type Specifications

  - `state/0` - The component's state (can be any type)
  - `message/0` - Events/messages the component receives
  - `command/0` - Side effects to execute after state updates
  - `ui_element/0` - The UI tree returned by `view/1`

  ## Signals

  Components automatically publish a `StateChanged` signal after each
  successful state update. This signal includes:
  - `component_id` - Unique identifier for the component
  - `old_state` - The state before the update
  - `new_state` - The state after the update

  Components can also receive signals via the `on_signal/2` callback.

  """

  alias DesktopUI.Signals
  require Logger

  @doc """
  Initialize the component with options.

  Called once when the component is first started. Use this to set up
  your initial state.

  ## Parameters

  - `opts` - Keyword list of initialization options

  ## Returns

  `{initial_state, commands}` where:
  - `initial_state` - The component's starting state
  - `commands` - List of commands to execute (empty list if none)

  ## Example

      def init(_opts) do
        initial_state = %{count: 0}
        {initial_state, []}
      end

  """
  @callback init(opts :: keyword()) :: {state(), [command()]}

  @doc """
  Update the component's state based on a message.

  Called whenever the component receives a message (event). This is where
  you transform your state in response to user actions, system events,
  or other stimuli.

  ## Parameters

  - `message` - The message/event to handle
  - `state` - The current component state

  ## Returns

  `{new_state, commands}` where:
  - `new_state` - The updated state
  - `commands` - List of commands to execute (empty list if none)

  ## Example

      def update(:increment, %{count: count} = state) do
        new_state = %{state | count: count + 1}
        {new_state, []}
      end

      def update(:decrement, %{count: count} = state) do
        new_state = %{state | count: count - 1}
        {new_state, []}
      end

  """
  @callback update(message(), state()) :: {state(), [command()]}

  @doc """
  Render the component's state as a UI tree.

  Called after initialization and after each state change. Returns a
  declarative description of what to render.

  The UI tree is a pure data structure - not drawing commands. The
  renderer interprets this structure to produce actual graphics.

  ## Parameters

  - `state` - The current component state

  ## Returns

  A `ui_element()` describing the UI tree.

  ## Example

      def view(state) do
        DesktopUI.Widget.container(:vbox, [
          DesktopUI.Widget.label("Counter"),
          DesktopUI.Widget.button("Increment", :increment),
          DesktopUI.Widget.button("Decrement", :decrement)
        ], spacing: 8)
      end

  """
  @callback view(state()) :: ui_element()

  @doc """
  Handle an incoming signal.

  Called when a signal is received from the signal bus. Components can
  override this to handle custom signal types.

  ## Parameters

  - `agent` - The Jido.Agent struct
  - `signal` - The Jido.Signal struct received

  ## Returns

  `{:ok, agent}` with the updated agent state, or `{:error, reason}`

  ## Example

      @impl true
      def on_signal(agent, %Signals.Clicked{data: %{target_id: :btn_save}}) do
        # Handle save button click
        DesktopUI.Elm.handle_ui_signal(agent, :save)
      end

      def on_signal(agent, _signal) do
        # Ignore other signals
        {:ok, agent}
      end

  """
  @callback on_signal(agent :: Jido.Agent.t(), signal :: Jido.Signal.t()) ::
              {:ok, Jido.Agent.t()} | {:error, term()}

  # Type Definitions

  @typedoc """
  The component's state.

  Can be any type - the component decides its state representation.
  Common patterns: maps, structs, tuples, or simple values.
  """
  @type state :: any()

  @typedoc """
  A message sent to the component.

  Messages represent events: user actions, system events, timeouts,
  or signals from other components.
  """
  @type message :: any()

  @typedoc """
  A command representing a side effect.

  Commands are returned from `init/1` and `update/2` to request
  side effects after state updates.

  ## Command Types

  - `:none` - No operation (placeholder)
  - `{:emit, signal}` - Emit a signal to other components
  - `{:send, pid, message}` - Send a message to a process
  - `{:after, milliseconds, message}` - Schedule a delayed message to self
  - `:quit` - Request application shutdown

  """
  @type command ::
          :none
          | {:emit, any()}
          | {:send, pid(), any()}
          | {:after, pos_integer(), message()}
          | :quit

  @typedoc """
  A UI element in the widget tree.

  UI elements form a recursive tree structure describing the interface.
  The renderer interprets this tree to produce actual graphics.

  ## Structure

  A UI element is a map with:
  - `:type` - Atom identifying the widget type
  - `:id` - Optional unique identifier for event targeting
  - `:props` - Keyword list of widget properties
  - `:children` - List of child UI elements

  ## Widget Types

  - `:label` - Text display
  - `:button` - Clickable button with on_click message
  - `:container` - Layout container (`:vbox`, `:hbox`, etc.)

  ## Example

      %{
        type: :container,
        id: :main_container,
        props: [layout: :vbox, spacing: 8],
        children: [
          %{type: :label, props: [text: "Hello"]},
          %{type: :button, props: [text: "Click", on_click: :clicked]}
        ]
      }

  See `DesktopUI.Widget` for convenient constructors.

  """
  @type ui_element :: %{
          type: atom(),
          id: atom() | nil,
          props: keyword(),
          children: [ui_element()]
        }

  @doc """
  Using macro for scaffolding component boilerplate.

  When `use DesktopUI.Elm` is called, this macro:
  1. Includes `use Jido.Agent` for agent capabilities
  2. Imports the `@behaviour DesktopUI.Elm` directive
  3. Generates default implementations that raise helpful errors
  4. Makes the `DesktopUI.Widget` module available as `Widget`
  5. Adds default `on_signal/2` implementation

  ## Options

  All options are passed to `use Jido.Agent`. Common options:
  - `:name` - Agent name (required)
  - `:description` - Agent description
  - `:category` - Agent category
  - `:tags` - List of tags

  """
  defmacro __using__(opts) do
    quote do
      use Jido.Agent, unquote(opts)

      @behaviour DesktopUI.Elm

      # Import Widget for convenience
      import DesktopUI.Widget, only: [label: 2, button: 3, container: 3]

      @impl true
      def init(_opts) do
        raise """
        #{__MODULE__} must implement the init/1 callback.

        Example:

            @impl true
            def init(opts) do
              initial_state = %{}
              {initial_state, []}
            end

        """
      end

      @impl true
      def update(_message, _state) do
        raise """
        #{__MODULE__} must implement the update/2 callback.

        Example:

            @impl true
            def update(:increment, %{count: count} = state) do
              new_state = %{state | count: count + 1}
              {new_state, []}
            end

        """
      end

      @impl true
      def view(_state) do
        raise """
        #{__MODULE__} must implement the view/1 callback.

        Example:

            @impl true
            def view(state) do
              Widget.label("Hello")
            end

        """
      end

      @impl true
      def on_signal(agent, _signal) do
        # Default implementation: ignore signals
        {:ok, agent}
      end

      # Jido.Agent lifecycle hook to initialize Elm state
      @impl true
      def on_before_run(agent) do
        # Initialize Elm state if not already set
        elm_state = Map.get(agent.state, :elm_state)

        if is_nil(elm_state) do
          # Call init/1 to get initial state
          {initial_elm_state, _commands} = apply(__MODULE__, :init, [[]])

          new_state =
            Map.put(agent.state, :elm_state, initial_elm_state)
            |> Map.put(:component_id, agent.id || to_string(__MODULE__))

          {:ok, %{agent | state: new_state}}
        else
          {:ok, agent}
        end
      end

      defoverridable init: 1, update: 2, view: 1, on_signal: 2, on_before_run: 1
    end
  end

  @doc """
  Handle a UI message by calling the component's update/2 callback.

  This helper function is intended to be called from within a component's
  `on_signal/2` callback to process UI messages through the standard
  update mechanism.

  After calling update/2, this function automatically publishes a
  `StateChanged` signal if the state changed.

  ## Parameters

  - `agent` - The Jido.Agent struct
  - `message` - The message to pass to update/2

  ## Returns

  `{:ok, agent}` with updated state, or `{:error, reason}`

  ## Example

      @impl true
      def on_signal(agent, %Signals.Clicked{data: %{target_id: :btn_increment}}) do
        DesktopUI.Elm.handle_ui_signal(agent, :increment)
      end

  """
  def handle_ui_signal(agent, message) when is_map(agent) and map_size(agent) > 0 do
    # Initialize elm_state if not already set
    agent =
      if is_nil(Map.get(agent.state, :elm_state)) do
        module = agent.__struct__
        {initial_elm_state, _commands} = apply(module, :init, [[]])
        component_id = Map.get(agent.state, :component_id, agent.id || to_string(module))

        new_agent_state =
          agent.state
          |> Map.put(:elm_state, initial_elm_state)
          |> Map.put(:component_id, component_id)

        %{agent | state: new_agent_state}
      else
        agent
      end

    elm_state = Map.get(agent.state, :elm_state)
    module = agent.__struct__

    case apply(module, :update, [message, elm_state]) do
      {new_elm_state, commands} ->
        old_state = elm_state
        component_id = Map.get(agent.state, :component_id, to_string(agent.__struct__))

        # Update agent state
        new_agent_state =
          Map.put(agent.state, :elm_state, new_elm_state)

        updated_agent = %{agent | state: new_agent_state}

        # Publish StateChanged signal
        if old_state != new_elm_state do
          publish_state_changed(component_id, old_state, new_elm_state)
        end

        # Execute commands
        case execute_commands(updated_agent, commands, component_id) do
          {:ok, final_agent} -> {:ok, final_agent}
          {:error, _} = error -> error
        end

      :error ->
        {:error, :update_error}
    end
  end

  @doc """
  Get the component's Elm state from an agent.

  ## Parameters

  - `agent` - The Jido.Agent struct

  ## Returns

  The component's Elm state, or nil if not initialized.

  """
  def get_elm_state(agent) when is_map(agent) do
    agent_state = Map.get(agent, :state, %{})
    Map.get(agent_state, :elm_state)
  end

  # Private function to execute commands returned from init/1 and update/2
  defp execute_commands(agent, commands, component_id) when is_list(commands) do
    # Execute commands in order, accumulating the agent state
    Enum.reduce_while(commands, {:ok, agent}, fn command, {:ok, acc_agent} ->
      case execute_command(acc_agent, command, component_id) do
        {:ok, updated_agent} -> {:cont, {:ok, updated_agent}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp execute_commands(agent, _commands, _component_id), do: {:ok, agent}

  # Private function to execute a single command
  defp execute_command(agent, :none, _component_id), do: {:ok, agent}

  defp execute_command(agent, {:emit, signal_data}, component_id) do
    # Create a generic signal from the data
    # signal_data should be a map with at least :type
    case create_signal(signal_data, component_id) do
      {:ok, signal} ->
        try do
          Jido.Signal.Bus.publish(:desktop_ui, [signal])
          {:ok, agent}
        rescue
          error ->
            # Signal bus not available, continue anyway
            Logger.debug("Signal bus not available for component #{component_id}: #{inspect(error)}")
            {:ok, agent}
        end

      {:error, reason} ->
        # Invalid signal data, continue anyway
        Logger.warning("Invalid signal data for component #{component_id}: #{inspect(reason)}")
        {:ok, agent}
    end
  end

  defp execute_command(agent, {:send, pid, message}, _component_id) when is_pid(pid) do
    send(pid, message)
    {:ok, agent}
  end

  defp execute_command(agent, {:send, _pid, _message}, _component_id) do
    # Invalid PID, continue anyway
    {:ok, agent}
  end

  defp execute_command(agent, {:after, milliseconds, message}, _component_id)
       when is_integer(milliseconds) and milliseconds > 0 do
    Process.send_after(self(), message, milliseconds)
    {:ok, agent}
  end

  defp execute_command(agent, {:after, _milliseconds, _message}, _component_id) do
    # Invalid delay, continue anyway
    {:ok, agent}
  end

  defp execute_command(_agent, :quit, _component_id) do
    # Quit command - signal to stop
    {:error, :quit}
  end

  defp execute_command(agent, _unknown, _component_id) do
    # Unknown command, continue anyway
    {:ok, agent}
  end

  # Helper to create a signal from data
  defp create_signal(data, component_id) do
    # Build signal type if not provided
    type = Map.get(data, :type, "desktop_ui.custom")

    # Add component_id to data if not present
    data_with_id = Map.put(data, :component_id, component_id)

    # Use Jido.Signal.new/2 to create the signal
    Jido.Signal.new(type, data_with_id,
      source: Map.get(data, :source, "/desktop_ui/#{component_id}")
    )
  end

  # Private function to publish state change signal
  defp publish_state_changed(component_id, old_state, new_state) do
    case Signals.StateChanged.new(%{
           component_id: component_id,
           old_state: old_state,
           new_state: new_state
         }) do
      {:ok, signal} ->
        # Publish to signal bus if it's available
        try do
          Jido.Signal.Bus.publish(:desktop_ui, [signal])
        rescue
          # Signal bus may not be started in tests
          _ ->
            :ok
        end

      {:error, _} ->
        :ok
    end
  end
end
