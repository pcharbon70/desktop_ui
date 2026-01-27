defmodule DesktopUI.Examples.CounterTest do
  use ExUnit.Case
  alias DesktopUI.Examples.Counter
  alias DesktopUI.Signals
  alias DesktopUI.Elm

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

  describe "init/1" do
    test "initializes with count of 0" do
      {state, commands} = Counter.init([])

      assert state.count == 0
      assert commands == []
    end

    test "ignores init opts" do
      {state, _commands} = Counter.init(count: 5)

      # Counter.init ignores opts and always starts at 0
      assert state.count == 0
    end
  end

  describe "update/2" do
    test "increment increases count by 1" do
      state = %{count: 0}
      {new_state, commands} = Counter.update(:increment, state)

      assert new_state.count == 1
      assert commands == []
    end

    test "increment from non-zero count" do
      state = %{count: 5}
      {new_state, _commands} = Counter.update(:increment, state)

      assert new_state.count == 6
    end

    test "decrement decreases count by 1" do
      state = %{count: 5}
      {new_state, commands} = Counter.update(:decrement, state)

      assert new_state.count == 4
      assert commands == []
    end

    test "decrement from zero" do
      state = %{count: 0}
      {new_state, _commands} = Counter.update(:decrement, state)

      assert new_state.count == -1
    end

    test "reset sets count to 0" do
      state = %{count: 42}
      {new_state, commands} = Counter.update(:reset, state)

      assert new_state.count == 0
      assert commands == []
    end

    test "quit returns quit command" do
      state = %{count: 5}
      {new_state, commands} = Counter.update(:quit, state)

      # State should be unchanged
      assert new_state.count == 5
      # Should return quit command
      assert commands == [:quit]
    end

    test "noop returns empty commands" do
      state = %{count: 3}
      {new_state, commands} = Counter.update(:noop, state)

      # State should be unchanged
      assert new_state.count == 3
      # No commands
      assert commands == []
    end
  end

  describe "view/1" do
    test "returns valid widget tree" do
      state = %{count: 5}
      ui_tree = Counter.view(state)

      # Root is a vbox container
      assert ui_tree.type == :container
      assert ui_tree.props[:layout] == :vbox
      # Enhanced spacing: 16 (was 8)
      assert ui_tree.props[:spacing] == 16
      # Enhanced padding: 24 (was 16)
      assert ui_tree.props[:padding] == 24
    end

    test "displays current count in label" do
      state = %{count: 42}
      ui_tree = Counter.view(state)

      # Find the count display label (id changed from :count_label to :count_display)
      count_label =
        Enum.find(ui_tree.children, fn child ->
          child.id == :count_display
        end)

      assert count_label != nil
      assert count_label.type == :label
      # Simplified display - just the number (was "Current: 42")
      assert count_label.props[:text] == "42"
    end

    test "displays title label" do
      state = %{count: 0}
      ui_tree = Counter.view(state)

      title_label =
        Enum.find(ui_tree.children, fn child ->
          child.id == :title
        end)

      assert title_label != nil
      assert title_label.type == :label
      # Enhanced title (was "Counter Demo")
      assert title_label.props[:text] == "DesktopUI Counter"
    end

    test "has four buttons in hbox" do
      state = %{count: 0}
      ui_tree = Counter.view(state)

      # Find the hbox container
      hbox =
        Enum.find(ui_tree.children, fn child ->
          child.type == :container and child.props[:layout] == :hbox
        end)

      assert hbox != nil
      # Enhanced spacing: 8 (was 4)
      assert hbox.props[:spacing] == 8
      # Enhanced padding: 8 (new)
      assert hbox.props[:padding] == 8
      # Now has 4 buttons (was 3) - added quit button
      assert length(hbox.children) == 4
    end

    test "buttons have correct ids and on_click messages" do
      state = %{count: 0}
      ui_tree = Counter.view(state)

      hbox =
        Enum.find(ui_tree.children, fn child ->
          child.type == :container and child.props[:layout] == :hbox
        end)

      increment_btn = Enum.find(hbox.children, fn child -> child.id == :btn_increment end)
      decrement_btn = Enum.find(hbox.children, fn child -> child.id == :btn_decrement end)
      reset_btn = Enum.find(hbox.children, fn child -> child.id == :btn_reset end)
      quit_btn = Enum.find(hbox.children, fn child -> child.id == :btn_quit end)

      # Increment button
      assert increment_btn != nil
      assert increment_btn.type == :button
      assert increment_btn.props[:text] == "+"
      assert increment_btn.props[:on_click] == :increment

      # Decrement button
      assert decrement_btn != nil
      assert decrement_btn.type == :button
      assert decrement_btn.props[:text] == "-"
      assert decrement_btn.props[:on_click] == :decrement

      # Reset button
      assert reset_btn != nil
      assert reset_btn.type == :button
      assert reset_btn.props[:text] == "Reset"
      assert reset_btn.props[:on_click] == :reset

      # Quit button (new)
      assert quit_btn != nil
      assert quit_btn.type == :button
      assert quit_btn.props[:text] == "Quit"
      assert quit_btn.props[:on_click] == :quit
    end

    test "has instructions label" do
      state = %{count: 0}
      ui_tree = Counter.view(state)

      instructions_label =
        Enum.find(ui_tree.children, fn child ->
          child.id == :instructions
        end)

      assert instructions_label != nil
      assert instructions_label.type == :label
      assert instructions_label.props[:text] == "Press + to increment, - to decrement"
    end
  end

  describe "on_signal/2" do
    setup do
      # Create a counter agent struct (not started)
      agent = struct(Counter, id: "test_counter", state: %{})

      %{agent: agent}
    end

    test "clicked signal with btn_increment increments count", %{agent: agent} do
      {:ok, signal} =
        Signals.Clicked.new(
          %{
            target_id: :btn_increment,
            button: :left
          },
          source: "/test"
        )

      {:ok, updated_agent} = Counter.on_signal(agent, signal)

      # Check elm_state was updated
      elm_state = Elm.get_elm_state(updated_agent)
      assert elm_state.count == 1
    end

    test "clicked signal with btn_decrement decrements count", %{agent: agent} do
      # First set count to 5 by initializing with handle_ui_signal
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)

      {:ok, signal} =
        Signals.Clicked.new(
          %{
            target_id: :btn_decrement,
            button: :left
          },
          source: "/test"
        )

      {:ok, updated_agent} = Counter.on_signal(agent, signal)

      elm_state = Elm.get_elm_state(updated_agent)
      assert elm_state.count == 4
    end

    test "clicked signal with btn_reset sets count to 0", %{agent: agent} do
      # First increment multiple times
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)

      {:ok, signal} =
        Signals.Clicked.new(
          %{
            target_id: :btn_reset,
            button: :left
          },
          source: "/test"
        )

      {:ok, updated_agent} = Counter.on_signal(agent, signal)

      elm_state = Elm.get_elm_state(updated_agent)
      assert elm_state.count == 0
    end

    test "clicked signal with btn_quit returns quit command", %{agent: agent} do
      # Initialize state first
      {:ok, agent} = Elm.handle_ui_signal(agent, :noop)

      {:ok, signal} =
        Signals.Clicked.new(
          %{
            target_id: :btn_quit,
            button: :left
          },
          source: "/test"
        )

      # The quit signal should return {:error, :quit}
      result = Counter.on_signal(agent, signal)

      assert result == {:error, :quit}
    end

    test "clicked signal with unknown target_id is ignored", %{agent: agent} do
      # Initialize state first
      {:ok, agent} = Elm.handle_ui_signal(agent, :noop)

      {:ok, signal} =
        Signals.Clicked.new(
          %{
            target_id: :unknown_button,
            button: :left
          },
          source: "/test"
        )

      {:ok, updated_agent} = Counter.on_signal(agent, signal)

      # State should be unchanged
      new_elm_state = Elm.get_elm_state(updated_agent)
      assert new_elm_state.count == 0
    end

    test "non-clicked signals are ignored", %{agent: agent} do
      # Initialize state first
      {:ok, agent} = Elm.handle_ui_signal(agent, :noop)

      {:ok, signal} =
        Signals.KeyPressed.new(
          %{
            key: "escape",
            modifiers: []
          },
          source: "/test"
        )

      {:ok, updated_agent} = Counter.on_signal(agent, signal)

      # State should be unchanged
      new_elm_state = Elm.get_elm_state(updated_agent)
      assert new_elm_state.count == 0
    end
  end

  describe "integration with Jido.Agent.Server" do
    setup do
      bus_name = :"counter_bus_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, _bus} = Jido.Signal.Bus.start_link(name: bus_name)

      {:ok, agent_pid} =
        Jido.Agent.Server.start_link(
          agent: Counter,
          name: nil
        )

      on_exit(fn ->
        if Process.whereis(bus_name), do: GenServer.stop(bus_name)
        if Process.alive?(agent_pid), do: GenServer.stop(agent_pid)
      end)

      %{agent_pid: agent_pid, bus_name: bus_name}
    end

    test "agent initializes with count of 0", %{agent_pid: agent_pid} do
      {:ok, server_state} = Jido.Agent.Server.state(agent_pid)
      agent = server_state.agent

      # Initialize elm state by calling handle_ui_signal
      {:ok, initialized_agent} = Elm.handle_ui_signal(agent, :noop)
      elm_state = Elm.get_elm_state(initialized_agent)

      assert elm_state.count == 0
    end

    test "handle_ui_signal increments count", %{agent_pid: agent_pid} do
      {:ok, server_state} = Jido.Agent.Server.state(agent_pid)
      agent = server_state.agent

      # Initialize first
      {:ok, agent} = Elm.handle_ui_signal(agent, :noop)

      # Send increment
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)

      elm_state = Elm.get_elm_state(agent)
      assert elm_state.count == 1
    end

    test "handle_ui_signal decrements count", %{agent_pid: agent_pid} do
      {:ok, server_state} = Jido.Agent.Server.state(agent_pid)
      agent = server_state.agent

      # Initialize and increment first
      {:ok, agent} = Elm.handle_ui_signal(agent, :noop)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)

      # Then decrement
      {:ok, agent} = Elm.handle_ui_signal(agent, :decrement)

      elm_state = Elm.get_elm_state(agent)
      assert elm_state.count == 0
    end

    test "handle_ui_signal resets count", %{agent_pid: agent_pid} do
      {:ok, server_state} = Jido.Agent.Server.state(agent_pid)
      agent = server_state.agent

      # Initialize and increment multiple times
      {:ok, agent} = Elm.handle_ui_signal(agent, :noop)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)
      {:ok, agent} = Elm.handle_ui_signal(agent, :increment)

      # Reset
      {:ok, agent} = Elm.handle_ui_signal(agent, :reset)

      elm_state = Elm.get_elm_state(agent)
      assert elm_state.count == 0
    end

    test "state changes publish StateChanged signals", %{agent_pid: agent_pid} do
      # Start the default signal bus for this test
      {:ok, _bus} = Jido.Signal.Bus.start_link(name: :desktop_ui)

      # Subscribe to state change signals
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          :desktop_ui,
          "desktop_ui.state.**",
          dispatch: {:pid, target: test_pid}
        )

      {:ok, server_state} = Jido.Agent.Server.state(agent_pid)
      agent = server_state.agent

      # Trigger a state change
      {:ok, _agent} = Elm.handle_ui_signal(agent, :increment)

      # Should receive StateChanged signal
      assert_receive {:signal, %Jido.Signal{type: "desktop_ui.state.changed"}}, 500
    end

    test "on_signal handles Clicked signals from bus", %{agent_pid: agent_pid, bus_name: bus_name} do
      # Subscribe to state changes to verify
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          bus_name,
          "desktop_ui.state.**",
          dispatch: {:pid, target: test_pid}
        )

      # Publish a Clicked signal to the bus
      {:ok, signal} =
        Signals.Clicked.new(
          %{
            target_id: :btn_increment,
            button: :left
          },
          source: "/test"
        )

      # The agent won't automatically receive this unless it's subscribed
      # So we need to also test the on_signal callback directly
      {:ok, server_state} = Jido.Agent.Server.state(agent_pid)
      agent = server_state.agent

      # Initialize
      {:ok, agent} = Elm.handle_ui_signal(agent, :noop)

      # Call on_signal directly
      {:ok, updated_agent} = Counter.on_signal(agent, signal)

      elm_state = Elm.get_elm_state(updated_agent)
      assert elm_state.count == 1
    end
  end
end
