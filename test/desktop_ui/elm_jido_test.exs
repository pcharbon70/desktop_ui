defmodule DesktopUI.ElmJidoTest do
  use ExUnit.Case

  alias DesktopUI.Elm
  alias DesktopUI.Signals

  setup_all do
    # Start the Elixir Registry that Jido.Signal.Bus needs
    # Jido.Signal.Bus registers itself under the name :Jido.Signal.Registry
    # Check if it already exists first (may have been started by another test module)
    case Process.whereis(Jido.Signal.Registry) do
      nil -> {:ok, _} = Registry.start_link(keys: :unique, name: Jido.Signal.Registry)
      _ -> :ok
    end
    :ok
  end

  describe "Jido.Agent integration" do
    test "component using use DesktopUI.Elm is a valid Jido.Agent" do
      # Verify TestCounter has the required Jido.Agent functions
      assert function_exported?(DesktopUI.ElmJidoTest.TestCounter, :__agent_metadata__, 0)
      assert function_exported?(DesktopUI.ElmJidoTest.TestCounter, :on_before_run, 1)
      assert function_exported?(DesktopUI.ElmJidoTest.TestCounter, :on_signal, 2)
    end

    test "component implements DesktopUI.Elm behaviour" do
      # Verify the component implements the Elm behaviour
      assert function_exported?(DesktopUI.ElmJidoTest.TestCounter, :init, 1)
      assert function_exported?(DesktopUI.ElmJidoTest.TestCounter, :update, 2)
      assert function_exported?(DesktopUI.ElmJidoTest.TestCounter, :view, 1)
    end

    test "component has default on_signal implementation" do
      # Create a valid signal
      {:ok, signal} = Signals.Quit.new(%{})

      # Create an agent struct
      agent = struct(DesktopUI.ElmJidoTest.TestCounter, id: "test_id", state: %{})

      # Default on_signal should just return the agent unchanged
      assert {:ok, returned_agent} = DesktopUI.ElmJidoTest.TestCounter.on_signal(agent, signal)
      assert returned_agent == agent
    end
  end

  describe "init/1 callback" do
    test "init is called when agent starts" do
      # Start an agent server
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestCounter,
          name: :test_init_counter
        )

      # Get the agent from the server state
      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # elm_state is lazily initialized, so it's nil initially
      assert Map.get(agent.state, :elm_state) == nil

      # Trigger initialization by calling handle_ui_signal
      {:ok, initialized_agent} = DesktopUI.Elm.handle_ui_signal(agent, :noop)

      # Now elm_state should be initialized
      assert initialized_agent.state.elm_state == %{count: 0}
      assert initialized_agent.state.component_id != nil

      # Clean up
      Process.exit(pid, :normal)
    end

    test "init with custom options" do
      # Start an agent server
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestCustomInit,
          name: :test_custom_init
        )

      # Get the agent from the server state
      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # Trigger initialization by calling handle_ui_signal
      {:ok, initialized_agent} = DesktopUI.Elm.handle_ui_signal(agent, :noop)

      # Should have default count since we passed no options
      assert initialized_agent.state.elm_state.count == 10

      # Clean up
      Process.exit(pid, :normal)
    end
  end

  describe "update/2 callback" do
    test "handle_ui_signal calls update/2 and publishes state change" do
      # Start signal bus for this test - use :desktop_ui to match the publish call
      {:ok, _bus} = Jido.Signal.Bus.start_link(name: :desktop_ui)

      # Subscribe to state changes
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          :desktop_ui,
          "desktop_ui.state.**",
          dispatch: {:pid, target: test_pid}
        )

      # Start agent
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestCounter,
          id: "test_counter",
          name: :test_counter_bus
        )

      # Get current agent from server state
      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # Call handle_ui_signal
      assert {:ok, updated_agent} = Elm.handle_ui_signal(agent, :increment)

      # Verify state was updated
      assert updated_agent.state.elm_state.count == 1

      # Verify StateChanged signal was published
      assert_receive {:signal, signal}, 1000
      assert signal.type == "desktop_ui.state.changed"
      assert signal.data.component_id == "test_counter"
      assert signal.data.old_state.count == 0
      assert signal.data.new_state.count == 1

      # Cleanup
      Process.exit(pid, :normal)
    end

    test "handle_ui_signal with decrement message" do
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestCounter,
          name: :test_decrement
        )

      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # Increment first
      assert {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      assert agent.state.elm_state.count == 1

      # Then decrement
      assert {:ok, agent} = Elm.handle_ui_signal(agent, :decrement)
      assert agent.state.elm_state.count == 0

      # Clean up
      Process.exit(pid, :normal)
    end

    test "handle_ui_signal with reset message" do
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestCounter,
          name: :test_reset
        )

      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # Increment a few times
      assert {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      assert {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      assert {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      assert agent.state.elm_state.count == 3

      # Reset
      assert {:ok, agent} = Elm.handle_ui_signal(agent, :reset)
      assert agent.state.elm_state.count == 0

      # Clean up
      Process.exit(pid, :normal)
    end
  end

  describe "view/1 callback" do
    test "view returns valid widget tree" do
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestCounter,
          name: :test_view
        )

      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # Initialize elm state by calling handle_ui_signal
      {:ok, initialized_agent} = Elm.handle_ui_signal(agent, :noop)

      # Call view with the elm state
      widget = DesktopUI.ElmJidoTest.TestCounter.view(initialized_agent.state.elm_state)

      # Verify it's a valid widget structure
      assert widget.type == :label
      assert is_list(widget.props)
      assert is_list(widget.children)

      # Clean up
      Process.exit(pid, :normal)
    end
  end

  describe "on_signal/2 callback" do
    test "custom on_signal handles specific signals" do
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestSignalHandler,
          name: :test_signal_handler
        )

      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # Create a Clicked signal
      {:ok, signal} =
        Signals.Clicked.new(%{
          target_id: :btn_click,
          button: :left
        })

      # Call on_signal
      assert {:ok, updated_agent} =
               DesktopUI.ElmJidoTest.TestSignalHandler.on_signal(agent, signal)

      # The signal handler should have called update(:set_clicked, state)
      assert updated_agent.state.elm_state.clicked == true

      # Clean up
      Process.exit(pid, :normal)
    end

    test "custom on_signal ignores unhandled signals" do
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestSignalHandler,
          name: :test_ignore_signal
        )

      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      initial_state = agent.state

      # Create a different Clicked signal
      {:ok, signal} =
        Signals.Clicked.new(%{
          target_id: :other_button,
          button: :left
        })

      # Call on_signal - should be ignored by catch-all
      assert {:ok, returned_agent} =
               DesktopUI.ElmJidoTest.TestSignalHandler.on_signal(agent, signal)

      # State should be unchanged
      assert returned_agent.state == initial_state

      # Clean up
      Process.exit(pid, :normal)
    end
  end

  describe "get_elm_state/1" do
    test "returns the component's elm state" do
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestCounter,
          name: :test_get_state
        )

      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # Initialize elm state
      {:ok, initialized_agent} = Elm.handle_ui_signal(agent, :noop)

      elm_state = Elm.get_elm_state(initialized_agent)
      assert elm_state == %{count: 0}

      # Clean up
      Process.exit(pid, :normal)
    end

    test "returns nil if elm_state not initialized" do
      # Create an agent struct without initialization
      agent = struct(DesktopUI.ElmJidoTest.TestCounter, id: "test", state: %{})

      # Before handle_ui_signal is called
      elm_state = Elm.get_elm_state(agent)
      assert is_nil(elm_state)
    end
  end

  describe "StateChanged signal publishing" do
    setup do
      # Start signal bus for each test - use :desktop_ui to match the publish call
      {:ok, _bus} = Jido.Signal.Bus.start_link(name: :desktop_ui)

      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          :desktop_ui,
          "desktop_ui.state.**",
          dispatch: {:pid, target: test_pid}
        )

      :ok
    end

    test "publishes signal when state changes" do
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestCounter,
          id: "test_counter",
          name: :test_state_change
        )

      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # Change state
      {:ok, _agent} = Elm.handle_ui_signal(agent, :increment)

      # Should receive StateChanged signal
      assert_receive {:signal, signal}, 1000
      assert signal.type == "desktop_ui.state.changed"
      assert signal.data.component_id == "test_counter"
      assert signal.data.new_state.count == 1

      # Clean up
      Process.exit(pid, :normal)
    end

    test "does not publish signal when state is unchanged" do
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestNoOp,
          id: "test_noop",
          name: :test_noop_state
        )

      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # Call update with no-op (which initializes state)
      {:ok, _agent} = Elm.handle_ui_signal(agent, :noop)

      # State is now %{value: 5}, call no-op again (no change)
      {:ok, server_state2} = Jido.Agent.Server.state(pid)
      {:ok, _agent} = Elm.handle_ui_signal(server_state2.agent, :noop)

      # Should NOT receive StateChanged signal for second call
      refute_receive {:signal, _signal}, 500

      # Clean up
      Process.exit(pid, :normal)
    end

    test "includes old_state and new_state in signal" do
      {:ok, pid} =
        Jido.Agent.Server.start_link(
          agent: DesktopUI.ElmJidoTest.TestCounter,
          id: "test_counter_old_new",
          name: :test_old_new
        )

      {:ok, server_state} = Jido.Agent.Server.state(pid)
      agent = server_state.agent

      # First call initializes state
      {:ok, initialized_agent} = Elm.handle_ui_signal(agent, :noop)
      old_count = initialized_agent.state.elm_state.count

      {:ok, _agent} = Elm.handle_ui_signal(initialized_agent, :increment)

      assert_receive {:signal, signal}, 1000
      assert signal.data.old_state.count == old_count
      assert signal.data.new_state.count == old_count + 1

      # Clean up
      Process.exit(pid, :normal)
    end
  end

  describe "Widget imports" do
    test "Widget functions are imported" do
      # Verify that the Widget module functions are available
      # by checking if the TestCounter module can call them directly
      widget = DesktopUI.ElmJidoTest.TestCounter.view(%{count: 5})

      # If the import works, we should be able to create widgets
      assert widget.type == :label
    end
  end
