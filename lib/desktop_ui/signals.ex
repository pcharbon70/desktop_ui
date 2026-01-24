defmodule DesktopUI.Signals do
  @moduledoc """
  Signal types for DesktopUI communication.

  All UI events and state changes are communicated via signals
  following the CloudEvents v1.0.2 specification through the Jido.Signal library.

  This module defines the core signal types used throughout DesktopUI:
  - State changes from component agents
  - UI input events (clicks, key presses)
  - Render coordination signals

  Signals enable decoupled communication between:
  - Component agents (publish state changes)
  - Runtime (bridges SDL events to signals)
  - RenderingCoordinator (subscribes to state changes)

  ## Example

      # Create a state change signal
      {:ok, signal} = DesktopUI.Signals.StateChanged.new(%{
        component_id: "counter_123",
        old_state: %{count: 0},
        new_state: %{count: 1}
      })

      # Publish to signal bus
      Jido.Signal.Bus.publish(:desktop_ui, [signal])

      # Create a click signal
      {:ok, signal} = DesktopUI.Signals.Clicked.new(%{
        target_id: :btn_increment,
        button: :left,
        x: 100,
        y: 50
      })
  """

  @doc """
  Signal published when a component's state changes.

  Component agents automatically publish this signal after their
  `update/2` callback returns a new state. The RenderingCoordinator
  subscribes to these signals to trigger re-renders.

  ## Fields

  - `component_id` - Unique identifier for the component (required)
  - `old_state` - The state before the update (required)
  - `new_state` - The state after the update (required)
  """
  defmodule StateChanged do
    use Jido.Signal,
      type: "desktop_ui.state.changed",
      default_source: "/desktop_ui/components",
      schema: [
        component_id: [
          type: :string,
          required: true,
          doc: "Unique identifier for the component"
        ],
        old_state: [
          type: :map,
          required: true,
          doc: "The state before the update"
        ],
        new_state: [
          type: :map,
          required: true,
          doc: "The state after the update"
        ]
      ]
  end

  @doc """
  Signal published when a mouse click occurs.

  The Runtime event bridge publishes this signal after receiving
  SDL mouse button events. Component agents can handle these
  signals via their `on_signal/2` callback.

  ## Fields

  - `target_id` - The widget that was clicked (optional, determined by hit testing)
  - `button` - Which mouse button was clicked (:left, :middle, :right)
  - `x` - X coordinate of the click (optional)
  - `y` - Y coordinate of the click (optional)
  """
  defmodule Clicked do
    use Jido.Signal,
      type: "desktop_ui.ui.clicked",
      default_source: "/desktop_ui/input",
      schema: [
        target_id: [
          type: :atom,
          required: false,
          doc: "The widget that was clicked (determined by hit testing)"
        ],
        button: [
          type: {:in, [:left, :middle, :right]},
          required: true,
          default: :left,
          doc: "Which mouse button was clicked"
        ],
        x: [
          type: :integer,
          required: false,
          doc: "X coordinate of the click"
        ],
        y: [
          type: :integer,
          required: false,
          doc: "Y coordinate of the click"
        ]
      ]
  end

  @doc """
  Signal published when a mouse button is pressed.

  The Runtime event bridge publishes this signal after receiving
  SDL mouse button events. Component agents can handle these
  signals via their `on_signal/2` callback.

  ## Fields

  - `target_id` - The widget that was pressed (optional, determined by hit testing)
  - `button` - Which mouse button was pressed (:left, :middle, :right)
  - `x` - X coordinate of the press (optional)
  - `y` - Y coordinate of the press (optional)
  """
  defmodule MousePressed do
    use Jido.Signal,
      type: "desktop_ui.ui.mouse_pressed",
      default_source: "/desktop_ui/input",
      schema: [
        target_id: [
          type: :atom,
          required: false,
          doc: "The widget that was pressed (determined by hit testing)"
        ],
        button: [
          type: {:in, [:left, :middle, :right]},
          required: true,
          default: :left,
          doc: "Which mouse button was pressed"
        ],
        x: [
          type: :integer,
          required: false,
          doc: "X coordinate of the press"
        ],
        y: [
          type: :integer,
          required: false,
          doc: "Y coordinate of the press"
        ]
      ]
  end

  @doc """
  Signal published when a keyboard key is pressed.

  The Runtime event bridge publishes this signal after receiving
  SDL keyboard events. Component agents can handle these
  signals via their `on_signal/2` callback.

  ## Fields

  - `key` - The key that was pressed (required)
  - `modifiers` - List of modifier keys that were held (:shift, :ctrl, :alt, :meta)
  """
  defmodule KeyPressed do
    use Jido.Signal,
      type: "desktop_ui.ui.key_pressed",
      default_source: "/desktop_ui/input",
      schema: [
        key: [
          type: :string,
          required: true,
          doc: "The key that was pressed (e.g., 'a', 'escape', 'enter')"
        ],
        modifiers: [
          type: {:list, {:in, [:shift, :ctrl, :alt, :meta]}},
          required: false,
          default: [],
          doc: "List of modifier keys that were held"
        ]
      ]
  end

  @doc """
  Signal published when a keyboard key is released.

  The Runtime event bridge publishes this signal after receiving
  SDL keyboard events. Component agents can handle these
  signals via their `on_signal/2` callback.

  ## Fields

  - `key` - The key that was released (required)
  - `modifiers` - List of modifier keys that were held (:shift, :ctrl, :alt, :meta)
  """
  defmodule KeyReleased do
    use Jido.Signal,
      type: "desktop_ui.ui.key_released",
      default_source: "/desktop_ui/input",
      schema: [
        key: [
          type: :string,
          required: true,
          doc: "The key that was released (e.g., 'a', 'escape', 'enter')"
        ],
        modifiers: [
          type: {:list, {:in, [:shift, :ctrl, :alt, :meta]}},
          required: false,
          default: [],
          doc: "List of modifier keys that were held"
        ]
      ]
  end

  @doc """
  Signal published to request a render of a component.

  This signal can be published to force a re-render of a specific
  component, even if its state hasn't changed. The RenderingCoordinator
  handles these signals by calling the component's `view/1` function.

  ## Fields

  - `component_id` - The component to render (required)
  - `force` - Whether to force render even if state unchanged (default: false)
  """
  defmodule RenderRequest do
    use Jido.Signal,
      type: "desktop_ui.render.request",
      default_source: "/desktop_ui/coordinator",
      schema: [
        component_id: [
          type: :string,
          required: true,
          doc: "The component to render"
        ],
        force: [
          type: :boolean,
          required: false,
          default: false,
          doc: "Whether to force render even if state unchanged"
        ]
      ]
  end

  @doc """
  Signal published to register a component with the RenderingCoordinator.

  Components must be registered before they will be rendered on state changes.
  This signal should be published when a component agent starts.

  ## Fields

  - `component_id` - Unique identifier for the component (required)
  - `module` - The component module name (required)
  - `pid` - The component agent's PID (optional)
  """
  defmodule ComponentRegister do
    use Jido.Signal,
      type: "desktop_ui.component.register",
      default_source: "/desktop_ui/components",
      schema: [
        component_id: [
          type: :string,
          required: true,
          doc: "Unique identifier for the component"
        ],
        module: [
          type: :atom,
          required: true,
          doc: "The component module name"
        ],
        pid: [
          type: :pid,
          required: false,
          doc: "The component agent's PID"
        ]
      ]
  end

  @doc """
  Signal published to unregister a component from the RenderingCoordinator.

  ## Fields

  - `component_id` - Unique identifier for the component (required)
  """
  defmodule ComponentUnregister do
    use Jido.Signal,
      type: "desktop_ui.component.unregister",
      default_source: "/desktop_ui/components",
      schema: [
        component_id: [
          type: :string,
          required: true,
          doc: "Unique identifier for the component"
        ]
      ]
  end

  @doc """
  Signal published when the window is resized.

  The Runtime publishes this signal when it receives an SDL window
  resize event. The RenderingCoordinator uses this to trigger
  layout recalculation.

  ## Fields

  - `width` - New window width in pixels (required)
  - `height` - New window height in pixels (required)
  """
  defmodule WindowResized do
    use Jido.Signal,
      type: "desktop_ui.window.resized",
      default_source: "/desktop_ui/runtime",
      schema: [
        width: [
          type: :integer,
          required: true,
          doc: "New window width in pixels"
        ],
        height: [
          type: :integer,
          required: true,
          doc: "New window height in pixels"
        ]
      ]
  end

  @doc """
  Signal published when the application should quit.

  The Runtime publishes this signal when it receives an SDL quit event.
  Components can handle this signal to perform cleanup before shutdown.

  ## Fields

  No additional fields beyond the standard signal attributes.
  """
  defmodule Quit do
    use Jido.Signal,
      type: "desktop_ui.app.quit",
      default_source: "/desktop_ui/runtime",
      schema: []
  end
end
