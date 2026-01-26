defmodule DesktopUI.RuntimeTest do
  use ExUnit.Case

  alias DesktopUI.Runtime
  alias DesktopUI.Signals
  alias DesktopUI.Widget

  # Helper to wait for a condition with timeout
  defp wait_for_condition(fun, max_retries \\ 10, retry_delay \\ 20) do
    wait_for_condition(fun, max_retries, retry_delay, 0)
  end

  defp wait_for_condition(_fun, max_retries, _retry_delay, attempt) when attempt >= max_retries do
    false
  end

  defp wait_for_condition(fun, max_retries, retry_delay, attempt) do
    if fun.() do
      true
    else
      Process.sleep(retry_delay)
      wait_for_condition(fun, max_retries, retry_delay, attempt + 1)
    end
  end

  # Helper to verify runtime is initialized
  defp assert_runtime_ready(name, runtime_pid) do
    assert Process.alive?(runtime_pid)
    # Verify root component is started
    assert wait_for_condition(fn ->
             pid = Runtime.get_root_component(name)
             is_pid(pid) and Process.alive?(pid)
           end)
  end

  # Test component to use as root component
  defmodule TestRootComponent do
    use DesktopUI.Elm,
      name: "test_root_component",
      description: "A test component for Runtime tests"

    @impl true
    def init(_opts) do
      {%{count: 0}, []}
    end

    @impl true
    def update(:increment, %{count: count} = state) do
      {%{state | count: count + 1}, []}
    end

    @impl true
    def update(:decrement, %{count: count} = state) do
      {%{state | count: count - 1}, []}
    end

    @impl true
    def update(:reset, state) do
      {%{state | count: 0}, []}
    end

    @impl true
    def view(%{count: count}) do
      Widget.container(
        :vbox,
        [
          Widget.label("Count: #{count}"),
          Widget.button("+", :increment),
          Widget.button("-", :decrement),
          Widget.button("Reset", :reset)
        ],
        spacing: 8
      )
    end
  end

  # Helper to start a unique runtime for each test
  defp start_runtime(context) do
    name = :"runtime_#{System.unique_integer([:positive, :monotonic])}"
    bus_name = :"bus_#{System.unique_integer([:positive, :monotonic])}"
    renderer_name = :"renderer_#{System.unique_integer([:positive, :monotonic])}"

    {:ok, renderer_pid} = DesktopUI.Renderer.Mock.start_link(name: renderer_name)

    {:ok, runtime_pid} =
      Runtime.start_link(
        name: name,
        root_component: TestRootComponent,
        renderer: {DesktopUI.Renderer.Mock, renderer_name},
        bus: bus_name
      )

    # Wait for children to start by verifying root component is alive
    assert_runtime_ready(name, runtime_pid)

    on_exit(fn ->
      # Try to stop runtime, ignore if already stopped or stopping
      if Process.whereis(name) do
        try do
          Process.monitor(runtime_pid)
          Supervisor.stop(name, :normal)

          # Wait for shutdown to complete
          assert_receive {:DOWN, _ref, :process, ^runtime_pid, _reason}, 500
        catch
          :exit, _ -> :already_stopping
          :throw, _ -> :already_stopping
        end
      end

      if Process.whereis(renderer_name) do
        try do
          GenServer.stop(renderer_name)
        catch
          :exit, _ -> :already_stopping
          :throw, _ -> :already_stopping
        end
      end
    end)

    Map.merge(context, %{
      runtime_name: name,
      runtime_pid: runtime_pid,
      bus_name: bus_name,
      renderer_name: renderer_name,
      renderer_pid: renderer_pid
    })
  end

  describe "start_link/1" do
    test "starts the runtime with required options" do
      name = :"runtime_start_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_start_#{System.unique_integer([:positive, :monotonic])}"
      renderer_name = :"renderer_start_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, renderer_pid} = DesktopUI.Renderer.Mock.start_link(name: renderer_name)

      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: TestRootComponent,
          renderer: {DesktopUI.Renderer.Mock, renderer_name},
          bus: bus_name
        )

      assert is_pid(runtime_pid)
      assert Process.alive?(runtime_pid)

      # Cleanup
      Supervisor.stop(name)
      GenServer.stop(renderer_name)
    end

    test "fails to start without root_component option" do
      name = :"runtime_no_root_#{System.unique_integer([:positive, :monotonic])}"

      # The init/1 callback raises KeyError, causing start_link to fail
      # We need to catch the exit signal
      capture_process_exit(fn ->
        Runtime.start_link(
          name: name,
          bus: :desktop_ui
        )
      end)

      # Verify the runtime did not start
      refute Process.whereis(name)
    end

    defp capture_process_exit(fun) do
      Process.flag(:trap_exit, true)
      pid = spawn_link(fun)

      receive do
        {:EXIT, ^pid, _reason} -> :ok
      after
        1000 -> flunk("Process did not exit")
      end
    end

    test "uses default renderer when none specified" do
      name = :"runtime_default_renderer_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_default_renderer_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: TestRootComponent,
          bus: bus_name
        )

      # Verify runtime is ready
      assert_runtime_ready(name, runtime_pid)

      # Should have started successfully with default renderer
      assert Process.alive?(runtime_pid)

      # Cleanup
      Supervisor.stop(name)
    end

    test "uses default bus name when none specified" do
      name = :"runtime_default_bus_#{System.unique_integer([:positive, :monotonic])}"
      renderer_name = :"renderer_default_bus_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, _renderer_pid} = DesktopUI.Renderer.Mock.start_link(name: renderer_name)

      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: TestRootComponent,
          renderer: {DesktopUI.Renderer.Mock, renderer_name}
        )

      # Verify runtime is ready
      assert_runtime_ready(name, runtime_pid)

      assert Process.alive?(runtime_pid)

      # Cleanup
      Supervisor.stop(name)
      GenServer.stop(renderer_name)
    end
  end

  describe "child processes" do
    setup :start_runtime

    test "starts root component", %{runtime_name: runtime_name} do
      # Root component is managed by the runtime supervisor
      pid = Runtime.get_root_component(runtime_name)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "root component is a valid Jido.Agent", %{runtime_name: runtime_name} do
      pid = Runtime.get_root_component(runtime_name)
      assert is_pid(pid)

      # Should respond to state queries
      {:ok, server_state} = Jido.Agent.Server.state(pid)
      assert server_state != nil
    end
  end

  describe "get_root_component/0" do
    setup :start_runtime

    test "returns root component PID when running", %{runtime_name: runtime_name} do
      pid = Runtime.get_root_component(runtime_name)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "returns nil when component not running", %{runtime_name: runtime_name} do
      # Stop the runtime
      Supervisor.stop(runtime_name)

      # Wait for shutdown to complete
      pid = Runtime.get_root_component(runtime_name)
      refute is_pid(pid)
    end
  end

  describe "get_bus/0" do
    test "returns the default bus name" do
      assert Runtime.get_bus() == :desktop_ui
    end
  end

  describe "bridge_event/1" do
    setup :start_runtime

    test "bridges keydown events to KeyPressed signal", %{bus_name: bus_name} do
      # Subscribe to capture the signal
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          bus_name,
          "desktop_ui.ui.**",
          dispatch: {:pid, target: test_pid}
        )

      :ok = Runtime.bridge_event({:sdl_keydown, key: :up, mod: []}, bus: bus_name)

      # Wait for signal
      assert_receive {:signal, %Jido.Signal{type: "desktop_ui.ui.key_pressed"}}, 500
    end

    test "bridges keyup events to KeyReleased signal", %{bus_name: bus_name} do
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          bus_name,
          "desktop_ui.ui.**",
          dispatch: {:pid, target: test_pid}
        )

      :ok = Runtime.bridge_event({:sdl_keyup, key: "escape", mod: [:ctrl, :shift]}, bus: bus_name)

      assert_receive {:signal, %Jido.Signal{type: "desktop_ui.ui.key_released"}}, 500
    end

    test "bridges mouseup events to Clicked signal when target_id provided", %{bus_name: bus_name} do
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          bus_name,
          "desktop_ui.ui.**",
          dispatch: {:pid, target: test_pid}
        )

      :ok =
        Runtime.bridge_event(
          {:sdl_mouseup, x: 100, y: 50, button: :left, target_id: :btn_click},
          bus: bus_name
        )

      assert_receive {:signal, %Jido.Signal{type: "desktop_ui.ui.clicked"}}, 500
    end

    test "returns error for mouseup without target_id" do
      result = Runtime.bridge_event({:sdl_mouseup, x: 100, y: 50, button: :left})
      assert result == {:error, :no_target_id}
    end

    test "bridges mousedown events to MousePressed signal when target_id provided", %{
      bus_name: bus_name
    } do
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          bus_name,
          "desktop_ui.ui.**",
          dispatch: {:pid, target: test_pid}
        )

      :ok =
        Runtime.bridge_event(
          {:sdl_mousedown, x: 50, y: 25, button: :right, target_id: :btn_menu},
          bus: bus_name
        )

      assert_receive {:signal, %Jido.Signal{type: "desktop_ui.ui.mouse_pressed"}}, 500
    end

    test "bridges quit events to Quit signal", %{bus_name: bus_name} do
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          bus_name,
          "desktop_ui.**",
          dispatch: {:pid, target: test_pid}
        )

      :ok = Runtime.bridge_event({:sdl_quit}, bus: bus_name)

      assert_receive {:signal, %Jido.Signal{type: "desktop_ui.app.quit"}}, 500
    end

    test "returns ok for mousemove events" do
      result = Runtime.bridge_event({:sdl_mousemove, x: 10, y: 20})
      assert result == {:ok, :mouse_move}
    end

    test "returns error for unknown event types" do
      result = Runtime.bridge_event({:unknown_event, data: "test"})
      assert result == {:error, :unknown_event_type}
    end
  end

  describe "shutdown" do
    test "shuts down cleanly all children" do
      name = :"runtime_shutdown_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_shutdown_#{System.unique_integer([:positive, :monotonic])}"
      renderer_name = :"renderer_shutdown_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, _renderer_pid} = DesktopUI.Renderer.Mock.start_link(name: renderer_name)

      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: TestRootComponent,
          renderer: {DesktopUI.Renderer.Mock, renderer_name},
          bus: bus_name
        )

      # Verify runtime is ready
      assert_runtime_ready(name, runtime_pid)

      # Monitor runtime for shutdown
      Process.monitor(runtime_pid)

      # Stop runtime
      Supervisor.stop(name, :normal)

      # Wait for shutdown
      assert_receive {:DOWN, _ref, :process, ^runtime_pid, _reason}, 500

      # Verify runtime is stopped
      refute Process.alive?(runtime_pid)

      # Renderer is not a child of runtime, so it should still be alive
      # Clean it up
      if Process.whereis(renderer_name) do
        try do
          GenServer.stop(renderer_name)
        rescue
          _ -> :already_stopped
        end
      end
    end

    test "handles shutdown of individual child" do
      name = :"runtime_child_death_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_child_death_#{System.unique_integer([:positive, :monotonic])}"
      renderer_name = :"renderer_child_death_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, _renderer_pid} = DesktopUI.Renderer.Mock.start_link(name: renderer_name)

      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: TestRootComponent,
          renderer: {DesktopUI.Renderer.Mock, renderer_name},
          bus: bus_name
        )

      # Verify runtime is ready
      assert_runtime_ready(name, runtime_pid)

      root_pid = Process.whereis(:root_component)

      if root_pid do
        original_root_pid = root_pid

        # Kill the root component
        GenServer.stop(root_pid, :normal)

        # Wait for root component to be restarted
        assert wait_for_condition(fn ->
                 new_root_pid = Process.whereis(:root_component)
                 is_pid(new_root_pid) and new_root_pid != original_root_pid
               end)

        # Root component should be restarted (new PID)
        new_root_pid = Process.whereis(:root_component)
        assert is_pid(new_root_pid)
        assert new_root_pid != original_root_pid

        # Runtime should still be alive
        assert Process.alive?(runtime_pid)
      end

      # Cleanup
      if Process.whereis(name) do
        try do
          Supervisor.stop(name)
        rescue
          _ -> :already_stopped
        end
      end

      try do
        GenServer.stop(renderer_name)
      rescue
        _ -> :already_stopped
      end
    end
  end
end
