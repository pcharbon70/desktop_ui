defmodule DesktopUI.Examples.Counter do
  @moduledoc """
  A polished counter component demonstrating the DesktopUI framework capabilities.

  This component serves as a reference implementation for building UI components
  using the DesktopUI.Elm behavior. It demonstrates:
  - State management via init/update callbacks
  - UI tree construction via view callback
  - Signal handling via on_signal callback
  - Layout capabilities (VBox, HBox, spacing, padding)
  - Interactive button handling
  - Application quit handling

  ## Layout Structure

  The component uses a VBox as the main container with an HBox for button arrangement:

  ```
  VBox (spacing: 16, padding: 24)
  ├── Label "DesktopUI Counter" (title)
  ├── Label "0" (count display, prominent)
  ├── HBox (spacing: 8, padding: 8)
  │   ├── Button "-" (decrement)
  │   ├── Button "+" (increment, primary action)
  │   ├── Button "Reset" (reset)
  │   └── Button "Quit" (quit)
  └── Label "Press + to increment, - to decrement" (instructions)
  ```

  ## Example

      # Start via Runtime
      {:ok, _runtime} = DesktopUI.Runtime.start_link(
        root_component: DesktopUI.Examples.Counter,
        renderer: DesktopUI.Renderer.SDL2,
        window_title: "DesktopUI Counter Demo",
        window_width: 400,
        window_height: 500
      )

  """

  # Note: DesktopUI.Elm behaviour defines init/1 which conflicts with GenServer's init/1.
  # This is expected - the Elm init/1 is for component state, not server initialization.
  @compile {:nowarn_callback_conflict, init: 1}

  use DesktopUI.Elm,
    name: "counter",
    description: "A polished counter component demonstrating layout capabilities",
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
  def update(:quit, state) do
    # Quit command - signals the agent to stop
    # The Elm behaviour handles :quit by returning {:error, :quit}
    {state, [:quit]}
  end

  @impl true
  def update(:noop, state) do
    # No-op message for testing
    {state, []}
  end

  @impl true
  def view(%{count: count}) do
    # Build the UI tree with enhanced layout:
    # - Main VBox with generous spacing and padding for visual polish
    # - Large count display as the focal point
    # - Centered button row with all actions
    # - Instructional text at bottom

    container(
      :vbox,
      [
        # Title
        label("DesktopUI Counter", id: :title),

        # Count display - prominent, large text representation
        # Using to_string/1 for clean number display
        label(to_string(count), id: :count_display),

        # Button row - HBox with centered alignment
        # Buttons are ordered with primary action (+) in the middle
        container(
          :hbox,
          [
            button("-", :decrement, id: :btn_decrement),
            button("+", :increment, id: :btn_increment),
            button("Reset", :reset, id: :btn_reset),
            button("Quit", :quit, id: :btn_quit)
          ],
          # Increased spacing for better touch targets
          spacing: 8,
          # Padding around button row for visual separation
          padding: 8
        ),

        # Instructions - helpful text for users
        label("Press + to increment, - to decrement", id: :instructions)
      ],
      # Generous spacing between main sections for visual hierarchy
      spacing: 16,
      # Generous padding around the entire UI for breathing room
      padding: 24
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
        :btn_quit -> :quit
        _ -> nil
      end

    if message do
      # Use handle_ui_signal to process through update/2
      # This will trigger state change and potentially a :quit command
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
