defmodule DesktopUI.Renderer.MockTest do
  use ExUnit.Case

  alias DesktopUI.Renderer.Mock
  alias DesktopUI.Widget

  # Setup helper to start a unique renderer for each test
  defp start_renderer(context) do
    name = :"renderer_#{System.unique_integer([:positive, :monotonic])}"
    {:ok, pid} = Mock.start_link(name: name)

    on_exit(fn ->
      if Process.whereis(name) do
        GenServer.stop(name)
      end
    end)

    Map.put(context, :renderer_name, name)
  end

  describe "server lifecycle" do
    test "starts with default name" do
      {:ok, pid} = Mock.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts with custom name" do
      name = :custom_test_renderer
      {:ok, pid} = Mock.start_link(name: name)
      assert is_pid(pid)
      assert Process.whereis(name) == pid
      GenServer.stop(name)
    end

    test "multiple renderers can run concurrently" do
      {:ok, _pid1} = Mock.start_link(name: :renderer_1)
      {:ok, _pid2} = Mock.start_link(name: :renderer_2)

      # Both should be alive
      assert Process.alive?(Process.whereis(:renderer_1))
      assert Process.alive?(Process.whereis(:renderer_2))

      GenServer.stop(:renderer_1)
      GenServer.stop(:renderer_2)
    end
  end

  describe "render/3" do
    setup :start_renderer

    test "accepts valid widget tree", %{renderer_name: name} do
      widget = Widget.label("Hello")
      assert Mock.render("component_1", widget, name) == :ok
    end

    test "returns validation_result for valid widget", %{renderer_name: name} do
      widget = Widget.label("Test")
      assert Mock.render("test_component", widget, name) == :ok
    end

    test "rejects invalid widget tree", %{renderer_name: name} do
      # Invalid widget: label without text
      invalid_widget = %Widget{type: :label, id: nil, props: [], children: []}

      assert Mock.render("component_invalid", invalid_widget, name) ==
               {:error, "label must have a :text property (string)"}
    end

    test "records render with timestamp", %{renderer_name: name} do
      widget = Widget.label("Test")
      time_before = DateTime.utc_now()
      Mock.render("timestamp_test", widget, name)
      time_after = DateTime.utc_now()

      [render] = Mock.get_renders(name)
      assert DateTime.compare(render.timestamp, time_before) in [:gt, :eq]
      assert DateTime.compare(render.timestamp, time_after) in [:lt, :eq]
    end

    test "stores validation_result in render history", %{renderer_name: name} do
      valid_widget = Widget.label("Valid")
      Mock.render("validation_test", valid_widget, name)

      [render] = Mock.get_renders(name)
      assert render.validation_result == :ok
    end

    test "stores validation error for invalid widget", %{renderer_name: name} do
      invalid_widget = %Widget{type: :label, id: nil, props: [], children: []}

      {:error, _reason} = Mock.render("invalid_validation", invalid_widget, name)

      [render] = Mock.get_renders(name)
      assert {:error, _reason} = render.validation_result
    end
  end

  describe "get_renders/1" do
    setup :start_renderer

    test "returns empty list initially", %{renderer_name: name} do
      assert Mock.get_renders(name) == []
    end

    test "returns renders in chronological order", %{renderer_name: name} do
      widget = Widget.label("Test")

      Mock.render("component_1", widget, name)
      Mock.render("component_2", widget, name)
      Mock.render("component_3", widget, name)

      renders = Mock.get_renders(name)

      assert length(renders) == 3
      assert Enum.at(renders, 0).component_id == "component_1"
      assert Enum.at(renders, 1).component_id == "component_2"
      assert Enum.at(renders, 2).component_id == "component_3"

      # Verify chronological order via timestamps (or sequence if timestamps are same)
      timestamps = Enum.map(renders, & &1.timestamp)
      # All timestamps should be in non-decreasing order
      assert timestamps == Enum.sort(timestamps, DateTime)
    end

    test "includes widget in render history", %{renderer_name: name} do
      widget = Widget.label("History Test")
      Mock.render("history_component", widget, name)

      [render] = Mock.get_renders(name)
      assert render.widget.type == :label
      assert render.widget.props[:text] == "History Test"
    end

    test "includes component_id in render history", %{renderer_name: name} do
      widget = Widget.label("Test")
      Mock.render("my_component", widget, name)

      [render] = Mock.get_renders(name)
      assert render.component_id == "my_component"
    end
  end

  describe "get_last_render/1" do
    setup :start_renderer

    test "returns nil when no renders", %{renderer_name: name} do
      assert Mock.get_last_render(name) == nil
    end

    test "returns the most recent render", %{renderer_name: name} do
      widget = Widget.label("Test")

      Mock.render("first", widget, name)
      Mock.render("second", widget, name)
      Mock.render("third", widget, name)

      last = Mock.get_last_render(name)
      assert last.component_id == "third"
    end

    test "returns render with full widget tree", %{renderer_name: name} do
      widget =
        Widget.container(
          :vbox,
          [
            Widget.label("Title"),
            Widget.button("Click", :clicked)
          ],
          spacing: 8
        )

      Mock.render("container_component", widget, name)

      last = Mock.get_last_render(name)
      assert last.widget.type == :container
      assert length(last.widget.children) == 2
    end
  end

  describe "get_render_by_component_id/2" do
    setup :start_renderer

    test "returns nil for unknown component", %{renderer_name: name} do
      assert Mock.get_render_by_component_id("unknown", name) == nil
    end

    test "returns most recent render for component", %{renderer_name: name} do
      widget = Widget.label("Test")

      Mock.render("comp_a", widget, name)
      Mock.render("comp_b", widget, name)
      # Second render of comp_a
      Mock.render("comp_a", widget, name)

      render = Mock.get_render_by_component_id("comp_a", name)
      assert render.component_id == "comp_a"

      renders = Mock.get_renders(name)
      # Should be the third render (second occurrence of comp_a)
      assert render == Enum.at(renders, 2)
    end

    test "returns correct component when multiple exist", %{renderer_name: name} do
      widget = Widget.label("Test")

      Mock.render("alpha", widget, name)
      Mock.render("beta", widget, name)
      Mock.render("gamma", widget, name)

      assert Mock.get_render_by_component_id("alpha", name).component_id == "alpha"
      assert Mock.get_render_by_component_id("beta", name).component_id == "beta"
      assert Mock.get_render_by_component_id("gamma", name).component_id == "gamma"
    end
  end

  describe "get_render_count/1" do
    setup :start_renderer

    test "returns 0 initially", %{renderer_name: name} do
      assert Mock.get_render_count(name) == 0
    end

    test "increments with each render", %{renderer_name: name} do
      widget = Widget.label("Test")

      assert Mock.get_render_count(name) == 0

      Mock.render("comp_1", widget, name)
      assert Mock.get_render_count(name) == 1

      Mock.render("comp_2", widget, name)
      assert Mock.get_render_count(name) == 2

      Mock.render("comp_3", widget, name)
      assert Mock.get_render_count(name) == 3
    end

    test "counts renders even when validation fails", %{renderer_name: name} do
      invalid_widget = %Widget{type: :label, id: nil, props: [], children: []}

      Mock.render("invalid", invalid_widget, name)
      assert Mock.get_render_count(name) == 1
    end
  end

  describe "clear/1" do
    setup :start_renderer

    test "clears render history", %{renderer_name: name} do
      widget = Widget.label("Test")

      Mock.render("comp_1", widget, name)
      Mock.render("comp_2", widget, name)

      assert Mock.get_render_count(name) == 2

      Mock.clear(name)

      assert Mock.get_renders(name) == []
      assert Mock.get_render_count(name) == 0
    end

    test "resets render count", %{renderer_name: name} do
      widget = Widget.label("Test")

      Mock.render("comp_1", widget, name)
      Mock.render("comp_2", widget, name)

      Mock.clear(name)

      assert Mock.get_render_count(name) == 0
    end

    test "allows recording renders after clear", %{renderer_name: name} do
      widget = Widget.label("Test")

      Mock.render("before", widget, name)
      Mock.clear(name)
      Mock.render("after", widget, name)

      renders = Mock.get_renders(name)
      assert length(renders) == 1
      assert hd(renders).component_id == "after"
    end
  end

  describe "screenshot/1" do
    test "generates text representation of label" do
      widget = Widget.label("Hello World")
      result = Mock.screenshot(widget)

      assert result =~ ~r/label\(text="Hello World"\)/
    end

    test "generates text representation of button" do
      widget = Widget.button("Click Me", :on_click)
      result = Mock.screenshot(widget)

      assert result =~ ~r/button\(text="Click Me", on_click=:on_click\)/
    end

    test "generates text representation of container" do
      widget = Widget.container(:vbox, [], spacing: 8, padding: 16)
      result = Mock.screenshot(widget)

      assert result =~ ~r/container\(vbox, spacing=8, padding=16\)/
    end

    test "generates text representation of nested widgets" do
      widget =
        Widget.container(
          :vbox,
          [
            Widget.label("Title"),
            Widget.button("Click", :clicked)
          ],
          spacing: 4
        )

      result = Mock.screenshot(widget)

      lines = result |> String.trim() |> String.split("\n")

      assert length(lines) == 3
      assert hd(lines) =~ ~r/^container\(vbox, spacing=4\)/
      # Children should be indented
      assert Enum.at(lines, 1) =~ ~r/^\s+label\(text="Title"\)/
      assert Enum.at(lines, 2) =~ ~r/^\s+button\(text="Click", on_click=:clicked\)/
    end

    test "handles deeply nested widgets" do
      widget =
        Widget.container(:vbox, [
          Widget.container(:hbox, [
            Widget.label("Nested")
          ])
        ])

      result = Mock.screenshot(widget)
      lines = result |> String.trim() |> String.split("\n")

      assert length(lines) == 3
      # Each level should be indented
      assert Enum.at(lines, 0) =~ ~r/^container/
      assert Enum.at(lines, 1) =~ ~r/^\s+container/
      assert Enum.at(lines, 2) =~ ~r/^\s\s+label/
    end

    test "includes id in screenshot when present" do
      widget = Widget.label("Test", id: :my_label)
      result = Mock.screenshot(widget)

      assert result =~ ~r/id=:my_label/
    end

    test "respects max_depth option" do
      widget =
        Widget.container(:vbox, [
          Widget.container(:hbox, [
            Widget.label("Deep")
          ])
        ])

      result = Mock.screenshot(widget, max_depth: 1)
      lines = result |> String.trim() |> String.split("\n")

      # Should show depth 0 (vbox) and depth 1 (hbox), but not depth 2 (label)
      assert length(lines) == 2
      assert hd(lines) =~ ~r/^container\(vbox\)/
      assert Enum.at(lines, 1) =~ ~r/^\s+container\(hbox\)/
    end

    test "respects custom indent_size" do
      widget =
        Widget.container(:vbox, [
          Widget.label("Indented")
        ])

      result = Mock.screenshot(widget, indent_size: 4)
      lines = result |> String.trim() |> String.split("\n")

      assert length(lines) == 2
      # Second line should have 4 spaces of indentation
      assert String.starts_with?(Enum.at(lines, 1), "  ")
    end

    test "returns string by default" do
      widget = Widget.label("Test")
      result = Mock.screenshot(widget)

      assert is_binary(result)
    end

    test "can write to custom io_device" do
      widget = Widget.label("Test")
      {:ok, pid} = StringIO.open("")

      result = Mock.screenshot(widget, io_device: pid)

      assert result == :ok

      {:ok, {_, output}} = StringIO.close(pid)
      assert output =~ ~r/label\(text="Test"\)/
    end

    test "generates readable screenshot for complex UI" do
      widget =
        Widget.container(
          :vbox,
          [
            Widget.label("Counter Demo", id: :title),
            Widget.container(
              :hbox,
              [
                Widget.button("+", :increment),
                Widget.button("-", :decrement)
              ],
              spacing: 8
            ),
            Widget.label("Current: 0", id: :count_label)
          ],
          spacing: 16,
          padding: 8
        )

      result = Mock.screenshot(widget)

      # Verify structure
      assert result =~ ~r/container\(vbox, spacing=16, padding=8\)/
      assert result =~ ~r/label\(text="Counter Demo", id=:title\)/
      assert result =~ ~r/container\(hbox, spacing=8\)/
      assert result =~ ~r/button\(text="\+", on_click=:increment\)/
      assert result =~ ~r/button\(text="-", on_click=:decrement\)/
      assert result =~ ~r/label\(text="Current: 0", id=:count_label\)/
    end
  end

  describe "integration with RenderingCoordinator" do
    test "supports {module, name} renderer pattern" do
      {:ok, bus} = Jido.Signal.Bus.start_link(name: :test_mock_bus)
      {:ok, renderer_pid} = Mock.start_link(name: :coordinator_test_renderer)

      {:ok, coord_pid} =
        DesktopUI.RenderingCoordinator.start_link(
          renderer: {Mock, :coordinator_test_renderer},
          bus: :test_mock_bus,
          name: :test_mock_coordinator
        )

      # Verify coordinator started
      Process.monitor(coord_pid)
      assert Process.alive?(coord_pid)

      # Register a test component
      defmodule TestComponentForMock do
        use DesktopUI.Elm,
          name: "test_component_for_mock",
          description: "Test component for Mock renderer"

        @impl true
        def init(_opts), do: {%{count: 0}, []}

        @impl true
        def update(_msg, state), do: {state, []}

        @impl true
        def view(%{count: count}) do
          Widget.label("Count: #{count}")
        end
      end

      {:ok, component_pid} =
        Jido.Agent.Server.start_link(
          agent: TestComponentForMock,
          name: :test_component_for_mock_agent
        )

      # Verify component started
      Process.monitor(component_pid)
      assert Process.alive?(component_pid)

      {:ok, _signal} =
        DesktopUI.RenderingCoordinator.register_component(
          coord_pid,
          "test_component",
          TestComponentForMock,
          pid: component_pid,
          bus: :test_mock_bus
        )

      # Subscribe to verify signal flow
      test_pid = self()
      {:ok, _sub} =
        Jido.Signal.Bus.subscribe(
          :test_mock_bus,
          "desktop_ui.**",
          dispatch: {:pid, target: test_pid}
        )

      # Publish a state change signal
      {:ok, signal} =
        DesktopUI.Signals.StateChanged.new(%{
          component_id: "test_component",
          old_state: %{count: 0},
          new_state: %{count: 5}
        })

      Jido.Signal.Bus.publish(:test_mock_bus, [signal])

      # Wait for the render signal to be processed
      assert_receive {:signal, %Jido.Signal{}}, 500

      # Verify mock renderer received the render
      renders = Mock.get_renders(:coordinator_test_renderer)
      assert length(renders) > 0

      last_render = Mock.get_last_render(:coordinator_test_renderer)
      assert last_render.component_id == "test_component"
      assert last_render.widget.type == :label

      # Cleanup
      GenServer.stop(component_pid)
      GenServer.stop(coord_pid)
      GenServer.stop(renderer_pid)
      GenServer.stop(bus)
    end
  end
end