end

# Test component modules defined outside the test module

defmodule DesktopUI.ElmJidoTest.TestCounter do
  use DesktopUI.Elm,
    name: "test_counter",
    description: "A test counter component"

  @impl true
  def init(_opts) do
    {%{count: 0}, []}
  end

  @impl true
  def update(:increment, %{count: count} = state) do
    {%{state | count: count + 1}, []}
  end

  def update(:decrement, %{count: count} = state) do
    {%{state | count: count - 1}, []}
  end

  def update(:reset, state) do
    {%{state | count: 0}, []}
  end

  def update(:noop, state) do
    {state, []}
  end

  @impl true
  def view(%{count: count}) do
    DesktopUI.Widget.label("Count: " <> Integer.to_string(count))
  end
end

defmodule DesktopUI.ElmJidoTest.TestSignalHandler do
  use DesktopUI.Elm,
    name: "test_signal_handler",
    description: "A test component with signal handling"

  @impl true
  def init(_opts) do
    {%{count: 0, clicked: false}, []}
  end

  @impl true
  def update(:set_clicked, state) do
    {%{state | clicked: true}, []}
  end

  @impl true
  def view(_state) do
    DesktopUI.Widget.label("Signal Handler")
  end

  @impl true
  def on_signal(agent, %Jido.Signal{type: "desktop_ui.ui.clicked", data: %{target_id: :btn_click}}) do
    DesktopUI.Elm.handle_ui_signal(agent, :set_clicked)
  end

  def on_signal(agent, _signal) do
    {:ok, agent}
  end
end

defmodule DesktopUI.ElmJidoTest.TestCustomInit do
  use DesktopUI.Elm, name: "test_custom_init"

  @impl true
  def init(opts) do
    initial_count = Keyword.get(opts, :count, 10)
    {%{count: initial_count}, []}
  end

  @impl true
  def update(_msg, state), do: {state, []}

  @impl true
  def view(_state), do: DesktopUI.Widget.label("Custom")
end

defmodule DesktopUI.ElmJidoTest.TestNoOp do
  use DesktopUI.Elm, name: "test_noop"

  @impl true
  def init(_opts), do: {%{value: 5}, []}

  @impl true
  def update(:noop, state), do: {state, []}

  @impl true
  def view(_state), do: DesktopUI.Widget.label("NoOp")
end
