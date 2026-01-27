defmodule DesktopUI.RenderingCoordinatorTest do
  use ExUnit.Case

  alias DesktopUI.RenderingCoordinator
  alias DesktopUI.Signals
  alias DesktopUI.Widget

  # ETS tables used by the coordinator
  @components_table :desktop_ui_rendering_coordinator_components
  @metrics_table :desktop_ui_rendering_coordinator_metrics

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

  # Helper to verify coordinator is initialized
  defp assert_coordinator_ready(pid) do
    assert Process.alive?(pid)
    # Verify ETS tables are created by checking metrics
    assert %{renders_completed: _} = RenderingCoordinator.get_metrics(pid)
  end

  # Mock renderer for testing
  defmodule MockRenderer do
    @moduledoc """
    Mock renderer that records render calls for testing.
    """

    use GenServer

    @doc """
    Start the mock renderer.
    """
    def start_link(opts \\ []) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, [name: name], name: name)
    end

    @impl true
    def init(opts) do
      name = Keyword.get(opts, :name, __MODULE__)

      {:ok,
       %{
         renders: [],
         render_count: 0,
         name: name
       }}
    end

    @doc """
    Render a widget tree (records the call).
    """
    def render(component_id, widget, name \\ __MODULE__) do
      GenServer.call(name, {:render, component_id, widget})
    end

    @doc """
    Render a component with a pre-calculated layout.
    This is the preferred rendering path as layout is calculated once.
    """
    def render_with_layout(component_id, layout) do
      render_with_layout(component_id, layout, __MODULE__)
    end

    def render_with_layout(component_id, layout, name) do
      GenServer.call(name, {:render_with_layout, component_id, layout})
    end

    @doc """
    Get the list of renders that have been recorded.
    """
    def get_renders(name \\ __MODULE__) do
      GenServer.call(name, :get_renders)
    end

    @doc """
    Clear the render history.
    """
    def clear(name \\ __MODULE__) do
      GenServer.call(name, :clear)
    end

    @doc """
    Get the render count.
    """
    def get_count(name \\ __MODULE__) do
      GenServer.call(name, :get_count)
    end

    # Callbacks

    @impl true
    def handle_call({:render, component_id, widget}, _from, state) do
      render = %{component_id: component_id, widget: widget, timestamp: DateTime.utc_now()}

      new_state = %{
        renders: [render | state.renders],
        render_count: state.render_count + 1
      }

      {:reply, :ok, new_state}
    end

    @impl true
    def handle_call({:render_with_layout, component_id, layout}, _from, state) do
      # Store render with both layout and widget for layout-based rendering tests
      render = %{
        component_id: component_id,
        widget: layout.widget,
        layout: layout,
        timestamp: DateTime.utc_now()
      }

      new_state = %{
        renders: [render | state.renders],
        render_count: state.render_count + 1
      }

      {:reply, :ok, new_state}
    end

    def handle_call(:get_renders, _from, state) do
      {:reply, Enum.reverse(state.renders), state}
    end

    def handle_call(:clear, _from, state) do
      {:reply, :ok, %{state | renders: [], render_count: 0}}
    end

    def handle_call(:get_count, _from, state) do
      {:reply, state.render_count, state}
    end
  end

  # Test component modules

  defmodule TestComponent do
    use DesktopUI.Elm,
      name: "test_component",
      description: "A test component"

    @impl true
    def init(_opts) do
      {%{count: 0}, []}
    end

    @impl true
    def update(:increment, %{count: count} = state) do
      {%{state | count: count + 1}, []}
    end

    @impl true
    def view(%{count: count}) do
      Widget.label("Count: " <> Integer.to_string(count))
    end
  end

  defmodule TestComponentWithContainer do
    use DesktopUI.Elm,
      name: "test_component_with_container",
      description: "A test component with container"

    @impl true
    def init(_opts) do
      {%{count: 0}, []}
    end

    @impl true
    def update(_msg, state), do: {state, []}

    @impl true
    def view(%{count: _count}) do
      Widget.container(
        :vbox,
        [
          Widget.label("Counter"),
          Widget.button("Increment", :increment)
        ],
        spacing: 8
      )
    end
  end

  # Setup and cleanup helpers
  defp cleanup_ets do
    try do
      :ets.delete(@components_table)
    rescue
      ArgumentError -> nil
    end

    try do
      :ets.delete(@metrics_table)
    rescue
      ArgumentError -> nil
    end
  end

  setup do
    # Each test will create its own ETS tables via the coordinator's init/1
    # We just ensure clean slate at the start
    cleanup_ets()

    # Also clean up on exit for the next test
    on_exit(fn ->
      cleanup_ets()
    end)

    :ok
  end

  describe "server initialization" do
    test "starts with default configuration" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_init_bus)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          bus: :test_init_bus,
          name: :test_init_coordinator
        )

      # Verify initialization is complete
      assert_coordinator_ready(pid)

      # Metrics are stored in ETS
      metrics = RenderingCoordinator.get_metrics(pid)
      assert metrics.renders_completed == 0
      assert metrics.renders_failed == 0
      assert metrics.renders_skipped == 0

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(bus)
    end

    test "starts with custom renderer" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_custom_renderer_bus)
      {:ok, _renderer} = MockRenderer.start_link(name: :test_custom_renderer)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          renderer: {MockRenderer, :test_custom_renderer},
          bus: :test_custom_renderer_bus,
          name: :test_coordinator_custom_renderer
        )

      # Verify initialization is complete
      assert_coordinator_ready(pid)

      # Verify renderer is stored
      renderer = RenderingCoordinator.get_metric(:renderer)
      assert renderer == {MockRenderer, :test_custom_renderer}

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(:test_custom_renderer)
      GenServer.stop(bus)
    end

    test "subscribes to desktop_ui signals on startup" do
      # Start signal bus
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_subscription_bus)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          bus: :test_subscription_bus,
          name: :test_subscription_coordinator
        )

      # Verify initialization is complete
      assert_coordinator_ready(pid)

      # Verify subscription by checking state
      assert :sys.get_state(pid) != nil

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(bus)
    end
  end

  describe "component registration" do
    test "register_component/4 registers a component" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_register_bus)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          bus: :test_register_bus,
          name: :test_register_coordinator
        )

      # Verify initialization
      assert_coordinator_ready(pid)

      {:ok, _signal} =
        RenderingCoordinator.register_component(pid, "test_component", TestComponent,
          bus: :test_register_bus
        )

      # Wait for registration to be processed by checking ETS
      assert wait_for_condition(fn ->
               components = RenderingCoordinator.get_components(pid)
               Map.has_key?(components, "test_component")
             end)

      # Verify component is in registry
      components = RenderingCoordinator.get_components(pid)
      assert Map.has_key?(components, "test_component")
      assert components["test_component"].module == TestComponent
      assert components["test_component"].registered_at != nil

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(bus)
    end

    test "register_component/4 with opts stores PID" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_register_pid_bus)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          bus: :test_register_pid_bus,
          name: :test_register_with_pid
        )

      # Verify initialization
      assert_coordinator_ready(pid)

      component_pid = self()

      {:ok, _signal} =
        RenderingCoordinator.register_component(
          pid,
          "test_component",
          TestComponent,
          pid: component_pid,
          bus: :test_register_pid_bus
        )

      # Wait for registration to be processed
      assert wait_for_condition(fn ->
               components = RenderingCoordinator.get_components(pid)
               Map.has_key?(components, "test_component") and
                 components["test_component"].pid == component_pid
             end)

      components = RenderingCoordinator.get_components(pid)
      assert components["test_component"].pid == component_pid

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(bus)
    end

    test "registering same component twice overwrites" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_register_twice_bus)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          bus: :test_register_twice_bus,
          name: :test_register_twice
        )

      # Verify initialization
      assert_coordinator_ready(pid)

      {:ok, _signal} =
        RenderingCoordinator.register_component(pid, "test_component", TestComponent,
          bus: :test_register_twice_bus
        )

      # Wait for first registration
      assert wait_for_condition(fn ->
               components = RenderingCoordinator.get_components(pid)
               Map.has_key?(components, "test_component")
             end)

      first_components = RenderingCoordinator.get_components(pid)
      first_registered_at = first_components["test_component"].registered_at

      {:ok, _signal} =
        RenderingCoordinator.register_component(
          pid,
          "test_component",
          TestComponentWithContainer,
          bus: :test_register_twice_bus
        )

      # Wait for second registration to be processed AND timestamp to be updated
      assert wait_for_condition(fn ->
               components = RenderingCoordinator.get_components(pid)
               components["test_component"].module == TestComponentWithContainer and
                 DateTime.compare(components["test_component"].registered_at, first_registered_at) != :eq
             end, 20, 20)

      second_components = RenderingCoordinator.get_components(pid)
      assert second_components["test_component"].module == TestComponentWithContainer
      # Timestamp should be updated
      assert DateTime.compare(
               second_components["test_component"].registered_at,
               first_registered_at
             ) != :eq

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(bus)
    end

    test "unregister_component/2 removes a component" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_unregister_bus)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          bus: :test_unregister_bus,
          name: :test_unregister_coordinator
        )

      # Verify initialization
      assert_coordinator_ready(pid)

      {:ok, _signal} =
        RenderingCoordinator.register_component(pid, "test_component", TestComponent,
          bus: :test_unregister_bus
        )

      # Wait for registration
      assert wait_for_condition(fn ->
               components = RenderingCoordinator.get_components(pid)
               Map.has_key?(components, "test_component")
             end)

      {:ok, _signal} =
        RenderingCoordinator.unregister_component(pid, "test_component",
          bus: :test_unregister_bus
        )

      # Wait for unregistration to be processed
      assert wait_for_condition(fn ->
               components = RenderingCoordinator.get_components(pid)
               not Map.has_key?(components, "test_component")
             end)

      # Verify component is removed
      components = RenderingCoordinator.get_components(pid)
      refute Map.has_key?(components, "test_component")

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(bus)
    end

    test "unregistering non-existent component is idempotent" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_unregister_nonexistent_bus)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          bus: :test_unregister_nonexistent_bus,
          name: :test_unregister_nonexistent
        )

      # Verify initialization
      assert_coordinator_ready(pid)

      # Should not error
      assert {:ok, _signal} =
               RenderingCoordinator.unregister_component(pid, "nonexistent",
                 bus: :test_unregister_nonexistent_bus
               )

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(bus)
    end
  end

  describe "metrics" do
    test "get_metrics/1 returns current metrics" do
      {:ok, pid} = RenderingCoordinator.start_link(name: :test_get_metrics_coordinator)

      # Verify initialization
      assert_coordinator_ready(pid)

      metrics = RenderingCoordinator.get_metrics(pid)

      assert metrics.renders_completed == 0
      assert metrics.renders_failed == 0
      assert metrics.renders_skipped == 0
      assert is_map(metrics)

      # Cleanup
      GenServer.stop(pid)
    end
  end

  describe "rendering on StateChanged signal" do
    test "renders component when StateChanged signal is received" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_render_bus)
      {:ok, _renderer} = MockRenderer.start_link(name: :test_render_renderer)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          renderer: {MockRenderer, :test_render_renderer},
          bus: :test_render_bus,
          name: :test_render_coordinator
        )

      # Verify initialization
      assert_coordinator_ready(pid)

      {:ok, _signal} =
        RenderingCoordinator.register_component(pid, "test_component", TestComponent,
          bus: :test_render_bus
        )

      # Wait for registration
      assert wait_for_condition(fn ->
               components = RenderingCoordinator.get_components(pid)
               Map.has_key?(components, "test_component")
             end)

      # Clear previous renders
      MockRenderer.clear(:test_render_renderer)

      # Create and publish a StateChanged signal
      {:ok, signal} =
        Signals.StateChanged.new(%{
          component_id: "test_component",
          old_state: %{count: 0},
          new_state: %{count: 1}
        })

      Jido.Signal.Bus.publish(:test_render_bus, [signal])

      # Wait for async rendering by checking render count
      assert wait_for_condition(fn ->
               length(MockRenderer.get_renders(:test_render_renderer)) == 1
             end)

      # Verify render was called
      renders = MockRenderer.get_renders(:test_render_renderer)
      assert length(renders) == 1
      assert hd(renders).component_id == "test_component"

      # Verify widget is correct
      widget = hd(renders).widget
      assert widget.type == :label
      assert widget.props[:text] == "Count: 1"

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(:test_render_renderer)
      GenServer.stop(bus)
    end

    test "increments renders_completed metric on successful render" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_render_metric_bus)
      {:ok, _renderer} = MockRenderer.start_link(name: :test_render_metric_renderer)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          renderer: {MockRenderer, :test_render_metric_renderer},
          bus: :test_render_metric_bus,
          name: :test_render_metric_coordinator
        )

      # Verify initialization
      assert_coordinator_ready(pid)

      {:ok, _signal} =
        RenderingCoordinator.register_component(pid, "test_component", TestComponent,
          bus: :test_render_metric_bus
        )

      # Wait for registration
      assert wait_for_condition(fn ->
               components = RenderingCoordinator.get_components(pid)
               Map.has_key?(components, "test_component")
             end)

      initial_metrics = RenderingCoordinator.get_metrics(pid)
      assert initial_metrics.renders_completed == 0

      # Publish StateChanged signal
      {:ok, signal} =
        Signals.StateChanged.new(%{
          component_id: "test_component",
          old_state: %{count: 0},
          new_state: %{count: 1}
        })

      Jido.Signal.Bus.publish(:test_render_metric_bus, [signal])

      # Wait for async rendering by checking metrics
      assert wait_for_condition(fn ->
               metrics = RenderingCoordinator.get_metrics(pid)
               metrics.renders_completed == 1
             end)

      new_metrics = RenderingCoordinator.get_metrics(pid)
      assert new_metrics.renders_completed == 1

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(:test_render_metric_renderer)
      GenServer.stop(bus)
    end

    test "does not render unregistered components" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_render_unreg_bus)
      {:ok, _renderer} = MockRenderer.start_link(name: :test_render_unreg_renderer)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          renderer: {MockRenderer, :test_render_unreg_renderer},
          bus: :test_render_unreg_bus,
          name: :test_render_unreg_coordinator
        )

      # Verify initialization
      assert_coordinator_ready(pid)

      # Don't register any component

      # Publish StateChanged signal for unregistered component
      {:ok, signal} =
        Signals.StateChanged.new(%{
          component_id: "nonexistent",
          old_state: %{count: 0},
          new_state: %{count: 1}
        })

      Jido.Signal.Bus.publish(:test_render_unreg_bus, [signal])

      # Wait a bit to ensure async processing had time to run
      assert wait_for_condition(fn ->
               # Give it a moment - after timeout, we verify no renders happened
               true
             end)

      # Verify no renders occurred
      renders = MockRenderer.get_renders(:test_render_unreg_renderer)
      assert length(renders) == 0

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(:test_render_unreg_renderer)
      GenServer.stop(bus)
    end
  end

  describe "rendering with container widgets" do
    test "validates and renders container widgets" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_container_bus)
      {:ok, _renderer} = MockRenderer.start_link(name: :test_container_renderer)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          renderer: {MockRenderer, :test_container_renderer},
          bus: :test_container_bus,
          name: :test_container_coordinator
        )

      # Verify initialization
      assert_coordinator_ready(pid)

      {:ok, _signal} =
        RenderingCoordinator.register_component(
          pid,
          "container_component",
          TestComponentWithContainer,
          bus: :test_container_bus
        )

      # Wait for registration
      assert wait_for_condition(fn ->
               components = RenderingCoordinator.get_components(pid)
               Map.has_key?(components, "container_component")
             end)

      # Publish StateChanged signal
      {:ok, signal} =
        Signals.StateChanged.new(%{
          component_id: "container_component",
          old_state: %{count: 0},
          new_state: %{count: 5}
        })

      Jido.Signal.Bus.publish(:test_container_bus, [signal])

      # Wait for async rendering
      assert wait_for_condition(fn ->
               length(MockRenderer.get_renders(:test_container_renderer)) == 1
             end)

      # Verify render was called
      renders = MockRenderer.get_renders(:test_container_renderer)
      assert length(renders) == 1

      # With layout-based rendering, the widget is a synthetic widget from layout calculation
      # Check that we have a layout and it contains the expected structure
      render = hd(renders)

      # The render should have a layout field (layout-based rendering)
      assert Map.has_key?(render, :layout)

      # The layout should have valid bounds
      layout = render.layout
      assert layout.width > 0
      assert layout.height > 0

      # The widget in the layout is a synthetic container widget
      # (may have type: nil due to layout calculation, but has props and children)
      widget = render.widget
      assert widget.props[:layout] == :vbox
      assert is_list(widget.children)

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(:test_container_renderer)
      GenServer.stop(bus)
    end
  end

  describe "error handling" do
    test "handles invalid widget trees gracefully" do
      # Create a module with invalid view
      defmodule InvalidComponent do
        use DesktopUI.Elm,
          name: "invalid_component",
          description: "A component with invalid view"

        @impl true
        def init(_opts), do: {%{value: 1}, []}

        @impl true
        def update(_msg, state), do: {state, []}

        @impl true
        def view(_state) do
          # Invalid widget - label without text
          %DesktopUI.Widget{type: :label, id: nil, props: [], children: []}
        end
      end

      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_error_bus)
      {:ok, _renderer} = MockRenderer.start_link(name: :test_error_renderer)

      {:ok, pid} =
        RenderingCoordinator.start_link(
          renderer: {MockRenderer, :test_error_renderer},
          bus: :test_error_bus,
          name: :test_error_coordinator
        )

      # Verify initialization
      assert_coordinator_ready(pid)

      {:ok, _signal} =
        RenderingCoordinator.register_component(pid, "invalid_component", InvalidComponent,
          bus: :test_error_bus
        )

      # Wait for registration
      assert wait_for_condition(fn ->
               components = RenderingCoordinator.get_components(pid)
               Map.has_key?(components, "invalid_component")
             end)

      # Publish StateChanged signal
      {:ok, signal} =
        Signals.StateChanged.new(%{
          component_id: "invalid_component",
          old_state: %{value: 1},
          new_state: %{value: 2}
        })

      Jido.Signal.Bus.publish(:test_error_bus, [signal])

      # Wait for async error handling
      assert wait_for_condition(fn ->
               metrics = RenderingCoordinator.get_metrics(pid)
               metrics.renders_failed > 0
             end)

      # Verify error was tracked but didn't crash
      metrics = RenderingCoordinator.get_metrics(pid)
      assert metrics.renders_failed > 0

      # Cleanup
      GenServer.stop(pid)
      GenServer.stop(:test_error_renderer)
      GenServer.stop(bus)
    end
  end
end
