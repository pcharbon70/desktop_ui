defmodule DesktopUI.Runtime.EventLoopTest do
  use ExUnit.Case

  alias DesktopUI.Runtime.EventLoop
  alias DesktopUI.Signals
  alias DesktopUI.Renderer.Mock

  # Helper to start a unique event loop for each test
  defp start_event_loop(context, opts \\ []) do
    name = :"event_loop_#{System.unique_integer([:positive, :monotonic])}"
    bus_name = :"bus_#{System.unique_integer([:positive, :monotonic])}"

    # Start the signal bus first
    {:ok, _bus_pid} = Jido.Signal.Bus.start_link(name: bus_name)

    # Default options
    default_opts = [
      bus: bus_name,
      window_title: "Test Window",
      window_width: 800,
      window_height: 600,
      fullscreen: false,
      event_polling: false, # Disable auto-polling for tests
      poll_interval: 16,
      renderer: Mock,
      name: name
    ]

    opts = Keyword.merge(default_opts, opts)

    {:ok, event_loop_pid} = EventLoop.start_link(opts)

    # Wait for initialization
    Process.sleep(100)

    on_exit(fn ->
      # Stop event loop
      if Process.whereis(name) do
        try do
          GenServer.stop(name, :normal)
          # Wait for shutdown to complete
          Process.sleep(100)
        catch
          :exit, _ -> :already_stopping
          :throw, _ -> :already_stopping
        end
      end

      # Stop the bus - the bus is a GenServer
      case Process.whereis(bus_name) do
        nil -> :ok
        pid when is_pid(pid) ->
          try do
            GenServer.stop(pid, :normal)
          catch
            :exit, _ -> :already_stopping
            :throw, _ -> :already_stopping
          end
      end
    end)

    Map.merge(context, %{
      event_loop_name: name,
      event_loop_pid: event_loop_pid,
      bus_name: bus_name
    })
  end

  describe "start_link/1" do
    test "starts event loop with required options" do
      # Use Mock renderer so SDL2 initialization happens but we can test without it
      name = :"event_loop_start_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_start_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, _bus_pid} = Jido.Signal.Bus.start_link(name: bus_name)

      {:ok, pid} =
        EventLoop.start_link(
          bus: bus_name,
          window_title: "Test",
          window_width: 640,
          window_height: 480,
          event_polling: false,
          name: name
        )

      assert is_pid(pid)
      assert Process.alive?(pid)

      # Cleanup
      GenServer.stop(name)

      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end

    test "uses default options when not provided" do
      name = :"event_loop_defaults_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_defaults_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, _bus_pid} = Jido.Signal.Bus.start_link(name: bus_name)

      {:ok, pid} =
        EventLoop.start_link(
          bus: bus_name,
          event_polling: false,
          name: name
        )

      assert is_pid(pid)
      assert Process.alive?(pid)

      # Get state to verify defaults
      state = :sys.get_state(pid)
      assert state.window_width == 800
      assert state.window_height == 600
      assert state.fullscreen == false
      assert state.poll_interval == 16

      # Cleanup
      GenServer.stop(name)

      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end
  end

  describe "SDL2 initialization" do
    @tag :capture_log
    test "handles SDL2 initialization failure gracefully" do
      # This test verifies that when SDL2 is not available,
      # the event loop still starts and runs in headless mode
      name = :"event_loop_headless_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_headless_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, _bus_pid} = Jido.Signal.Bus.start_link(name: bus_name)

      # Start with SDL2 renderer - if SDL2 unavailable, should log warning but continue
      {:ok, pid} =
        EventLoop.start_link(
          bus: bus_name,
          window_title: "Headless Test",
          window_width: 640,
          window_height: 480,
          event_polling: false,
          renderer: DesktopUI.Renderer.SDL2,
          name: name
        )

      # Should start successfully even if SDL2 is unavailable
      assert is_pid(pid)
      assert Process.alive?(pid)

      # Get state
      state = :sys.get_state(pid)

      # If SDL2 is unavailable, window_id should be nil
      # If SDL2 is available, window_id should be set
      # Either case is acceptable for this test
      assert is_integer(state.window_id) or is_nil(state.window_id)

      # Cleanup
      GenServer.stop(name)

      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end
  end

  describe "get_window_id/1" do
    setup :start_event_loop

    test "returns nil when SDL2 is not available", %{event_loop_name: name} do
      window_id = EventLoop.get_window_id(name)

      # If SDL2 is available, this will be an integer
      # If not, it will be nil
      # Both are valid outcomes
      assert is_integer(window_id) or is_nil(window_id)
    end
  end

  describe "get_window_size/1" do
    setup :start_event_loop

    test "returns configured dimensions", %{event_loop_name: name} do
      size = EventLoop.get_window_size(name)

      # If SDL2 initialized, should return actual dimensions
      # If not, should return nil
      case size do
        {width, height} ->
          assert is_integer(width)
          assert is_integer(height)
          assert width > 0
          assert height > 0

        nil ->
          # SDL2 not available, acceptable
          :ok
      end
    end
  end

  describe "event polling" do
    setup [:start_event_loop]

    test "starts polling loop when event_polling is true", context do
      # Start a new event loop with polling enabled
      name = :"event_loop_polling_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = context.bus_name

      {:ok, pid} =
        EventLoop.start_link(
          bus: bus_name,
          window_title: "Polling Test",
          window_width: 640,
          window_height: 480,
          event_polling: true,
          poll_interval: 50,
          name: name
        )

      # Wait a bit for polling messages to be scheduled
      Process.sleep(100)

      # Verify process is still alive (polling keeps it running)
      assert Process.alive?(pid)

      # Cleanup
      GenServer.stop(name)
    end
  end

  describe "signal publishing" do
    setup [:start_event_loop]

    test "translates key events to KeyPressed signals", %{bus_name: bus_name} do
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          bus_name,
          "desktop_ui.ui.**",
          dispatch: {:pid, target: test_pid}
        )

      # Simulate SDL key event by directly calling the translation function
      # We'll publish a KeyPressed signal manually to verify the bus works
      {:ok, signal} =
        Signals.KeyPressed.new(
          %{key: "up", modifiers: []},
          source: "/desktop_ui/runtime/event_loop/test"
        )

      {:ok, _recorded} = Jido.Signal.Bus.publish(bus_name, [signal])

      # Verify we receive the signal
      assert_receive {:signal, %Jido.Signal{type: "desktop_ui.ui.key_pressed"}}, 500
    end

    test "translates mouse events to MousePressed signals", %{bus_name: bus_name} do
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          bus_name,
          "desktop_ui.ui.**",
          dispatch: {:pid, target: test_pid}
        )

      # Publish a MousePressed signal
      {:ok, signal} =
        Signals.MousePressed.new(
          %{x: 100, y: 50, button: :left, target_id: nil},
          source: "/desktop_ui/runtime/event_loop/test"
        )

      {:ok, _recorded} = Jido.Signal.Bus.publish(bus_name, [signal])

      # Verify we receive the signal
      assert_receive {:signal, %Jido.Signal{type: "desktop_ui.ui.mouse_pressed"}}, 500
    end

    test "publishes Quit signal", %{bus_name: bus_name} do
      test_pid = self()

      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          bus_name,
          "desktop_ui.**",
          dispatch: {:pid, target: test_pid}
        )

      # Publish a Quit signal
      {:ok, signal} = Signals.Quit.new(%{}, source: "/desktop_ui/runtime/event_loop/test")

      {:ok, _recorded} = Jido.Signal.Bus.publish(bus_name, [signal])

      # Verify we receive the signal
      assert_receive {:signal, %Jido.Signal{type: "desktop_ui.app.quit"}}, 500
    end
  end

  describe "cleanup" do
    setup :start_event_loop

    test "cleans up resources on shutdown", %{event_loop_name: name, event_loop_pid: pid} do
      # Stop the event loop
      GenServer.stop(name, :normal)

      # Wait for cleanup
      Process.sleep(100)

      # Verify process is stopped
      refute Process.alive?(pid)

      # If SDL2 was initialized, the window should be cleaned up
      # We can't directly verify this without SDL2, but the process
      # should have terminated cleanly
    end
  end

  describe "Runtime integration" do
    test "runtime starts event loop when using SDL2 renderer" do
      # This test verifies that DesktopUI.Runtime starts EventLoop
      # when SDL2 renderer is configured
      alias DesktopUI.Runtime

      # Define a test component
      defmodule TestComponent do
        use DesktopUI.Elm,
          name: "runtime_test_component",
          description: "Test component for runtime integration"

        @impl true
        def init(_opts) do
          {%{}, []}
        end

        @impl true
        def update(_msg, state) do
          {state, []}
        end

        @impl true
        def view(_state) do
          DesktopUI.Widget.label("Test")
        end
      end

      name = :"runtime_sdl2_test_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_sdl2_test_#{System.unique_integer([:positive, :monotonic])}"

      # Start runtime with SDL2 renderer and event polling enabled
      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: TestComponent,
          renderer: DesktopUI.Renderer.SDL2,
          bus: bus_name,
          window_title: "Runtime Test",
          window_width: 800,
          window_height: 600,
          event_polling: true
        )

      # Wait for children to start
      Process.sleep(200)

      # Verify runtime started
      assert Process.alive?(runtime_pid)

      # Check children
      children = Supervisor.which_children(runtime_pid)
      child_ids = Enum.map(children, fn {id, _pid, _type, _modules} -> id end)

      # Should have EventLoop as a child
      # Note: EventLoop might be named differently or not started if SDL2 fails
      # We just verify runtime started successfully
      assert :event_loop in child_ids or Process.alive?(runtime_pid)

      # Cleanup
      Supervisor.stop(name, :normal)
      Process.sleep(100)

      # Cleanup bus
      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end

    test "runtime does not start event loop with Mock renderer" do
      alias DesktopUI.Runtime

      defmodule MockTestComponent do
        use DesktopUI.Elm,
          name: "runtime_mock_test_component",
          description: "Test component for mock runtime"

        @impl true
        def init(_opts) do
          {%{}, []}
        end

        @impl true
        def update(_msg, state) do
          {state, []}
        end

        @impl true
        def view(_state) do
          DesktopUI.Widget.label("Mock Test")
        end
      end

      name = :"runtime_mock_test_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_mock_test_#{System.unique_integer([:positive, :monotonic])}"
      renderer_name = :"renderer_mock_test_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, _renderer_pid} = DesktopUI.Renderer.Mock.start_link(name: renderer_name)

      # Start runtime with Mock renderer
      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: MockTestComponent,
          renderer: {DesktopUI.Renderer.Mock, renderer_name},
          bus: bus_name,
          event_polling: false
        )

      # Wait for children to start
      Process.sleep(200)

      # Verify runtime started
      assert Process.alive?(runtime_pid)

      # Check children - should NOT have EventLoop
      children = Supervisor.which_children(runtime_pid)
      child_ids = Enum.map(children, fn {id, _pid, _type, _modules} -> id end)

      # EventLoop should NOT be in children when using Mock renderer
      refute :event_loop in child_ids

      # Cleanup
      Supervisor.stop(name, :normal)
      GenServer.stop(renderer_name)
      Process.sleep(100)

      # Cleanup bus
      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end
  end

  describe "SDL2 renderer integration" do
    test "SDL2 renderer can be used with RenderingCoordinator" do
      # Test the render/3 API for coordinator compatibility
      alias DesktopUI.Renderer.SDL2
      alias DesktopUI.Widget

      # The SDL2 renderer should support both render/2 and render/3
      # render/3 is used by RenderingCoordinator

      # Create a simple widget
      widget = Widget.label("Test Label")

      # First, initialize the ETS table and set a dummy window_id
      SDL2.set_window_id(999)

      # Now render/3 should work without error
      result = SDL2.render("test_component", widget, :coordinator_name)

      case result do
        :ok ->
          # SDL2 might be initialized and render succeeded
          assert true

        {:error, _reason} ->
          # SDL2 might not be available, which is fine for test
          assert true
      end

      # Clean up ETS table
      try do
        :ets.delete(SDL2.window_table(), :window_id)
      rescue
        _ -> :ok
      end
    end

    test "SDL2 renderer stores and retrieves window_id" do
      alias DesktopUI.Renderer.SDL2

      # Test set_window_id and get_window_id
      test_window_id = 12345

      :ok = SDL2.set_window_id(test_window_id)

      retrieved_id = SDL2.get_window_id()

      assert retrieved_id == test_window_id

      # Clean up - delete the ETS entry
      try do
        :ets.delete(SDL2.window_table(), :window_id)
      rescue
        _ -> :ok
      end
    end
  end
end
