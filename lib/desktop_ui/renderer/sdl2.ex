defmodule DesktopUI.Renderer.SDL2 do
  @moduledoc """
  Real SDL2 renderer that draws layout trees to SDL2 windows.

  This module implements the `DesktopUI.Renderer` behaviour.

  This module uses DesktopUI.Graphics API for actual drawing operations.
  For now, renders widgets as colored rectangles without text rendering.

  ## Rendering with Layout

  The renderer accepts pre-calculated layout trees from `DesktopUI.Layout.calculate/2`.
  Layout trees contain explicit bounds for each widget, separating layout calculation
  from rendering.

  ## Widget Rendering

  - **Label**: Filled rectangle (light blue)
  - **Button**: Outlined rectangle (gray outline, light fill)
  - **Container**: No visual, arranges children (vbox/hbox)

  ## Usage

  ### Direct Usage with Layout

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

      # Calculate layout
      available_bounds = %{width: 800, height: 600}
      {:ok, layout} = DesktopUI.Layout.calculate(widget, available_bounds)

      # Render layout
      :ok = DesktopUI.Renderer.SDL2.render(renderer, layout)

      # Cleanup when done
      :ok = DesktopUI.Renderer.SDL2.cleanup(renderer)
      DesktopUI.Graphics.destroy_window(window_id)

  ### Convenience: Render Widget Directly

      # The renderer can also accept a widget and calculate layout internally
      :ok = DesktopUI.Renderer.SDL2.render(renderer, widget)

  ### With RenderingCoordinator

      # The coordinator stores the window_id in ETS for named renderer calls
      # This allows the SDL2 renderer to work with the coordinator's render/3 API

      DesktopUI.Renderer.SDL2.set_window_id(window_id)
      :ok = DesktopUI.Renderer.SDL2.render(component_id, widget, :coordinator_name)

  """

  @behaviour DesktopUI.Renderer

  alias DesktopUI.{Graphics, Layout, Widget}

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
  Render to the window.

  This function accepts either a `DesktopUI.Layout` struct (pre-calculated layout)
  or a `DesktopUI.Widget` struct (calculates layout first).

  When given a widget, this function is a convenience wrapper that calculates
  layout first, then renders. For better performance, calculate layout once
  and use `render/2` with the layout directly.

  ## Parameters

  - `renderer` - Renderer struct from `init/1`
  - `layout_or_widget` - Either a layout tree (from `Layout.calculate/2`) or a widget tree

  ## Returns

  - `:ok` - Rendered successfully
  - `{:error, reason}` - Rendering or layout calculation failed

  ## Examples

      # With pre-calculated layout (recommended for repeated renders)
      widget = Widget.label("Hello")
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})
      :ok = DesktopUI.Renderer.SDL2.render(renderer, layout)

      # With widget (convenience wrapper)
      :ok = DesktopUI.Renderer.SDL2.render(renderer, widget)

  """
  @spec render(t(), Layout.t()) :: :ok | {:error, String.t()}
  def render(%__MODULE__{} = renderer, %Layout{} = layout) do
    with :ok <- Graphics.clear_window(renderer.window_id, @background_color),
       :ok <- render_layout(renderer, layout),
       :ok <- Graphics.present_window(renderer.window_id) do
      :ok
    end
  end

  @spec render(t(), Widget.t()) :: :ok | {:error, String.t()}
  def render(%__MODULE__{} = renderer, %Widget{} = widget) do
    available_bounds = %{width: renderer.window_width, height: renderer.window_height}

    case Layout.calculate(widget, available_bounds) do
      {:ok, layout} ->
        render(renderer, layout)

      {:error, reason} ->
        {:error, "Layout calculation failed: #{reason}"}
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

  # Main layout dispatch - routes to specific renderer based on widget type
  defp render_layout(renderer, %Layout{widget: %Widget{type: :label}} = layout) do
    render_label_at(renderer, layout)
  end

  defp render_layout(renderer, %Layout{widget: %Widget{type: :button}} = layout) do
    render_button_at(renderer, layout)
  end

  defp render_layout(renderer, %Layout{widget: %Widget{type: :container}} = layout) do
    render_container_layout(renderer, layout)
  end

  # Render label at its calculated layout position
  defp render_label_at(renderer, %Layout{x: x, y: y, width: width, height: height}) do
    {draw_x, draw_y, draw_w, draw_h} =
      clip_to_bounds(x, y, width, height, renderer.window_width, renderer.window_height)

    Graphics.fill_rect_on_window(renderer.window_id, draw_x, draw_y, draw_w, draw_h, @label_color)
  end

  # Render button at its calculated layout position
  defp render_button_at(renderer, %Layout{x: x, y: y, width: width, height: height}) do
    {draw_x, draw_y, draw_w, draw_h} =
      clip_to_bounds(x, y, width, height, renderer.window_width, renderer.window_height)

    # Draw fill
    Graphics.fill_rect_on_window(renderer.window_id, draw_x, draw_y, draw_w, draw_h, @button_fill_color)
    # Draw outline
    Graphics.draw_rect_on_window(renderer.window_id, draw_x, draw_y, draw_w, draw_h, @button_outline_color)
  end

  # Render container by rendering all its child layouts
  defp render_container_layout(renderer, %Layout{widget: %Widget{children: children}}) do
    Enum.reduce_while(children, :ok, fn child_layout, _acc ->
      case render_layout(renderer, child_layout) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  # Clip drawing coordinates to window bounds
  defp clip_to_bounds(x, y, w, h, max_w, max_h) do
    clipped_x = max(0, min(x, max_w))
    clipped_y = max(0, min(y, max_h))
    clipped_w = max(0, min(w, max_w - clipped_x))
    clipped_h = max(0, min(h, max_h - clipped_y))

    {clipped_x, clipped_y, clipped_w, clipped_h}
  end
end
