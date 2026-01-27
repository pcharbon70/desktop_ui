defmodule DesktopUI.Renderer.Mock do
  @moduledoc """
  Mock renderer for testing and debugging UI trees.

  The MockRenderer validates widget trees and records render calls for test
  assertions. It provides introspection capabilities for debugging without
  actually drawing anything to screen.

  ## Purpose

  This module serves as a test double renderer that proves the rendering
  pipeline works before we have real graphics. It's useful for:

  * Unit testing component view/1 functions
  * Integration testing the full rendering pipeline
  * Debugging widget tree structure
  * Validating widget well-formedness

  ## Usage

  Start the mock renderer as a named process:

      {:ok, pid} = DesktopUI.Renderer.Mock.start_link(name: :my_mock_renderer)

  Render a widget tree:

      :ok = DesktopUI.Renderer.Mock.render("component_id", widget, :my_mock_renderer)

  Get render history:

      renders = DesktopUI.Renderer.Mock.get_renders(:my_mock_renderer)

  Clear history:

      :ok = DesktopUI.Renderer.Mock.clear(:my_mock_renderer)

  Generate text screenshot:

      text = DesktopUI.Renderer.Mock.screenshot(widget)

  ## Integration with RenderingCoordinator

  The MockRenderer supports the stateful renderer pattern used by
  DesktopUI.RenderingCoordinator:

      {:ok, _pid} = RenderingCoordinator.start_link(
        renderer: {DesktopUI.Renderer.Mock, :mock_renderer},
        bus: :desktop_ui
      )

  ## Screenshot Format

  The screenshot function produces an indented text representation:

      container(vbox, spacing=8, padding=16)
        label(text="Counter Demo")
        container(hbox, spacing=4)
          button(text="+")
          button(text="-")
        label(text="Current: 0")

  """

  use GenServer
  alias DesktopUI.Widget

  # Client API

  @doc """
  Start the mock renderer.

  ## Options

  * `:name` - The name to register the GenServer (required for concurrent tests)

  ## Examples

      {:ok, pid} = DesktopUI.Renderer.Mock.start_link(name: :test_renderer)

  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Render a widget tree.

  Validates the widget tree and records the render call.

  ## Parameters

  * `component_id` - Unique identifier for the component being rendered
  * `widget` - The widget tree to render
  * `server_name` - The name of the mock renderer process (defaults to __MODULE__)

  ## Returns

  * `:ok` - Widget was validated and render recorded
  * `{:error, reason}` - Widget validation failed

  ## Examples

      :ok = DesktopUI.Renderer.Mock.render("counter", widget, :my_renderer)

  """
  def render(component_id, widget, server_name \\ __MODULE__) do
    GenServer.call(server_name, {:render, component_id, widget})
  end

  @doc """
  Render a component with a pre-calculated layout.

  This is the preferred rendering path as layout is calculated once
  by the RenderingCoordinator and then passed to the renderer.

  ## Parameters

  * `component_id` - The component identifier
  * `layout` - The pre-calculated layout tree
  * `server_name` - The name of the mock renderer process (default: __MODULE__)

  ## Returns

  * `:ok` - Render was recorded successfully

  ## Examples

      {:ok, layout} = DesktopUI.Layout.calculate(widget, bounds)
      :ok = DesktopUI.Renderer.Mock.render_with_layout("counter", layout)
      :ok = DesktopUI.Renderer.Mock.render_with_layout("counter", layout, :my_renderer)

  """
  def render_with_layout(component_id, layout) do
    render_with_layout(component_id, layout, __MODULE__)
  end

  def render_with_layout(component_id, layout, server_name) do
    GenServer.call(server_name, {:render_with_layout, component_id, layout})
  end

  @doc """
  Get the list of all renders.

  Returns renders in chronological order (oldest first).

  ## Parameters

  * `server_name` - The name of the mock renderer process

  ## Returns

  List of render maps with keys:
  * `:component_id` - The component identifier
  * `:widget` - The widget tree that was rendered
  * `:timestamp` - When the render occurred
  * `:validation_result` - `:ok` or `{:error, reason}`

  ## Examples

      renders = DesktopUI.Renderer.Mock.get_renders(:my_renderer)
      # => [
      #   %{component_id: "counter", widget: %Widget{}, timestamp: ~U[...], validation_result: :ok},
      #   ...
      # ]

  """
  def get_renders(server_name \\ __MODULE__) do
    GenServer.call(server_name, :get_renders)
  end

  @doc """
  Get the most recent render.

  Returns `nil` if no renders have been recorded.

  ## Parameters

  * `server_name` - The name of the mock renderer process

  ## Examples

      last = DesktopUI.Renderer.Mock.get_last_render(:my_renderer)

  """
  def get_last_render(server_name \\ __MODULE__) do
    GenServer.call(server_name, :get_last_render)
  end

  @doc """
  Get the most recent render for a specific component.

  Returns `nil` if the component hasn't been rendered.

  ## Parameters

  * `component_id` - The component identifier to look up
  * `server_name` - The name of the mock renderer process

  ## Examples

      render = DesktopUI.Renderer.Mock.get_render_by_component_id("counter", :my_renderer)

  """
  def get_render_by_component_id(component_id, server_name \\ __MODULE__) do
    GenServer.call(server_name, {:get_render_by_component_id, component_id})
  end

  @doc """
  Get the total number of renders.

  ## Parameters

  * `server_name` - The name of the mock renderer process

  ## Examples

      count = DesktopUI.Renderer.Mock.get_render_count(:my_renderer)
      # => 5

  """
  def get_render_count(server_name \\ __MODULE__) do
    GenServer.call(server_name, :get_render_count)
  end

  @doc """
  Clear the render history.

  ## Parameters

  * `server_name` - The name of the mock renderer process

  ## Examples

      :ok = DesktopUI.Renderer.Mock.clear(:my_renderer)

  """
  def clear(server_name \\ __MODULE__) do
    GenServer.call(server_name, :clear)
  end

  @doc """
  Generate a text screenshot of a widget tree.

  This function produces an indented text representation of the widget
  hierarchy, useful for debugging and documentation.

  ## Parameters

  * `widget` - The widget tree to screenshot
  * `opts` - Optional keyword list

  ## Options

  * `:indent_size` - Number of spaces per indentation level (default: 2)
  * `:max_depth` - Maximum depth to traverse (default: :unlimited)
  * `:io_device` - IO device to write to (default: :string_io, returns string)

  ## Returns

  By default, returns a string. If `:io_device` is provided, returns `:ok`.

  ## Examples

      DesktopUI.Renderer.Mock.screenshot(widget)
      #=> "container(vbox, spacing=8)\\n  label(text=\\"Hello\\")\\n  button(text=\\"Click\\")"

      # Write to file
      {:ok, file} = File.open("screenshot.txt", [:write])
      DesktopUI.Renderer.Mock.screenshot(widget, io_device: file)
      File.close(file)

  """
  def screenshot(widget, opts \\ []) do
    indent_size = Keyword.get(opts, :indent_size, 2)
    max_depth = Keyword.get(opts, :max_depth, :unlimited)
    io_device = Keyword.get(opts, :io_device, :string_io)

    if io_device == :string_io do
      {:ok, pid} = StringIO.open("")
      screenshot_to_io(pid, widget, 0, "", indent_size, max_depth)
      {:ok, {_, result}} = StringIO.close(pid)
      result
    else
      screenshot_to_io(io_device, widget, 0, "", indent_size, max_depth)
      :ok
    end
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    {:ok,
     %{
       renders: [],
       render_count: 0,
       validation_failure_count: 0,
       name: name
     }}
  end

  @impl true
  def handle_call({:render, component_id, widget}, _from, state) do
    # Validate the widget
    validation_result = Widget.validate(widget)

    render = %{
      component_id: component_id,
      widget: widget,
      timestamp: DateTime.utc_now(),
      validation_result: validation_result
    }

    new_state = %{
      state
      | renders: state.renders ++ [render],
        render_count: state.render_count + 1,
        validation_failure_count:
          if validation_result == :ok do
            state.validation_failure_count
          else
            state.validation_failure_count + 1
          end
    }

    {:reply, validation_result, new_state}
  end

  @impl true
  def handle_call({:render_with_layout, component_id, layout}, _from, state) do
    # Extract widget from layout for compatibility with existing tests
    widget = layout.widget

    # Validate the widget
    validation_result = Widget.validate(widget)

    # Store render with both layout and widget for flexibility
    render = %{
      component_id: component_id,
      widget: widget,
      layout: layout,
      timestamp: DateTime.utc_now(),
      validation_result: validation_result
    }

    new_state = %{
      state
      | renders: state.renders ++ [render],
        render_count: state.render_count + 1,
        validation_failure_count:
          if validation_result == :ok do
            state.validation_failure_count
          else
            state.validation_failure_count + 1
          end
    }

    {:reply, :ok, new_state}
  end

  def handle_call(:get_renders, _from, state) do
    {:reply, state.renders, state}
  end

  def handle_call(:get_last_render, _from, %{renders: []} = state) do
    {:reply, nil, state}
  end

  def handle_call(:get_last_render, _from, state) do
    {:reply, List.last(state.renders), state}
  end

  def handle_call({:get_render_by_component_id, component_id}, _from, state) do
    render =
      state.renders
      |> Enum.filter(fn r -> r.component_id == component_id end)
      |> List.last()

    {:reply, render, state}
  end

  def handle_call(:get_render_count, _from, state) do
    {:reply, state.render_count, state}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok,
     %{
       state
       | renders: [],
         render_count: 0,
         validation_failure_count: 0
     }}
  end

  # Private Functions

  # Screenshot generation - recursive traversal
  defp screenshot_to_io(
         io_device,
         %Widget{type: type, props: props, children: children},
         depth,
         prefix,
         indent_size,
         max_depth
       ) do
    if max_depth != :unlimited and depth > max_depth do
      :ok
    else
      # Build widget description line
      line = widget_to_line(type, props)

      # Write indented line
      IO.write(io_device, prefix <> line <> "\n")

      # Recursively write children
      new_prefix = prefix <> String.duplicate(" ", indent_size)

      Enum.each(children || [], fn child ->
        screenshot_to_io(io_device, child, depth + 1, new_prefix, indent_size, max_depth)
      end)

      :ok
    end
  end

  defp screenshot_to_io(_io_device, _other, _depth, _prefix, _indent_size, _max_depth) do
    :ok
  end

  # Convert widget to text line
  defp widget_to_line(:label, props) do
    text = Keyword.get(props, :text, "")
    id = if id = Keyword.get(props, :id), do: ", id=#{inspect(id)}", else: ""
    "label(text=\"#{text}\"#{id})"
  end

  defp widget_to_line(:button, props) do
    text = Keyword.get(props, :text, "")
    on_click = Keyword.get(props, :on_click)
    id = if id = Keyword.get(props, :id), do: ", id=#{inspect(id)}", else: ""
    "button(text=\"#{text}\", on_click=#{inspect(on_click)}#{id})"
  end

  defp widget_to_line(:container, props) do
    layout = Keyword.get(props, :layout, :vbox)
    spacing = Keyword.get(props, :spacing, 0)
    padding = Keyword.get(props, :padding, 0)
    id = if id = Keyword.get(props, :id), do: ", id=#{inspect(id)}", else: ""

    parts = ["container(", Atom.to_string(layout)]
    parts = if spacing > 0, do: parts ++ [", spacing=#{spacing}"], else: parts
    parts = if padding > 0, do: parts ++ [", padding=#{padding}"], else: parts
    parts = parts ++ [id, ")"]

    Enum.join(parts)
  end
end
