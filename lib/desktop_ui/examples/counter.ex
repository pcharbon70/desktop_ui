defmodule DesktopUI.Examples.Counter do
  @moduledoc """
  A simple counter component demonstrating the Elm Architecture with Jido agents.

  This component serves as a reference implementation for building UI components
  using the DesktopUI.Elm behavior. It demonstrates:
  - State management via init/update callbacks
  - UI tree construction via view callback
  - Signal handling via on_signal callback
  - Nested widget containers (vbox with hbox)
  - Button click handling

  ## Example

      # Start via Runtime
      {:ok, _runtime} = DesktopUI.Runtime.start_link(
        root_component: DesktopUI.Examples.Counter,
        renderer: DesktopUI.Renderer.Mock,
        bus: :desktop_ui
      )

      # Or start directly as an agent
      {:ok, pid} = Jido.Agent.Server.start_link(
        agent: DesktopUI.Examples.Counter,
        name: :counter
      )

      # Send increment message directly
      Jido.Agent.Server.send_signal(pid, :increment)

      # Or bridge click events
      DesktopUI.Runtime.bridge_event(
        {:sdl_mouseup, x: 100, y: 50, button: :left, target_id: :btn_increment}
      )
  """

  # Note: DesktopUI.Elm behaviour defines init/1 which conflicts with GenServer's init/1.
  # This is expected - the Elm init/1 is for component state, not server initialization.
  @compile {:nowarn_callback_conflict, init: 1}

  use DesktopUI.Elm,
    name: "counter",
    description: "A simple counter component demonstrating the Elm Architecture",
    category: "ui"

  # DesktopUI.Widget functions are imported via use DesktopUI.Elm

  @impl true
  def init(_opts) do
    # Initialize with count of 0
    initial_state = %{count: 0}
    {initial_state, []}
  end

  @impl true
  def update(:increment, %{count: count} = state) do
    # Increase count by 1
    new_state = %{state | count: count + 1}
    {new_state, []}
  end

  @impl true
  def update(:decrement, %{count: count} = state) do
    # Decrease count by 1
    new_state = %{state | count: count - 1}
    {new_state, []}
  end

  @impl true
  def update(:reset, state) do
    # Reset count to 0
    new_state = %{state | count: 0}
    {new_state, []}
  end

  @impl true
  def update(:noop, state) do
    # No-op message for testing
    {state, []}
  end

  @impl true
  def view(%{count: count}) do
    # Build the UI tree:
    # - VBox container with spacing and padding
    #   - Title label
    #   - Count display label
    #   - HBox container for buttons
    #     - Increment button (+)
    #     - Decrement button (-)
    #     - Reset button

    container(
      :vbox,
      [
        label("Counter Demo", id: :title),
        label("Current: #{count}", id: :count_label),
        container(
          :hbox,
          [
            button("+", :increment, id: :btn_increment),
            button("-", :decrement, id: :btn_decrement),
            button("Reset", :reset, id: :btn_reset)
          ],
          spacing: 4
        )
      ],
      spacing: 8,
      padding: 16
    )
  end

  @impl true
  def on_signal(agent, %Jido.Signal{type: "desktop_ui.ui.clicked", data: %{target_id: target_id}}) do
    # Handle Clicked signals by mapping target_id to messages
    message =
      case target_id do
        :btn_increment -> :increment
        :btn_decrement -> :decrement
        :btn_reset -> :reset
        _ -> nil
      end

    if message do
      # Use handle_ui_signal to process through update/2
      DesktopUI.Elm.handle_ui_signal(agent, message)
    else
      # Unknown target_id, ignore
      {:ok, agent}
    end
  end

  @impl true
  def on_signal(agent, _signal) do
    # Ignore all other signals
    {:ok, agent}
  end
end
