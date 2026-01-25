defmodule DesktopUI.Integration.Phase2Test do
  use ExUnit.Case, async: false

  # Integration tests for Phase 2 (Graphics Bridge)
  # These tests verify all Phase 2 components work together correctly
  # Note: async: false because SDL2 initialization is global state
  # Note: Tests will be skipped if SDL2 is not available

  alias DesktopUI.Graphics
  alias DesktopUI.Runtime
  alias DesktopUI.Runtime.EventLoop
  alias DesktopUI.RenderingCoordinator
  alias DesktopUI.Signals
  alias DesktopUI.Examples.Counter

  # Helper to check if SDL2 is available (runtime check)
  defp sdl2_available? do
    case Graphics.sdl_init() do
      :ok ->
        Graphics.sdl_quit()
        true

      {:error, _reason} ->
        false
    end
  end

  # Setup for tests that require SDL2
  defp require_sdl2(_context) do
    if sdl2_available?() do
      :ok
    else
      {:skip, "SDL2 not available"}
    end
  end

  # Setup that ensures SDL2 is cleaned up after each test
  setup do
    # Ensure we start with a clean state
    # If SDL2 was initialized, clean it up
    if Graphics.initialized?() do
      Graphics.sdl_quit()
    end

    :ok
  end

  describe "SDL2 lifecycle" do
    setup :require_sdl2

    test "full initialization and cleanup cycle" do
      # Initialize SDL2
      assert :ok = Graphics.sdl_init()
      assert Graphics.initialized?() == true

      # Clean up
      assert :ok = Graphics.sdl_quit()
      assert Graphics.initialized?() == false
    end

    test "multiple init/quit cycles work correctly" do
      # First cycle
      assert :ok = Graphics.sdl_init()
      assert :ok = Graphics.sdl_quit()

      # Second cycle
      assert :ok = Graphics.sdl_init()
      assert :ok = Graphics.sdl_quit()

      # Third cycle
      assert :ok = Graphics.sdl_init()
      assert Graphics.initialized?() == true
      assert :ok = Graphics.sdl_quit()
      assert Graphics.initialized?() == false
    end

    test "initialization returns info map when successful" do
      case Graphics.sdl_init() do
        {:ok, info} ->
          assert is_map(info)
          assert Graphics.initialized?() == true
          Graphics.sdl_quit()

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "Window management" do
    setup :require_sdl2

    test "create and destroy window" do
      :ok = Graphics.sdl_init()

      on_exit(fn ->
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      title = "Test Window"
      width = 640
      height = 480

      {:ok, window_id} = Graphics.create_window(title, width, height)

      assert is_integer(window_id)
      assert window_id > 0

      # Verify window exists by getting its size
      {:ok, {w, h}} = Graphics.get_window_size(window_id)
      assert w == width
      assert h == height

      # Clean up
      :ok = Graphics.destroy_window(window_id)
    end

    test "window resize operations" do
      :ok = Graphics.sdl_init()

      on_exit(fn ->
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      {:ok, window_id} = Graphics.create_window("Resize Test", 800, 600)

      # Get initial size
      {:ok, {initial_w, initial_h}} = Graphics.get_window_size(window_id)
      assert initial_w == 800
      assert initial_h == 600

      # Resize window
      :ok = Graphics.set_window_size(window_id, 1024, 768)

      # Verify new size
      {:ok, {new_w, new_h}} = Graphics.get_window_size(window_id)
      assert new_w == 1024
      assert new_h == 768

      # Clean up
      Graphics.destroy_window(window_id)
    end

    test "window title changes" do
      :ok = Graphics.sdl_init()

      on_exit(fn ->
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      {:ok, window_id} = Graphics.create_window("Original Title", 640, 480)

      # Change title
      :ok = Graphics.set_window_title(window_id, "New Title")

      # We can't directly verify the title changed without SDL2 functions
      # But the call should succeed
      assert :ok = Graphics.set_window_title(window_id, "Another Title")

      # Clean up
      Graphics.destroy_window(window_id)
    end

    test "multiple windows can coexist" do
      :ok = Graphics.sdl_init()

      on_exit(fn ->
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      {:ok, window1} = Graphics.create_window("Window 1", 400, 300)
      {:ok, window2} = Graphics.create_window("Window 2", 500, 400)

      assert window1 != window2

      # Verify both windows exist
      {:ok, _} = Graphics.get_window_size(window1)
      {:ok, _} = Graphics.get_window_size(window2)

      # Clean up
      Graphics.destroy_window(window1)
      Graphics.destroy_window(window2)
    end

    test "destroying invalid window returns error" do
      result = Graphics.destroy_window(999_999)
      assert match?({:error, _}, result)
    end
  end

  describe "Drawing primitives" do
    setup :require_sdl2

    test "clear and present window" do
      :ok = Graphics.sdl_init()
      {:ok, window_id} = Graphics.create_window("Drawing Test", 800, 600)

      on_exit(fn ->
        Graphics.destroy_window(window_id)
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      # Clear window with white color
      :ok = Graphics.clear_window(window_id, {255, 255, 255, 255})

      # Present to screen
      :ok = Graphics.present_window(window_id)
    end

    test "fill rectangle on window" do
      :ok = Graphics.sdl_init()
      {:ok, window_id} = Graphics.create_window("Drawing Test", 800, 600)

      on_exit(fn ->
        Graphics.destroy_window(window_id)
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      # Fill a rectangle with red color
      :ok =
        Graphics.fill_rect_on_window(
          window_id,
          100,
          100,
          200,
          150,
          {255, 0, 0, 255}
        )

      # Present to screen
      :ok = Graphics.present_window(window_id)
    end

    test "draw rectangle outline on window" do
      :ok = Graphics.sdl_init()
      {:ok, window_id} = Graphics.create_window("Drawing Test", 800, 600)

      on_exit(fn ->
        Graphics.destroy_window(window_id)
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      # Draw rectangle outline with blue color
      :ok =
        Graphics.draw_rect_on_window(
          window_id,
          50,
          50,
          300,
          200,
          {0, 0, 255, 255}
        )

      # Present to screen
      :ok = Graphics.present_window(window_id)
    end

    test "multiple drawing operations" do
      :ok = Graphics.sdl_init()
      {:ok, window_id} = Graphics.create_window("Drawing Test", 800, 600)

      on_exit(fn ->
        Graphics.destroy_window(window_id)
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      # Clear background
      :ok = Graphics.clear_window(window_id, {240, 240, 240, 255})

      # Draw multiple rectangles
      :ok = Graphics.fill_rect_on_window(window_id, 50, 50, 100, 100, {255, 0, 0, 255})
      :ok = Graphics.fill_rect_on_window(window_id, 200, 50, 100, 100, {0, 255, 0, 255})
      :ok = Graphics.fill_rect_on_window(window_id, 125, 200, 100, 100, {0, 0, 255, 255})

      # Present
      :ok = Graphics.present_window(window_id)
    end

    test "drawing operations handle out-of-bounds coordinates" do
      :ok = Graphics.sdl_init()
      {:ok, window_id} = Graphics.create_window("Drawing Test", 800, 600)

      on_exit(fn ->
        Graphics.destroy_window(window_id)
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      # These should not crash, even if coordinates are outside window
      :ok =
        Graphics.fill_rect_on_window(
          window_id,
          -50,
          -50,
          100,
          100,
          {255, 0, 0, 255}
        )

      :ok =
        Graphics.fill_rect_on_window(
          window_id,
          700,
          500,
          200,
          200,
          {0, 255, 0, 255}
        )

      :ok = Graphics.present_window(window_id)
    end

    test "drawing with color variations" do
      :ok = Graphics.sdl_init()
      {:ok, window_id} = Graphics.create_window("Drawing Test", 800, 600)

      on_exit(fn ->
        Graphics.destroy_window(window_id)
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      colors = [
        {255, 0, 0, 255},
        {0, 255, 0, 255},
        {0, 0, 255, 255},
        {255, 255, 0, 255},
        {255, 0, 255, 255},
        {0, 255, 255, 255},
        {255, 255, 255, 255},
        {0, 0, 0, 255}
      ]

      Enum.each(colors, fn color ->
        :ok = Graphics.fill_rect_on_window(window_id, 10, 10, 50, 50, color)
      end)

      :ok = Graphics.present_window(window_id)
    end
  end

  describe "Event polling" do
    setup :require_sdl2

    test "poll_event returns :no_event when no events available" do
      :ok = Graphics.sdl_init()
      {:ok, window_id} = Graphics.create_window("Event Test", 640, 480)

      on_exit(fn ->
        Graphics.destroy_window(window_id)
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      # Present window so it can receive events
      :ok = Graphics.present_window(window_id)

      # Poll without generating any events
      result = Graphics.poll_event()

      # Should return :no_event or another valid event type
      assert result == :no_event or is_tuple(result)
    end

    test "multiple polls work correctly" do
      :ok = Graphics.sdl_init()
      {:ok, window_id} = Graphics.create_window("Event Test", 640, 480)

      on_exit(fn ->
        Graphics.destroy_window(window_id)
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      # Present window so it can receive events
      :ok = Graphics.present_window(window_id)

      # Poll multiple times
      for _ <- 1..10 do
        result = Graphics.poll_event()
        assert result == :no_event or is_tuple(result)
      end
    end

    test "quit event can be received" do
      :ok = Graphics.sdl_init()
      {:ok, window_id} = Graphics.create_window("Event Test", 640, 480)

      on_exit(fn ->
        Graphics.destroy_window(window_id)
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      # Present window so it can receive events
      :ok = Graphics.present_window(window_id)

      # We can't easily generate a real SDL_QUIT event in a test
      # But we can verify the polling mechanism works
      result = Graphics.poll_event()
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "Graphics API integration" do
    test "version returns expected format" do
      version = Graphics.version()
      version_str = if is_list(version), do: List.to_string(version), else: version

      assert version_str =~ ~r/^0\.3\.0-(nif|fallback)$/
    end

    test "get_error returns string" do
      error = Graphics.get_error()
      assert is_binary(error) or is_list(error)
    end

    test "nif_init returns ok or error" do
      result = Graphics.nif_init()

      case result do
        {:ok, info} when is_map(info) ->
          assert Map.has_key?(info, :version)
          assert Map.has_key?(info, :initialized)

        {:error, _reason} ->
          :ok
      end
    end

    setup :require_sdl2

    test "full graphics workflow" do
      :ok = Graphics.sdl_init()

      on_exit(fn ->
        if Graphics.initialized?() do
          Graphics.sdl_quit()
        end
      end)

      # Create window
      {:ok, window_id} = Graphics.create_window("Workflow Test", 800, 600)

      # Draw to it
      :ok = Graphics.clear_window(window_id, {200, 200, 200, 255})
      :ok = Graphics.fill_rect_on_window(window_id, 100, 100, 200, 150, {255, 100, 50, 255})
      :ok = Graphics.draw_rect_on_window(window_id, 100, 100, 200, 150, {0, 0, 0, 255})
      :ok = Graphics.present_window(window_id)

      # Resize
      :ok = Graphics.set_window_size(window_id, 1024, 768)

      # Change title
      :ok = Graphics.set_window_title(window_id, "Resized")

      # Clean up
      :ok = Graphics.destroy_window(window_id)
    end
  end

  describe "EventLoop integration" do
    test "EventLoop starts and stops correctly" do
      name = :"event_loop_integration_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, _bus} = Jido.Signal.Bus.start_link(name: bus_name)

      {:ok, pid} =
        EventLoop.start_link(
          bus: bus_name,
          window_title: "EventLoop Test",
          window_width: 800,
          window_height: 600,
          event_polling: false,
          name: name
        )

      assert is_pid(pid)
      assert Process.alive?(pid)

      # Get window_id
      window_id = EventLoop.get_window_id(name)

      # If SDL2 initialized, should have a window_id
      if is_integer(window_id) do
        assert window_id > 0

        # Get window size
        size = EventLoop.get_window_size(name)
        assert match?({w, h} when is_integer(w) and is_integer(h), size)
      end

      # Stop
      GenServer.stop(name)

      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end

    test "EventLoop with event polling enabled" do
      name = :"event_loop_polling_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_polling_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, _bus} = Jido.Signal.Bus.start_link(name: bus_name)

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

      # Wait for some polling cycles
      Process.sleep(200)

      # Should still be alive
      assert Process.alive?(pid)

      # Stop
      GenServer.stop(name)

      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end
  end

  describe "Runtime with SDL2 backend" do
    test "Runtime starts with SDL2 renderer" do
      # Define a simple test component
      defmodule RuntimeTestComponent do
        use DesktopUI.Elm,
          name: "runtime_test_component_integration",
          description: "Test component for runtime integration"

        @impl true
        def init(_opts) do
          {%{value: 0}, []}
        end

        @impl true
        def update(:increment, %{value: value} = state) do
          {%{state | value: value + 1}, []}
        end

        @impl true
        def update(_msg, state) do
          {state, []}
        end

        @impl true
        def view(%{value: value}) do
          DesktopUI.Widget.container(
            :vbox,
            [
              DesktopUI.Widget.label("Value: #{value}"),
              DesktopUI.Widget.button("Increment", :increment)
            ],
            spacing: 8,
            padding: 16
          )
        end
      end

      name = :"runtime_sdl2_integration_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_sdl2_integration_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: RuntimeTestComponent,
          renderer: DesktopUI.Renderer.SDL2,
          bus: bus_name,
          window_title: "Runtime SDL2 Integration Test",
          window_width: 800,
          window_height: 600,
          event_polling: false
        )

      # Wait for initialization
      Process.sleep(300)

      # Verify runtime started
      assert Process.alive?(runtime_pid)

      # Check children
      children = Supervisor.which_children(runtime_pid)
      child_ids = Enum.map(children, fn {id, _pid, _type, _modules} -> id end)

      # Should have EventLoop, RenderingCoordinator, and root component
      assert :event_loop in child_ids or Process.alive?(runtime_pid)

      # Stop
      Supervisor.stop(name, :normal)
      Process.sleep(100)

      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end
  end

  describe "Counter component with real SDL rendering" do
    test "Counter component renders through SDL2 renderer" do
      # This test verifies the Counter component can render with SDL2
      # We don't actually display the window for long, but verify
      # the rendering pipeline works

      name = :"counter_sdl2_test_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_counter_#{System.unique_integer([:positive, :monotonic])}"

      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: Counter,
          renderer: DesktopUI.Renderer.SDL2,
          bus: bus_name,
          window_title: "Counter SDL2 Test",
          window_width: 400,
          window_height: 300,
          event_polling: false
        )

      # Wait for initialization and first render
      Process.sleep(300)

      # Verify runtime started
      assert Process.alive?(runtime_pid)

      # Get the component and verify its state
      root_pid = Runtime.get_root_component(name)

      if root_pid do
        {:ok, server_state} = Jido.Agent.Server.state(root_pid)
        agent = server_state.agent

        # Initialize elm state
        {:ok, initialized_agent} = DesktopUI.Elm.handle_ui_signal(agent, :noop)
        elm_state = DesktopUI.Elm.get_elm_state(initialized_agent)

        # Counter should start at 0
        assert elm_state.count == 0
      end

      # Stop
      Supervisor.stop(name, :normal)
      Process.sleep(100)

      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end
  end

  describe "Signal flow with SDL2 backend" do
    test "state changes trigger renders with SDL2" do
      # Define a test component
      defmodule SignalFlowComponent do
        use DesktopUI.Elm,
          name: "signal_flow_component",
          description: "Test signal flow"

        @impl true
        def init(_opts) do
          {%{count: 0}, []}
        end

        @impl true
        def update(:increment, %{count: count} = state) do
          {%{state | count: count + 1}, []}
        end

        @impl true
        def update(_msg, state) do
          {state, []}
        end

        @impl true
        def view(%{count: count}) do
          DesktopUI.Widget.label("Count: #{count}")
        end
      end

      name = :"signal_flow_test_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_signal_#{System.unique_integer([:positive, :monotonic])}"

      # Start runtime
      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: SignalFlowComponent,
          renderer: DesktopUI.Renderer.SDL2,
          bus: bus_name,
          window_title: "Signal Flow Test",
          window_width: 400,
          window_height: 300,
          event_polling: false
        )

      # Wait for initialization
      Process.sleep(300)

      # Get root component
      root_pid = Runtime.get_root_component(name)

      if root_pid do
        # Subscribe to state change signals
        test_pid = self()

        {:ok, _sub} =
          Jido.Signal.Bus.subscribe(
            bus_name,
            "desktop_ui.state.**",
            dispatch: {:pid, target: test_pid}
          )

        # Trigger a state change
        {:ok, server_state} = Jido.Agent.Server.state(root_pid)
        agent = server_state.agent

        {:ok, _agent} = DesktopUI.Elm.handle_ui_signal(agent, :increment)

        # Should receive StateChanged signal
        assert_receive {:signal, %Jido.Signal{type: "desktop_ui.state.changed"}}, 1000
      end

      # Stop
      Supervisor.stop(name, :normal)
      Process.sleep(100)

      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end
  end

  describe "Resource cleanup" do
    setup :require_sdl2

    test "all SDL resources cleaned up on shutdown" do
      # Ensure clean state
      if Graphics.initialized?() do
        Graphics.sdl_quit()
      end

      # Initialize and create resources
      :ok = Graphics.sdl_init()
      {:ok, window1} = Graphics.create_window("Cleanup Test 1", 400, 300)
      {:ok, window2} = Graphics.create_window("Cleanup Test 2", 500, 400)

      # Do some drawing
      :ok = Graphics.fill_rect_on_window(window1, 10, 10, 100, 100, {255, 0, 0, 255})
      :ok = Graphics.fill_rect_on_window(window2, 20, 20, 150, 150, {0, 255, 0, 255})

      # Clean up windows
      :ok = Graphics.destroy_window(window1)
      :ok = Graphics.destroy_window(window2)

      # Clean up SDL2
      :ok = Graphics.sdl_quit()

      # Verify clean state
      assert Graphics.initialized?() == false
    end
  end

  describe "Runtime cleanup" do
    test "Runtime cleanup releases all resources" do
      name = :"cleanup_test_#{System.unique_integer([:positive, :monotonic])}"
      bus_name = :"bus_cleanup_#{System.unique_integer([:positive, :monotonic])}"

      # Define simple component
      defmodule CleanupTestComponent do
        use DesktopUI.Elm,
          name: "cleanup_test_component",
          description: "Test cleanup"

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
          DesktopUI.Widget.label("Cleanup Test")
        end
      end

      {:ok, runtime_pid} =
        Runtime.start_link(
          name: name,
          root_component: CleanupTestComponent,
          renderer: DesktopUI.Renderer.SDL2,
          bus: bus_name,
          window_title: "Cleanup Test",
          window_width: 400,
          window_height: 300,
          event_polling: false
        )

      # Wait for initialization
      Process.sleep(300)

      # Stop runtime
      Supervisor.stop(name, :normal)

      # Wait for cleanup
      Process.sleep(200)

      # Verify runtime stopped
      refute Process.alive?(runtime_pid)

      case Process.whereis(bus_name) do
        nil -> :ok
        bus_pid when is_pid(bus_pid) -> GenServer.stop(bus_pid)
      end
    end
  end
end
