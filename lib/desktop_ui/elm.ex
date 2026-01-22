defmodule DesktopUI.Elm do
  @moduledoc """
  The Elm Architecture behaviour for DesktopUI components.

  This module defines the contract that all UI components must implement,
  following The Elm Architecture (TEA) pattern for predictable state management
  and unidirectional data flow.

  ## The Elm Architecture

  TEA consists of three core concepts:

  1. **Model** - Your application's state
  2. **Update** - A way to update state based on messages
  3. **View** - A way to render state as UI elements

  ## Component Lifecycle

  The lifecycle of a component follows this flow:

  1. `init/1` - Initialize with options, return initial state and commands
  2. `view/1` - Render current state as a UI tree
  3. Event occurs (user interaction, system event, etc.)
  4. `update/2` - Process event, return new state and commands
  5. If state changed, `view/1` is called again
  6. Loop continues

  ## Using This Behaviour

  To create a component, `use DesktopUI.Elm` in your module:

      defmodule MyComponent do
        use DesktopUI.Elm

        @impl true
        def init(opts) do
          # Initialize state from options
          initial_state = %{}
          {initial_state, []}
        end

        @impl true
        def update(msg, state) do
          # Handle message, return new state and commands
          new_state = process_message(msg, state)
          {new_state, []}
        end

        @impl true
        def view(state) do
          # Return UI tree describing what to render
          # See DesktopUI.Widget for constructors
          DesktopUI.Widget.label("Hello, World!")
        end
      end

  The `use DesktopUI.Elm` macro generates default implementations of all
  required callbacks that raise helpful error messages, so you only need to
  implement the callbacks you actually use.

  ## Type Specifications

  - `state/0` - The component's state (can be any type)
  - `message/0` - Events/messages the component receives
  - `command/0` - Side effects to execute after state updates
  - `ui_element/0` - The UI tree returned by `view/1`

  ## Commands

  Commands represent side effects that should be executed after state updates.
  They are returned from `init/1` and `update/2` as a list.

  Examples of commands:
  - Emitting a signal to other components
  - Scheduling a delayed message
  - Performing I/O operations
  - Requesting runtime actions (quit, focus, etc.)

  Commands are executed by the Runtime after the state has been updated.

  """

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

      def update({:set, value}, state) do
        {state, []}
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

      def view(%{count: count}) do
        DesktopUI.Widget.container(:vbox, [
          DesktopUI.Widget.label("Count: \#{count}"),
          DesktopUI.Widget.button("Increment", :increment),
          DesktopUI.Widget.button("Decrement", :decrement)
        ], spacing: 8)
      end

  """
  @callback view(state()) :: ui_element()

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
  1. Imports the `@behaviour DesktopUI.Elm` directive
  2. Generates default implementations that raise helpful errors
  3. Makes the `DesktopUI.Widget` module available as `Widget`

  """
  defmacro __using__(_opts) do
    quote do
      @behaviour DesktopUI.Elm

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

      defoverridable init: 1, update: 2, view: 1
    end
  end
end
