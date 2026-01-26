defmodule DesktopUI.Renderer.SDL2 do
  @moduledoc """
  Real SDL2 renderer that draws widget trees to SDL2 windows.

  This module implements the `DesktopUI.Renderer` behaviour.

  This module uses DesktopUI.Graphics API for actual drawing operations.
  For now, renders widgets as colored rectangles without text rendering.

  ## Widget Rendering

  - **Label**: Filled rectangle (light blue)
  - **Button**: Outlined rectangle (gray outline, light fill)
  - **Container (vbox)**: No visual, arranges children vertically
  - **Container (hbox)**: No visual, arranges children horizontally

  ## Usage

  ### Direct Usage

      # Initialize SDL2 and create window
      DesktopUI.Graphics.init()
      {:ok, window_id} = DesktopUI.Graphics.create_window("My App", 800, 600)

      # Initialize renderer
      {:ok, renderer} = DesktopUI.Renderer.SDL2.init(window_id)

      # Build widget tree
      widget = DesktopUI.Widget.container(:vbox, [
        DesktopUI.Widget.label("Hello, World!"),
        DesktopUI.Widget.button("Click me", :clicked)
      ], spacing: 8, padding: 16)

      # Render widget tree
      :ok = DesktopUI.Renderer.SDL2.render(renderer, widget)

      # Cleanup when done
      :ok = DesktopUI.Renderer.SDL2.cleanup(renderer)
      DesktopUI.Graphics.destroy_window(window_id)

  ### With RenderingCoordinator

      # The coordinator stores the window_id in ETS for named renderer calls
      # This allows the SDL2 renderer to work with the coordinator's render/3 API

      DesktopUI.Renderer.SDL2.set_window_id(window_id)
      :ok = DesktopUI.Renderer.SDL2.render(component_id, widget, :coordinator_name)

  """

  @behaviour DesktopUI.Renderer

  alias DesktopUI.Graphics
  alias DesktopUI.Widget

  defstruct [:window_id, :window_width, :window_height]

  @type t :: %__MODULE__{
          window_id: non_neg_integer(),
          window_width: pos_integer(),
          window_height: pos_integer()
        }

  # ETS table for storing window_id (for coordinator compatibility)
  @window_table :desktop_ui_sdl2_renderer_window

  # Color constants for placeholder rendering
  @label_color {173, 216, 230, 255}          # Light blue
  @button_fill_color {220, 220, 220, 255}    # Light gray
  @button_outline_color {100, 100, 100, 255} # Dark gray
  @background_color {255, 255, 255, 255}     # White
  @error_color {255, 100, 100, 255}          # Light red

  # Default widget dimensions
  @default_label_width 100
  @default_label_height 30
  @default_button_width 80
  @default_button_height 30

  @doc """
  Initialize the SDL2 renderer with a window.

  ## Parameters

  - `window_id` - Window ID from `Graphics.create_window/4`

  ## Returns

  - `{:ok, renderer}` - Renderer initialized successfully
  - `{:error, reason}` - Initialization failed

  ## Examples

      {:ok, window_id} = Graphics.create_window("Demo", 800, 600)
      {:ok, renderer} = DesktopUI.Renderer.SDL2.init(window_id)

  """
  @spec init(non_neg_integer()) :: {:ok, t()} | {:error, String.t()}
  def init(window_id) when is_integer(window_id) do
    with {:ok, {width, height}} <- Graphics.get_window_size(window_id) do
      renderer = %__MODULE__{
        window_id: window_id,
        window_width: width,
        window_height: height
      }

      {:ok, renderer}
    end
  end

  @doc """
  Render a widget tree to the window.

  This function:
  1. Clears the window with background color
  2. Traverses the widget tree and renders each widget
  3. Presents the rendered content to the screen

  ## Parameters

  - `renderer` - Renderer struct from `init/1`
  - `widget` - Root widget to render

  ## Returns

  - `:ok` - Rendered successfully
  - `{:error, reason}` - Rendering failed

  ## Examples

      widget = Widget.label("Hello")
      :ok = DesktopUI.Renderer.SDL2.render(renderer, widget)

  """
  @spec render(t(), Widget.t()) :: :ok | {:error, String.t()}
  def render(%__MODULE__{} = renderer, %Widget{} = widget) do
    with :ok <- Graphics.clear_window(renderer.window_id, @background_color),
         :ok <- render_widget(renderer, widget, 0, 0, renderer.window_width, renderer.window_height),
         :ok <- Graphics.present_window(renderer.window_id) do
      :ok
    end
  end

  @doc """
  Set the window_id for use with the RenderingCoordinator's render/3 API.

  This stores the window_id in an ETS table so that the coordinator can call
  `render/3` without needing to pass a renderer struct.

  ## Parameters

  - `window_id` - Window ID from Graphics.create_window/4

  ## Returns

  - `:ok`

  ## Examples

      DesktopUI.Renderer.SDL2.set_window_id(window_id)

  """
  @spec set_window_id(non_neg_integer()) :: :ok
  def set_window_id(window_id) when is_integer(window_id) do
    # Create ETS table if it doesn't exist
    try do
      :ets.new(@window_table, [:named_table, :public, :set])
    rescue
      ArgumentError -> :ok  # Table already exists
    end

    # Store window_id
    :ets.insert(@window_table, {:window_id, window_id})

    :ok
  end

  @doc """
  Get the stored window_id.

  Returns `nil` if no window_id has been set.
  """
  @spec get_window_id() :: non_neg_integer() | nil
  def get_window_id do
    case :ets.lookup(@window_table, :window_id) do
      [{:window_id, window_id}] -> window_id
      [] -> nil
    end
  end

  @doc """
  Render using the coordinator's render/3 API.

  This function is called by RenderingCoordinator with component_id and name.
  It retrieves the stored window_id and delegates to the main render/2 function.

  ## Parameters

  - `_component_id` - Component identifier (unused for SDL2 renderer)
  - `widget` - Widget tree to render
  - `_name` - Process name (unused for SDL2 renderer)

  ## Returns

  - `:ok` - Rendered successfully
  """
  @spec render(String.t(), Widget.t(), atom()) :: :ok
  def render(_component_id, %Widget{} = widget, _name) do
    case get_window_id() do
      nil ->
        {:error, "No window_id set. Call DesktopUI.Renderer.SDL2.set_window_id/1 first."}

      window_id ->
        case Graphics.get_window_size(window_id) do
          {:ok, {width, height}} ->
            renderer = %__MODULE__{
              window_id: window_id,
              window_width: width,
              window_height: height
            }

            render(renderer, widget)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Cleanup renderer resources.

  Currently a no-op since Graphics handles resource cleanup.
  Provided for API consistency and future extensibility.

  ## Parameters

  - `renderer` - Renderer struct

  ## Returns

  - `:ok` - Always succeeds

  """
  @spec cleanup(t()) :: :ok
  def cleanup(%__MODULE__{}) do
    # No renderer-specific resources to clean up
    # Graphics handles window/renderer cleanup
    :ok
  end

  @doc """
  Clean up window-specific resources.

  This implements the `DesktopUI.Renderer.cleanup_window/1` callback.
  It removes the window_id from the renderer's ETS table.

  ## Parameters

  - `window_id` - Window identifier

  ## Returns

  - `:ok` - Always succeeds
  """
  @impl true
  @spec cleanup_window(non_neg_integer()) :: :ok
  def cleanup_window(_window_id) do
    # Delete window_id from the renderer's ETS table
    try do
      :ets.delete(@window_table, :window_id)
    rescue
      _ -> :ok
    end

    :ok
  end

  @doc false
  # Get the window table name (deprecated, kept for compatibility)
  def window_table, do: @window_table

  # ============================================================================
  # Private Functions
  # ============================================================================

  # Main widget dispatch - routes to specific renderer based on widget type
  defp render_widget(renderer, %Widget{type: :label} = widget, x, y, available_width, available_height) do
    render_label(renderer, widget, x, y, available_width, available_height)
  end

  defp render_widget(renderer, %Widget{type: :button} = widget, x, y, available_width, available_height) do
    render_button(renderer, widget, x, y, available_width, available_height)
  end

  defp render_widget(renderer, %Widget{type: :container} = widget, x, y, available_width, available_height) do
    render_container(renderer, widget, x, y, available_width, available_height)
  end

  # Render label as filled rectangle
  defp render_label(renderer, %Widget{props: props}, x, y, available_width, _available_height) do
    width = Keyword.get(props, :width, @default_label_width)
    height = Keyword.get(props, :height, @default_label_height)

    # Ensure widget doesn't overflow available space
    actual_width = min(width, available_width)
    {draw_x, draw_y, draw_w, draw_h} = clip_to_bounds(x, y, actual_width, height, renderer.window_width, renderer.window_height)

    Graphics.fill_rect_on_window(renderer.window_id, draw_x, draw_y, draw_w, draw_h, @label_color)
  end

  # Render button as outlined rectangle
  defp render_button(renderer, %Widget{props: props}, x, y, available_width, _available_height) do
    width = Keyword.get(props, :width, @default_button_width)
    height = Keyword.get(props, :height, @default_button_height)

    # Ensure widget doesn't overflow available space
    actual_width = min(width, available_width)
    {draw_x, draw_y, draw_w, draw_h} = clip_to_bounds(x, y, actual_width, height, renderer.window_width, renderer.window_height)

    # Draw fill
    Graphics.fill_rect_on_window(renderer.window_id, draw_x, draw_y, draw_w, draw_h, @button_fill_color)
    # Draw outline
    Graphics.draw_rect_on_window(renderer.window_id, draw_x, draw_y, draw_w, draw_h, @button_outline_color)
  end

  # Render container with child layout
  defp render_container(renderer, %Widget{props: props, children: children}, x, y, available_width, available_height) do
    layout_type = Keyword.get(props, :layout, :vbox)
    spacing = Keyword.get(props, :spacing, 0)
    padding = Keyword.get(props, :padding, 0)

    # Calculate child layouts
    child_layouts = calculate_layout(layout_type, children, x, y, available_width, available_height, spacing, padding)

    # Render each child at its calculated position
    Enum.reduce_while(child_layouts, :ok, fn child_layout, _acc ->
      case render_widget(renderer, child_layout.widget, child_layout.x, child_layout.y, child_layout.width, child_layout.height) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  # Calculate layout positions for container children
  defp calculate_layout(:vbox, children, container_x, container_y, container_width, container_height, spacing, padding) do
    start_x = container_x + padding
    start_y = container_y + padding
    available_width = container_width - (2 * padding)

    {layouts, _final_y} =
      Enum.map_reduce(children, start_y, fn child, current_y ->
        child_height = get_widget_height(child, available_width)
        child_width = get_widget_width(child, available_width)

        layout = %{
          widget: child,
          x: start_x,
          y: current_y,
          width: child_width,
          height: child_height
        }

        {layout, current_y + child_height + spacing}
      end)

    layouts
  end

  defp calculate_layout(:hbox, children, container_x, container_y, container_width, container_height, spacing, padding) do
    start_x = container_x + padding
    start_y = container_y + padding
    available_height = container_height - (2 * padding)

    {layouts, _final_x} =
      Enum.map_reduce(children, start_x, fn child, current_x ->
        child_width = get_widget_width(child, container_width)
        child_height = get_widget_height(child, available_height)

        layout = %{
          widget: child,
          x: current_x,
          y: start_y,
          width: child_width,
          height: child_height
        }

        {layout, current_x + child_width + spacing}
      end)

    layouts
  end

  # Get widget width from props or use default
  defp get_widget_width(%Widget{type: :label, props: props}, _available_width) do
    Keyword.get(props, :width, @default_label_width)
  end

  defp get_widget_width(%Widget{type: :button, props: props}, _available_width) do
    Keyword.get(props, :width, @default_button_width)
  end

  defp get_widget_width(%Widget{type: :container, props: props}, available_width) do
    case Keyword.get(props, :width) do
      nil -> available_width
      width -> width
    end
  end

  # Get widget height from props or use default
  defp get_widget_height(%Widget{type: :label, props: props}, _available_height) do
    Keyword.get(props, :height, @default_label_height)
  end

  defp get_widget_height(%Widget{type: :button, props: props}, _available_height) do
    Keyword.get(props, :height, @default_button_height)
  end

  defp get_widget_height(%Widget{type: :container, props: props}, available_height) do
    case Keyword.get(props, :height) do
      nil -> available_height
      height -> height
    end
  end

  # Clip drawing coordinates to window bounds
  defp clip_to_bounds(x, y, w, h, max_w, max_h) do
    import Integer

    clipped_x = max(0, min(x, max_w))
    clipped_y = max(0, min(y, max_h))
    clipped_w = max(0, min(w, max_w - clipped_x))
    clipped_h = max(0, min(h, max_h - clipped_y))

    {clipped_x, clipped_y, clipped_w, clipped_h}
  end
end
